<?php
// POST /movements-create.php
// Body: { "document_id": "DOC-2026-000001", "office_id": 1, "status": "IN|OUT", "expected_movement_id": 1, "remarks": "..." }
// Return (incomplete / sent back): { ..., "status": "OUT", "is_return": true, "remarks": "<reason>" }
//   destination must be an office that already held the folder; reason is required.
// Auth: Bearer token required (user id extracted from token)

require __DIR__ . '/config.php';
require_once __DIR__ . '/movements-helper.php';
require_once __DIR__ . '/routing-helper.php';
require_once __DIR__ . '/qr-token-helper.php';
require_once __DIR__ . '/folder-contents-helper.php';
require_once __DIR__ . '/movement-requests-helper.php';
require_once __DIR__ . '/movement-corrections-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

$userId = require_user_id();
$user = smartflow_require_authenticated_user($pdo, $userId);

$body = get_json_body();
$documentId = trim((string)($body['document_id'] ?? ''));
$officeId = (int)($body['office_id'] ?? 0);
$status = strtoupper(trim((string)($body['status'] ?? '')));
$remarks = isset($body['remarks']) ? trim((string)$body['remarks']) : null;
$destinationOfficeId = isset($body['destination_office_id'])
    ? (int)$body['destination_office_id']
    : 0;
$scanStartedAtRaw = trim((string)($body['scan_started_at'] ?? ''));
$qrPayloadRaw = trim((string)($body['qr_payload'] ?? ''));
$isReturn = !empty($body['is_return']);
$fromSystem = ($body['movement_source'] ?? '') === 'system';
$displayedMovement = $body['expected_movement_id'] ?? null;
$expectedMovementId = filter_var($displayedMovement, FILTER_VALIDATE_INT, ['options' => ['min_range' => 0]]);

if ($user['role'] !== 'staff') {
    smartflow_reject_scan(
        $pdo, 'movement.scan', $documentId !== '' ? $documentId : null,
        $userId, $officeId > 0 ? $officeId : null,
        in_array($status, ['IN', 'OUT'], true) ? $status : null,
        'role_forbidden',
        'Only office staff can record physical handoffs. Heads and administrators can look up and monitor folders.',
        403
    );
}

if ($documentId === '' || $officeId <= 0 || ($status !== 'IN' && $status !== 'OUT')) {
    json_response([
        'success' => false,
        'message' => 'document_id, office_id, and status (IN or OUT) are required',
        'scan_error' => 'invalid_request',
    ], 400);
}
if ($isReturn && $status !== 'OUT') {
    json_response([
        'success' => false,
        'message' => 'Returns are recorded as Mark OUT',
        'scan_error' => 'invalid_request',
    ], 400);
}
// A scan timestamp does not prove that this is still the movement the user reviewed.
// Explicit zero preserves Scan lookup of a legacy folder with no recorded movement.
if ((!is_int($displayedMovement) && !is_string($displayedMovement)) || $expectedMovementId === false) {
    json_response(['success' => false, 'message' => 'Look up the current folder and review its latest movement before recording a handoff.', 'scan_error' => 'confirmation_required'], 400);
}

if ($fromSystem) {
    if ($expectedMovementId <= 0 || ($status === 'IN' && ($body['receipt_confirmed'] ?? false) !== true)) {
        json_response(['success' => false, 'message' => 'Open the current document and confirm actual receipt before receiving.', 'scan_error' => 'confirmation_required'], 400);
    }
}
// Both scanner and system handoffs share this lock and state validation.
smartflow_ensure_folder_contents($pdo);
smartflow_ensure_documents_filed_columns($pdo);
smartflow_ensure_movement_corrections($pdo);
$requestId = isset($body['request_id']) ? smartflow_request_id($body['request_id']) : null;
if ($requestId !== null) smartflow_ensure_movement_requests($pdo);
$pdo->beginTransaction();
if ($requestId !== null) {
    $requestBody = $body;
    unset($requestBody['_smartflow_operation']);
    smartflow_lock_movement_request($pdo, $requestId, $userId, $documentId, $requestBody);
}
$stmtDoc = $pdo->prepare('SELECT id, title, folder_inventory, filed_at FROM documents WHERE id = :id LIMIT 1 FOR UPDATE');
$stmtDoc->execute([':id' => $documentId]);
$doc = $stmtDoc->fetch();
if (!$doc) {
    smartflow_reject_scan(
        $pdo,
        'movement.scan',
        $documentId !== '' ? $documentId : null,
        $userId,
        $officeId > 0 ? $officeId : null,
        $status !== '' ? $status : null,
        'document_not_found',
        'Document not found. Ask the originating office to register it in SmartFlow.',
        404
    );
}
if (!empty($doc['filed_at'])) {
    smartflow_reject_scan(
        $pdo,
        'movement.scan',
        $documentId,
        $userId,
        $officeId > 0 ? $officeId : null,
        $status !== '' ? $status : null,
        'already_filed',
        'This folder is filed. The route is finished.',
        409
    );
}

$stmtCurrent = $pdo->prepare('SELECT id, status, office_id, destination_office_id FROM movements WHERE document_id = ? ORDER BY scanned_at DESC, id DESC LIMIT 1');
$stmtCurrent->execute([$documentId]);
$current = $stmtCurrent->fetch();
if ((int)($current['id'] ?? 0) !== $expectedMovementId) {
    smartflow_reject_scan($pdo, 'movement.scan', $documentId, $userId, $officeId, $status,
        'document_changed', 'The document moved since you opened it. Refresh and review its current location.',
        409, ['movement_source' => $fromSystem ? 'system' : 'scan', 'expected_movement_id' => $expectedMovementId]);
}
if ($fromSystem) {
    if ($status === 'IN' && (int)($current['destination_office_id'] ?? 0) !== $user['office_id']) {
        smartflow_reject_scan($pdo, 'movement.scan', $documentId, $userId, $officeId, $status,
            'wrong_receiver', 'Only the selected receiving office can confirm receipt.',
            409, ['movement_source' => 'system']);
    }
}

if ($qrPayloadRaw !== '') {
    $qrCheck = smartflow_qr_verify($qrPayloadRaw);
    if (!$qrCheck['valid']) {
        $qrReason = (string)($qrCheck['reason'] ?? 'invalid');
        smartflow_reject_scan(
            $pdo,
            'movement.scan',
            $qrCheck['document_id'] ?? $documentId,
            $userId,
            $officeId,
            $status,
            'qr_' . $qrReason,
            $qrCheck['message'],
            403,
            ['qr_reason' => $qrReason]
        );
    }
    if (strcasecmp((string)$qrCheck['document_id'], $documentId) !== 0) {
        smartflow_reject_scan(
            $pdo,
            'movement.scan',
            $documentId,
            $userId,
            $officeId,
            $status,
            'qr_mismatch',
            'QR label does not match this document. Rescan the correct folder label.',
            403,
            ['qr_document_id' => $qrCheck['document_id']]
        );
    }
}

if ($scanStartedAtRaw !== '') {
    $scanAtTs = strtotime($scanStartedAtRaw);
    if ($scanAtTs === false) {
        smartflow_reject_scan(
            $pdo,
            'movement.scan',
            $documentId,
            $userId,
            $officeId,
            $status,
            'scan_session_invalid',
            'Invalid scan timestamp. Rescan the QR and try again.',
            400
        );
    }
    $scanAgeSeconds = time() - $scanAtTs;
    if ($scanAgeSeconds > 300) {
        smartflow_reject_scan(
            $pdo,
            'movement.scan',
            $documentId,
            $userId,
            $officeId,
            $status,
            'scan_session_expired',
            'Scan session expired. Rescan the QR before marking IN/OUT.',
            409,
            ['scan_age_seconds' => $scanAgeSeconds]
        );
    }
}

smartflow_validate_movement($pdo, $user, $documentId, $officeId, $status, [
    'user_id' => $userId,
    'office_id' => $officeId,
    'status' => $status,
]);

if (smartflow_has_recent_duplicate_movement($pdo, $documentId, $officeId, $status, $userId)) {
    smartflow_reject_scan(
        $pdo,
        'movement.scan',
        $documentId,
        $userId,
        $officeId,
        $status,
        'duplicate',
        'Duplicate scan blocked. This action was already recorded a moment ago.',
        409
    );
}

$destOffice = null;
if ($status === 'OUT') {
    if ($destinationOfficeId <= 0) {
        smartflow_reject_scan(
            $pdo,
            'movement.scan',
            $documentId,
            $userId,
            $officeId,
            $status,
            'missing_destination',
            'Select the receiving department before marking OUT.',
            400
        );
    }
    if ($destinationOfficeId === $officeId) {
        smartflow_reject_scan(
            $pdo,
            'movement.scan',
            $documentId,
            $userId,
            $officeId,
            $status,
            'same_destination',
            'Destination office must be different from your office.',
            400
        );
    }
    $stmtDest = $pdo->prepare('SELECT id, name, code FROM offices WHERE id = :id LIMIT 1');
    $stmtDest->execute([':id' => $destinationOfficeId]);
    $destOffice = $stmtDest->fetch();
    if (!$destOffice) {
        smartflow_reject_scan(
            $pdo,
            'movement.scan',
            $documentId,
            $userId,
            $officeId,
            $status,
            'destination_not_found',
            'Destination office not found.',
            400
        );
    }
    if (smartflow_document_trail_complete($pdo, $documentId)) {
        $holder = smartflow_last_movement($pdo, $documentId);
        $fromCode = '';
        if ($holder) {
            $codeStmt = $pdo->prepare('SELECT code FROM offices WHERE id = :id LIMIT 1');
            $codeStmt->execute([':id' => $holder['office_id']]);
            $fromCode = strtoupper((string)$codeStmt->fetchColumn());
        }
        $toCode = strtoupper((string)$destOffice['code']);
        if ($fromCode !== 'TRE' || $toCode !== 'ACC') {
            smartflow_reject_scan(
                $pdo,
                'movement.scan',
                $documentId,
                $userId,
                $officeId,
                $status,
                'route_finished',
                'This folder is filed. The route is finished.',
                409
            );
        }
    }
}

if ($isReturn) {
    if ($remarks === null || mb_strlen($remarks) < 5) {
        smartflow_reject_scan(
            $pdo,
            'movement.scan',
            $documentId,
            $userId,
            $officeId,
            $status,
            'return_reason_required',
            'Enter the reason for returning this folder (at least 5 characters).',
            400
        );
    }
    $stmtHeld = $pdo->prepare("
        SELECT 1 FROM movements
        WHERE document_id = :doc AND office_id = :dest AND status = 'IN'
        LIMIT 1
    ");
    $stmtHeld->execute([':doc' => $documentId, ':dest' => $destinationOfficeId]);
    if (!$stmtHeld->fetch()) {
        smartflow_reject_scan(
            $pdo,
            'movement.scan',
            $documentId,
            $userId,
            $officeId,
            $status,
            'return_not_previous_holder',
            'A folder can only be returned to an office that already received it.',
            400
        );
    }
    $remarks = 'Returned to ' . $destOffice['name'] . ' (' . $destOffice['code'] . '): ' . $remarks;
} elseif ($remarks === null || $remarks === '') {
    if ($status === 'IN') {
        $remarks = 'Received at ' . $user['office_name'];
    } else {
        $remarks = 'Forwarded from ' . $user['office_name']
            . ' → ' . $destOffice['name'] . ' (' . $destOffice['code'] . ')';
    }
}

$contentsReceipt = null;
if ($status === 'IN' && $doc['folder_inventory'] !== null) {
    try { $contentsReceipt = smartflow_receipt_validate(smartflow_contents_decode($doc['folder_inventory']), $body['contents_receipt'] ?? null); }
    catch (InvalidArgumentException $e) {
        smartflow_reject_scan($pdo, 'movement.scan', $documentId, $userId, $officeId, $status,
            'contents_check_required', $e->getMessage(), 400);
    }
    $remarks = ($remarks ? $remarks . "\n" : '') . smartflow_receipt_summary($contentsReceipt);
}

try {
    $stmt = $pdo->prepare('
        INSERT INTO movements (document_id, office_id, destination_office_id, status, user_id, remarks, contents_receipt, is_return)
        VALUES (:document_id, :office_id, :destination_office_id, :status, :user_id, :remarks, :contents_receipt, :is_return)
    ');
    $stmt->execute([
        ':document_id' => $documentId,
        ':office_id'   => $officeId,
        ':destination_office_id' => $status === 'OUT' ? $destinationOfficeId : null,
        ':status'      => $status,
        ':user_id'     => $userId,
        ':remarks'     => $remarks,
        ':contents_receipt' => $contentsReceipt === null ? null : json_encode($contentsReceipt, JSON_THROW_ON_ERROR),
        ':is_return' => $isReturn ? 1 : 0,
    ]);
    $movementId = (int)$pdo->lastInsertId();
    // Build and persist the exact successful response before committing the movement.
    $last = smartflow_last_movement($pdo, $documentId);
    $message = $status === 'IN'
        ? 'Document received (IN) at ' . $user['office_code']
        : 'Document ' . ($isReturn ? 'returned' : 'forwarded') . ' (OUT) from ' . $user['office_code'] . ' → ' . ($destOffice['code'] ?? '?');
    if ($contentsReceipt !== null && $contentsReceipt['status'] !== 'complete') $message .= ' · ' . ($contentsReceipt['status'] === 'incomplete' ? 'Incomplete contents recorded' : 'Contents discrepancy recorded');
    $response = [
        'success'=>true, 'message'=>$message, 'movement_id'=>$movementId, 'document_id'=>$documentId,
        'status'=>$status, 'is_return'=>$isReturn, 'office_id'=>$officeId, 'office_code'=>$user['office_code'],
        'destination_office_id'=>$status==='OUT'?$destinationOfficeId:null,
        'destination_office_code'=>$status==='OUT'?($destOffice['code']??null):null,
        'destination_office_name'=>$status==='OUT'?($destOffice['name']??null):null,
        'current_status'=>$last['status']??$status, 'current_office_id'=>$last['office_id']??$officeId,
        'current_office_name'=>$last['office_name']??$user['office_name'], 'contents_receipt'=>$contentsReceipt,
    ];
    if ($requestId !== null) {
        $saved = $pdo->prepare("UPDATE movement_requests SET state='recorded',response_json=? WHERE request_id=?");
        $saved->execute([json_encode($response,JSON_THROW_ON_ERROR),$requestId]);
    }
    $pdo->commit();
} catch (PDOException $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    smartflow_write_audit_log(
        $pdo,
        'movement.scan',
        $documentId,
        $userId,
        $officeId,
        $status,
        'failed',
        'Could not record movement',
        ['scan_error' => 'server_error']
    );
    json_response([
        'success' => false,
        'message' => 'Could not record movement. Try again in a moment.',
        'scan_error' => 'server_error',
    ], 500);
}

smartflow_write_audit_log(
    $pdo,
    'movement.scan',
    $documentId,
    $userId,
    $officeId,
    $status,
    'success',
    $message,
    [
        'destination_office_id' => $status === 'OUT' ? $destinationOfficeId : null,
        'is_return' => $isReturn,
        'movement_source' => $fromSystem ? 'system' : 'scan',
        'receipt_confirmed' => $fromSystem && $status === 'IN',
        'contents_status' => $contentsReceipt['status'] ?? null,
    ]
);

json_response($response);
