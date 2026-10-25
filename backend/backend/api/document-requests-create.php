<?php
// POST /document-requests-create.php
// Body: {
//   "request_kind": "access|pull",
//   "document_category": "budget|disbursement|other",
//   "target_office_id": 1,   // required if pull
//   "purpose": "..."
// }

require __DIR__ . '/config.php';
require_once __DIR__ . '/document-requests-helper.php';
require_once __DIR__ . '/creation-requests-helper.php';

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
try { $operationId = smartflow_creation_id($body['operation_id'] ?? null); }
catch (InvalidArgumentException $e) { json_response(['success'=>false,'message'=>$e->getMessage()],400); }
smartflow_ensure_creation_requests($pdo);
try {
    $replay = smartflow_replay_creation($pdo, $operationId, $userId, 'request', $body);
    if ($replay !== null) json_response($replay, 201);
} catch (InvalidArgumentException $e) { json_response(['success'=>false,'message'=>$e->getMessage()], $e->getCode()); }
$kind = strtolower(trim((string)($body['request_kind'] ?? 'access')));
$category = trim((string)($body['document_category'] ?? ''));
$purpose = trim((string)($body['purpose'] ?? ''));
$targetOfficeId = null;
if (isset($body['target_office_id'])) {
    $targetOfficeId = filter_var($body['target_office_id'], FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    if ((!is_int($body['target_office_id']) && !is_string($body['target_office_id'])) || $targetOfficeId === false) {
        json_response(['success' => false, 'message' => 'target_office_id must be a positive office ID'], 400);
    }
}
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

if (strtolower($category) === 'payroll') {
    json_response([
        'success' => false,
        'message' => 'Payroll is payslip access only in Phase 1 — Accounting prepares payroll',
    ], 400);
}

$allowed = smartflow_allowed_categories_for_role($user['role']);
if ($category !== '' && !in_array(strtolower($category), $allowed, true)) {
    json_response(['success' => false, 'message' => 'Document category not allowed for your role'], 403);
}

$resolved = smartflow_resolve_document_request($pdo, $user, $kind, $category, $targetOfficeId);
$pdo->beginTransaction();
try {
$saved = smartflow_lock_creation($pdo, $operationId, $userId, 'request', $body);
if ($saved !== null) { $pdo->commit(); json_response($saved, 201); }
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
$insertBody = [
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
];
$inserted = false;
for ($attempt = 0; $attempt < 5; $attempt++) {
    if ($attempt > 0) $insertBody[':code'] = preg_replace_callback('/(\d+)$/', static fn($m) => str_pad((string)((int)$m[1] + $attempt), strlen($m[1]), '0', STR_PAD_LEFT), $code);
    try { $ins->execute($insertBody); $inserted = true; break; }
    catch (PDOException $e) { if ((int)($e->errorInfo[1] ?? 0) !== 1062) throw $e; }
}
if (!$inserted) throw new RuntimeException('Could not assign a request code');

$id = (int)$pdo->lastInsertId();
$stmtRow = $pdo->prepare(SMARTFLOW_DR_SELECT . ' WHERE r.id = :id LIMIT 1');
$stmtRow->execute([':id' => $id]);
$row = $stmtRow->fetch();
smartflow_require_locked_writer($pdo, $user);

$response = [
    'success' => true,
    'message' => 'Request submitted to ' . ($row['handler_office_name'] ?? 'handler office'),
    'request' => smartflow_format_document_request_row($row),
];
smartflow_save_creation($pdo, $operationId, $response);
$pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    smartflow_reject_write_conflict($pdo, $e);
    if ($e instanceof InvalidArgumentException && $e->getCode() >= 400 && $e->getCode() <= 499) json_response(['success'=>false,'message'=>$e->getMessage()],$e->getCode());
    smartflow_log('error','Request creation rolled back',['error'=>$e->getMessage()]);
    json_response(['success'=>false,'message'=>'Could not submit request; no ticket was saved'],500);
}
json_response($response, 201);
