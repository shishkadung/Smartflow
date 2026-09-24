<?php
// POST /documents
// Body: { "title": "...", "type": "...", "origin_office_id": 1, "description": "..." }
// Auth: Bearer token required (user id extracted from token)

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/movements-helper.php';
require_once __DIR__ . '/qr-token-helper.php';

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

$body = get_json_body();
$title = trim((string)($body['title'] ?? ''));
$type = trim((string)($body['type'] ?? ''));
$originOfficeId = (int)($body['origin_office_id'] ?? 0);
$description = isset($body['description']) ? trim((string)$body['description']) : null;
$payee = trim((string)($body['payee'] ?? ''));
$fundSource = trim((string)($body['fund_source'] ?? ''));
$referenceNo = trim((string)($body['reference_no'] ?? ''));

if ($description === null || $description === '') {
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
    if ($logbookParts !== []) {
        $description = implode("\n", $logbookParts);
    }
}
smartflow_ensure_documents_due_column($pdo);
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

$stmtOffice = $pdo->prepare('SELECT id FROM offices WHERE id = :id LIMIT 1');
$stmtOffice->execute([':id' => $originOfficeId]);
if (!$stmtOffice->fetch()) {
    json_response(['success' => false, 'message' => 'Origin office not found'], 400);
}

$role = (string)$creator['role'];
$creatorOfficeId = (int)$creator['office_id'];
$allowedRoles = ['admin', 'staff', 'head'];
if (!in_array($role, $allowedRoles, true)) {
    json_response([
        'success' => false,
        'message' => 'Your role cannot register documents',
    ], 403);
}
if ($role !== 'admin' && $originOfficeId !== $creatorOfficeId) {
    json_response([
        'success' => false,
        'message' => 'You can only register documents for your assigned office',
    ], 403);
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

$inserted = false;
$docId = '';
for ($attempt = 0; $attempt < 5; $attempt++) {
    $docId = sprintf('DOC-%d-%06d', $year, $next + $attempt);
    try {
        $stmt = $pdo->prepare('
            INSERT INTO documents (id, title, type, origin_office_id, description, due_at, created_by)
            VALUES (:id, :title, :type, :origin_office_id, :description, :due_at, :created_by)
        ');
        $stmt->execute([
            ':id' => $docId,
            ':title' => $title,
            ':type' => $type,
            ':origin_office_id' => $originOfficeId,
            ':description' => $description,
            ':due_at' => $dueAt,
            ':created_by' => $userId,
        ]);
        $inserted = true;
        break;
    } catch (PDOException $e) {
        if ((int)($e->errorInfo[1] ?? 0) !== 1062) {
            json_response([
                'success' => false,
                'message' => 'Could not create document',
            ], 500);
        }
    }
}
if (!$inserted) {
    json_response([
        'success' => false,
        'message' => 'Could not assign document ID — try again',
    ], 500);
}

// Document starts physically at the origin office — log initial IN for tracking.
$initialIn = false;
try {
    $stmtIn = $pdo->prepare('
        INSERT INTO movements (document_id, office_id, status, user_id, remarks)
        VALUES (:doc, :oid, \'IN\', :uid, :rm)
    ');
    $stmtIn->execute([
        ':doc' => $docId,
        ':oid' => $originOfficeId,
        ':uid' => $userId,
        ':rm'  => 'Registered and received at origin office',
    ]);
    $initialIn = true;
} catch (PDOException $e) {
    // Document exists; clerk can mark IN manually on scanner.
}

try {
    $qrIssued = smartflow_qr_issue($docId);
} catch (InvalidArgumentException $e) {
    json_response(['success' => false, 'message' => 'Could not issue QR label'], 500);
}

json_response([
    'success' => true,
    'message' => $initialIn
        ? 'Document registered and marked IN at origin office'
        : 'Document registered — mark IN on scanner if needed',
    'document' => [
        'id' => $docId,
        'title' => $title,
        'type' => $type,
        'origin_office_id' => $originOfficeId,
        'qr_payload' => $qrIssued['payload'],
        'qr_expires_at' => $qrIssued['expires_at'],
        'due_at' => $dueAt,
        'due_at_display' => $dueAt ? smartflow_due_at_display($dueAt) : null,
        'initial_in_recorded' => $initialIn,
    ],
], 201);

