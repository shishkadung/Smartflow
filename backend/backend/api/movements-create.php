<?php
// POST /movements-create.php
// Body: { "document_id": "DOC-2026-000001", "office_id": 1, "status": "IN|OUT", "remarks": "..." }
// Return (incomplete / sent back): { ..., "status": "OUT", "is_return": true, "remarks": "<reason>" }
//   destination must be an office that already held the folder; reason is required.
// Auth: Bearer token required (user id extracted from token)

require __DIR__ . '/config.php';
require_once __DIR__ . '/movements-helper.php';
require_once __DIR__ . '/qr-token-helper.php';

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

$stmtDoc = $pdo->prepare('SELECT id, title FROM documents WHERE id = :id LIMIT 1');
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
        'Document not found. Ask Accounting to register the document and print its QR label.',
        404
    );
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

try {
    $stmt = $pdo->prepare('
        INSERT INTO movements (document_id, office_id, destination_office_id, status, user_id, remarks)
        VALUES (:document_id, :office_id, :destination_office_id, :status, :user_id, :remarks)
    ');
    $stmt->execute([
        ':document_id' => $documentId,
        ':office_id'   => $officeId,
        ':destination_office_id' => $status === 'OUT' ? $destinationOfficeId : null,
        ':status'      => $status,
        ':user_id'     => $userId,
        ':remarks'     => $remarks,
    ]);
} catch (PDOException $e) {
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

$last = smartflow_last_movement($pdo, $documentId);

$message = $status === 'IN'
    ? 'Document received (IN) at ' . $user['office_code']
    : 'Document ' . ($isReturn ? 'returned' : 'forwarded') . ' (OUT) from ' . $user['office_code']
        . ' → ' . ($destOffice['code'] ?? '?');

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
    ]
);

json_response([
    'success' => true,
    'message' => $message,
    'movement_id' => (int)$pdo->lastInsertId(),
    'document_id' => $documentId,
    'status'      => $status,
    'is_return'   => $isReturn,
    'office_id'   => $officeId,
    'office_code' => $user['office_code'],
    'destination_office_id' => $status === 'OUT' ? $destinationOfficeId : null,
    'destination_office_code' => $status === 'OUT' ? ($destOffice['code'] ?? null) : null,
    'destination_office_name' => $status === 'OUT' ? ($destOffice['name'] ?? null) : null,
    'current_status' => $last['status'] ?? $status,
    'current_office_id' => $last['office_id'] ?? $officeId,
    'current_office_name' => $last['office_name'] ?? $user['office_name'],
]);
