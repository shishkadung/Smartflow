<?php
// POST /document-requests-create.php
// Body: {
//   "request_kind": "access|pull",
//   "document_category": "budget|payroll|disbursement",
//   "target_office_id": 1,   // required if pull
//   "purpose": "..."
// }

require __DIR__ . '/config.php';
require_once __DIR__ . '/document-requests-helper.php';

smartflow_ensure_document_requests($pdo);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
$stmt = $pdo->prepare('
    SELECT u.id, u.role, u.office_id, o.code AS office_code, o.name AS office_name
    FROM users u
    JOIN offices o ON o.id = u.office_id
    WHERE u.id = :id AND u.is_active = 1
    LIMIT 1
');
$stmt->execute([':id' => $userId]);
$user = $stmt->fetch();
if (!$user) {
    json_response(['success' => false, 'message' => 'User not found'], 401);
}

$body = get_json_body();
$kind = strtolower(trim((string)($body['request_kind'] ?? 'access')));
$category = trim((string)($body['document_category'] ?? ''));
$purpose = trim((string)($body['purpose'] ?? ''));
$targetOfficeId = isset($body['target_office_id']) ? (int)$body['target_office_id'] : null;
$requiredByRaw = trim((string)($body['required_by'] ?? ''));

if ($purpose === '') {
    json_response(['success' => false, 'message' => 'purpose is required'], 400);
}

if ($requiredByRaw === '') {
    json_response(['success' => false, 'message' => 'required_by date is required'], 400);
}

require_once __DIR__ . '/thresholds-helper.php';
$requiredBy = smartflow_parse_due_at_input($requiredByRaw);
if ($requiredBy === null) {
    json_response(['success' => false, 'message' => 'required_by must be YYYY-MM-DD'], 400);
}
$requiredByDate = substr($requiredBy, 0, 10);
if (strtotime($requiredByDate) < strtotime('today')) {
    json_response(['success' => false, 'message' => 'required_by cannot be in the past'], 400);
}

if (!smartflow_can_use_request_kind($user['role'], $kind)) {
    json_response(['success' => false, 'message' => 'Your role cannot create document requests'], 403);
}

$allowed = smartflow_allowed_categories_for_role($user['role']);
if ($category !== '' && !in_array(strtolower($category), $allowed, true)) {
    json_response(['success' => false, 'message' => 'Document category not allowed for your role'], 403);
}

$resolved = smartflow_resolve_document_request($pdo, $user, $kind, $category, $targetOfficeId);
$code = smartflow_generate_request_code($pdo);

$ins = $pdo->prepare('
    INSERT INTO document_requests (
        request_code, request_kind, document_category,
        requested_by, requester_office_id, requester_role,
        handler_office_id, target_office_id, purpose, required_by, status
    ) VALUES (
        :code, :kind, :cat,
        :uid, :roid, :role,
        :hoid, :toid, :purpose, :reqby, \'pending\'
    )
');
$ins->execute([
    ':code'    => $code,
    ':kind'    => $kind,
    ':cat'     => $resolved['document_category'],
    ':uid'     => $userId,
    ':roid'    => $user['office_id'],
    ':role'    => $user['role'],
    ':hoid'    => $resolved['handler_office_id'],
    ':toid'    => $resolved['target_office_id'],
    ':purpose' => $purpose,
    ':reqby'   => $requiredByDate,
]);

$id = (int)$pdo->lastInsertId();
$stmtRow = $pdo->prepare(SMARTFLOW_DR_SELECT . ' WHERE r.id = :id LIMIT 1');
$stmtRow->execute([':id' => $id]);
$row = $stmtRow->fetch();

json_response([
    'success' => true,
    'message' => 'Request submitted to ' . ($row['handler_office_name'] ?? 'handler office'),
    'request' => smartflow_format_document_request_row($row),
], 201);
