<?php
// POST /documents
// Body: { "title": "...", "type": "...", "origin_office_id": 1, "description": "...", "request_id": 1 }
// request_id optionally links an approved request when its handler registers the physical folder.
// Auth: Bearer token required (user id extracted from token)

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/movements-helper.php';
require_once __DIR__ . '/qr-token-helper.php';
require_once __DIR__ . '/documents-logbook-helper.php';
require_once __DIR__ . '/folder-contents-helper.php';
require_once __DIR__ . '/document-requests-helper.php';
require_once __DIR__ . '/creation-requests-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

$userId = require_user_id();

$stmtUser = $pdo->prepare('SELECT role, office_id FROM users WHERE id = :id LIMIT 1');
$stmtUser->execute([':id' => $userId]);
$creator = $stmtUser->fetch();
if (!$creator) {
    json_response(['success' => false, 'message' => 'User not found'], 401);
}
$role = (string)$creator['role'];
$creatorOfficeId = (int)$creator['office_id'];
if ($role !== 'staff') {
    json_response([
        'success' => false,
        'message' => 'Only office staff can register physical folders. Heads and administrators monitor custody.',
    ], 403);
}

$body = get_json_body();
try { $operationId = smartflow_creation_id($body['operation_id'] ?? null); }
catch (InvalidArgumentException $e) { json_response(['success'=>false,'message'=>$e->getMessage()],400); }
smartflow_ensure_creation_requests($pdo);
try {
    $replay = smartflow_replay_creation($pdo, $operationId, $userId, 'document', $body);
    if ($replay !== null) json_response($replay, 201);
} catch (InvalidArgumentException $e) { json_response(['success'=>false,'message'=>$e->getMessage()], $e->getCode()); }
$title = trim((string)($body['title'] ?? ''));
$type = trim((string)($body['type'] ?? ''));
$originOfficeId = (int)($body['origin_office_id'] ?? 0);
$comment = isset($body['description']) ? trim((string)$body['description']) : '';
$payee = trim((string)($body['payee'] ?? ''));
$fundSource = trim((string)($body['fund_source'] ?? ''));
$referenceNo = trim((string)($body['reference_no'] ?? ''));
$receivedFromOfficeId = isset($body['received_from_office_id']) ? (int)$body['received_from_office_id'] : 0;
$requestId = (int)($body['request_id'] ?? 0);
if (isset($body['request_id']) && (filter_var($body['request_id'], FILTER_VALIDATE_INT) === false || $requestId <= 0)) {
    json_response(['success' => false, 'message' => 'request_id must be a positive request ID'], 400);
}

smartflow_ensure_documents_due_column($pdo);
smartflow_ensure_documents_logbook_columns($pdo);
smartflow_ensure_folder_contents($pdo);
smartflow_ensure_documents_qr_column($pdo);
$inventory = null;
if (array_key_exists('folder_inventory', $body)) {
    try { $inventory = smartflow_inventory_validate($body['folder_inventory']); }
    catch (InvalidArgumentException $e) { json_response(['success' => false, 'message' => $e->getMessage()], 400); }
}
$dueAt = null;
if (array_key_exists('due_at', $body)) {
    $dueAt = smartflow_parse_due_at_input(is_string($body['due_at']) ? $body['due_at'] : null);
    if ($body['due_at'] !== null && $body['due_at'] !== '' && $dueAt === null) {
        json_response(['success' => false, 'message' => 'Invalid due_at format'], 400);
    }
}

if ($title === '' || $type === '' || $originOfficeId <= 0) {
    json_response([
        'success' => false,
        'message' => 'title, type, and origin_office_id are required',
    ], 400);
}
if (mb_strlen($title) < 3 || mb_strlen($title) > 200 || mb_strlen($type) > 50
    || mb_strlen($referenceNo) > 100 || mb_strlen($payee) > 200 || mb_strlen($fundSource) > 100) {
    json_response(['success' => false, 'message' => 'Title must be 3–200 characters; type, reference, payee, and fund must fit their field limits'], 400);
}

$stmtOffice = $pdo->prepare('SELECT id FROM offices WHERE id = :id LIMIT 1');
$stmtOffice->execute([':id' => $originOfficeId]);
if (!$stmtOffice->fetch()) {
    json_response(['success' => false, 'message' => 'Origin office not found'], 400);
}

// Staff may register only a folder physically held by their assigned office.
if ($originOfficeId !== $creatorOfficeId) {
    json_response([
        'success' => false,
        'message' => 'You can only register documents your office physically holds (your assigned office)',
    ], 403);
}

$stmtCode = $pdo->prepare('SELECT code FROM offices WHERE id = :id LIMIT 1');
$stmtCode->execute([':id' => $originOfficeId]);
$originCode = strtoupper((string)($stmtCode->fetchColumn() ?: ''));
$typesByOffice = [
    'ENG' => ['Disbursement Voucher'],
    'HR' => [],
    'BUD' => ['Approved Budget'],
    'ACC' => ['Disbursement Voucher', 'Approved Budget'],
    'TRE' => ['Disbursement Voucher'],
    'MAY' => ['Disbursement Voucher'],
];
$knownTypes = $typesByOffice[$originCode] ?? ['Disbursement Voucher', 'Approved Budget'];
$otherName = '';
if (str_starts_with($type, 'Others:')) {
    $otherName = trim(substr($type, strlen('Others:')));
}
if (!in_array($type, $knownTypes, true) && strlen($otherName) < 3) {
    json_response([
        'success' => false,
        'message' => 'Choose Disbursement Voucher, Approved Budget, or name the folder under Others',
    ], 400);
}

$missingLogbook = smartflow_missing_logbook_fields($type, $referenceNo, $payee, $fundSource);
if ($missingLogbook !== []) {
    json_response([
        'success' => false,
        'message' => 'Logbook fields required for ' . $type . ': ' . implode(', ', $missingLogbook),
    ], 400);
}

$receivedFrom = null;
if ($originCode === 'ACC' && $type === 'Disbursement Voucher') {
    if ($receivedFromOfficeId <= 0 || $receivedFromOfficeId === $originOfficeId) {
        json_response([
            'success' => false,
            'message' => 'Accounting does not originate project DVs — choose the office that sent this folder',
        ], 400);
    }
    $stmtFrom = $pdo->prepare('SELECT id, name, code FROM offices WHERE id = :id LIMIT 1');
    $stmtFrom->execute([':id' => $receivedFromOfficeId]);
    $receivedFrom = $stmtFrom->fetch() ?: null;
    if ($receivedFrom === null) {
        json_response(['success' => false, 'message' => 'Received-from office not found'], 400);
    }
} else {
    $receivedFromOfficeId = 0;
}

$logbookParts = [];
if ($referenceNo !== '') {
    $logbookParts[] = 'Reference: ' . $referenceNo;
}
if ($payee !== '') {
    $logbookParts[] = 'Payee: ' . $payee;
}
if ($fundSource !== '') {
    $logbookParts[] = 'Fund source: ' . $fundSource;
}
if ($receivedFrom !== null) {
    $logbookParts[] = 'Received from: ' . $receivedFrom['name'] . ' (' . $receivedFrom['code'] . ')';
}

$description = null;
if ($comment !== '' && $logbookParts !== []) {
    $description = $comment . "\n\n" . implode("\n", $logbookParts);
} elseif ($comment !== '') {
    $description = $comment;
} elseif ($logbookParts !== []) {
    $description = implode("\n", $logbookParts);
}

// Generate document id: DOC-YYYY-000001 (use max sequence, not COUNT — avoids duplicates after deletes/gaps)
$year = (int)date('Y');
$prefix = "DOC-$year-%";
$stmtMax = $pdo->prepare('
    SELECT MAX(CAST(SUBSTRING_INDEX(id, "-", -1) AS UNSIGNED)) AS max_seq
    FROM documents
    WHERE id LIKE :prefix
');
$stmtMax->execute([':prefix' => $prefix]);
$maxSeq = (int)($stmtMax->fetch()['max_seq'] ?? 0);
$next = $maxSeq + 1;

$pdo->beginTransaction();
try {
    $saved = smartflow_lock_creation($pdo, $operationId, $userId, 'document', $body);
    if ($saved !== null) { $pdo->commit(); json_response($saved, 201); }
    $inserted = false;
    $docId = '';
    for ($attempt = 0; $attempt < 5; $attempt++) {
        $docId = sprintf('DOC-%d-%06d', $year, $next + $attempt);
        try {
            $stmt = $pdo->prepare('
                INSERT INTO documents (
                    id, title, type, origin_office_id, description,
                    reference_no, payee, fund_source, received_from_office_id,
                    due_at, created_by, folder_inventory
                )
                VALUES (
                    :id, :title, :type, :origin_office_id, :description,
                    :reference_no, :payee, :fund_source, :received_from,
                    :due_at, :created_by, :folder_inventory
                )
            ');
            $stmt->execute([
                ':id' => $docId,
                ':title' => $title,
                ':type' => $type,
                ':origin_office_id' => $originOfficeId,
                ':description' => $description,
                ':reference_no' => $referenceNo !== '' ? $referenceNo : null,
                ':payee' => $payee !== '' ? $payee : null,
                ':fund_source' => $fundSource !== '' ? $fundSource : null,
                ':received_from' => $receivedFromOfficeId > 0 ? $receivedFromOfficeId : null,
                ':due_at' => $dueAt,
                ':created_by' => $userId,
                ':folder_inventory' => $inventory === null ? null : json_encode($inventory, JSON_THROW_ON_ERROR),
            ]);
            $inserted = true;
            break;
        } catch (PDOException $e) {
            if ((int)($e->errorInfo[1] ?? 0) !== 1062) {
                throw $e;
            }
        }
    }
    if (!$inserted) {
        throw new RuntimeException('Could not assign document ID — try again');
    }

    // Document starts physically at the origin office — log initial IN for tracking.
    $stmtIn = $pdo->prepare('
        INSERT INTO movements (document_id, office_id, status, user_id, remarks)
        VALUES (:doc, :oid, \'IN\', :uid, :rm)
    ');
    $stmtIn->execute([
        ':doc' => $docId,
        ':oid' => $originOfficeId,
        ':uid' => $userId,
        ':rm'  => $receivedFrom !== null
            ? 'Registered at Accounting — folder received without QR from ' . $receivedFrom['code']
            : 'Registered and received at origin office',
    ]);
    $initialIn = true;

    $qrIssued = smartflow_document_qr($pdo, $docId);
    if ($requestId > 0) {
        $creator['id'] = $userId;
        $linkedRequest = smartflow_link_request_document($pdo, $creator, $requestId, $docId);
        smartflow_audit_action($pdo, 'request.link', $userId,
            'Linked request ' . $linkedRequest['request_code'] . ' while registering its physical folder',
            ['request_id' => $requestId, 'request_code' => $linkedRequest['request_code'], 'source' => 'registration'], $docId);
    }
    $response = [
        'success' => true,
        'message' => 'Document registered and marked IN at origin office',
        'document' => [
            'id' => $docId, 'request_id' => $requestId > 0 ? $requestId : null,
            'title' => $title, 'type' => $type, 'origin_office_id' => $originOfficeId,
            'reference_no' => $referenceNo !== '' ? $referenceNo : null,
            'payee' => $payee !== '' ? $payee : null, 'fund_source' => $fundSource !== '' ? $fundSource : null,
            'received_from_office_code' => $receivedFrom['code'] ?? null,
            'qr_payload' => $qrIssued['payload'], 'qr_expires_at' => $qrIssued['expires_at'],
            'due_at' => $dueAt, 'due_at_display' => $dueAt ? smartflow_due_at_display($dueAt) : null,
            'initial_in_recorded' => $initialIn, 'folder_inventory' => $inventory,
            'contents_status' => $inventory['status'] ?? 'unrecorded',
        ],
    ];
    smartflow_save_creation($pdo, $operationId, $response);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    if ($e instanceof InvalidArgumentException && $e->getCode() >= 400 && $e->getCode() <= 499) {
        json_response(['success' => false, 'message' => $e->getMessage()], $e->getCode());
    }
    smartflow_log('error', 'Document registration rolled back', ['error' => $e->getMessage()]);
    json_response(['success' => false, 'message' => 'Could not register the folder; no document or request link was saved'], 500);
}

json_response($response, 201);

