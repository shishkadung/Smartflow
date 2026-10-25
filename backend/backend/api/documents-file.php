<?php
// POST /documents-file.php
// The clerk holding an Others folder files it. Fixed routes finish on their own.
// Head and admin cannot file from the queue.

require __DIR__ . '/config.php';
require_once __DIR__ . '/movements-helper.php';
require_once __DIR__ . '/routing-helper.php';
require_once __DIR__ . '/audit-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

smartflow_ensure_documents_filed_columns($pdo);
$user = smartflow_require_authenticated_user($pdo, require_user_id());
if ((string)$user['role'] !== 'staff') {
    json_response(['success' => false, 'message' => 'Only the clerk holding the folder can file it.'], 403);
}

$body = get_json_body();
$documentId = trim((string)($body['document_id'] ?? ''));
$displayedMovement = $body['expected_movement_id'] ?? null;
$expectedMovement = filter_var($displayedMovement, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
if ($documentId === '') {
    json_response(['success' => false, 'message' => 'document_id is required'], 400);
}
if ((!is_int($displayedMovement) && !is_string($displayedMovement)) || $expectedMovement === false) {
    json_response(['success' => false, 'message' => 'Open the current folder and review its latest movement before filing.', 'file_error' => 'confirmation_required'], 400);
}

$pdo->beginTransaction();
$stmt = $pdo->prepare('SELECT id, type, filed_at FROM documents WHERE id = :id LIMIT 1 FOR UPDATE');
$stmt->execute([':id' => $documentId]);
$doc = $stmt->fetch();
$user = smartflow_require_locked_writer($pdo, $user);
if (!$doc) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'Document not found'], 404);
}
if (!empty($doc['filed_at']) || smartflow_document_trail_complete($pdo, $documentId)) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'This folder is already filed.'], 409);
}
if (smartflow_type_has_fixed_route((string)$doc['type'])) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'This folder follows a fixed route. It is filed when the last office receives it.'], 409);
}

$last = $pdo->prepare('
    SELECT m.id, m.status, m.office_id, o.name AS office_name
    FROM movements m
    JOIN offices o ON o.id = m.office_id
    WHERE m.document_id = :id
    ORDER BY m.scanned_at DESC, m.id DESC
    LIMIT 1
');
$last->execute([':id' => $documentId]);
$movement = $last->fetch();
if (!$movement || (int)$movement['id'] !== $expectedMovement) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'The folder moved since you opened it. Refresh and review its current custody before filing.', 'file_error' => 'document_changed'], 409);
}
$holding = $movement
    && strtoupper((string)$movement['status']) === 'IN'
    && (int)$movement['office_id'] === (int)$user['office_id'];
if (!$holding) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'File it only while the folder is at your desk.'], 409);
}

$update = $pdo->prepare('UPDATE documents SET filed_at = NOW(), filed_by = :user WHERE id = :id AND filed_at IS NULL');
$update->execute([':user' => (int)$user['id'], ':id' => $documentId]);
if ($update->rowCount() !== 1) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'This folder is already filed.'], 409);
}

smartflow_write_audit_log(
    $pdo,
    'document.file',
    $documentId,
    (int)$user['id'],
    (int)$user['office_id'],
    'IN',
    'ok',
    'Folder filed by the holding office'
);
$pdo->commit();

json_response([
    'success' => true,
    'message' => 'Filed. This folder is done.',
    'document_id' => $documentId,
]);
