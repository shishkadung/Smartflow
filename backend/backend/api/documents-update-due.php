<?php
// POST /documents-update-due.php
// Body: { "document_id": "DOC-2026-000001", "due_at": "2026-05-30 17:00:00",
//         "expected_movement_id": 1, "expected_due_at": null }
// Pass due_at as null or "" to clear. Roles: admin, head.

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
smartflow_ensure_documents_due_column($pdo);

$stmtUser = $pdo->prepare('SELECT role, office_id FROM users WHERE id = :id LIMIT 1');
$stmtUser->execute([':id' => $userId]);
$caller = $stmtUser->fetch();
$role = (string)($caller['role'] ?? '');
if ($role !== 'admin' && $role !== 'head') {
    json_response(['success' => false, 'message' => 'Only admin or department head can set document due dates'], 403);
}

$body = get_json_body();
$docId = trim((string)($body['document_id'] ?? ''));
$displayedMovement = $body['expected_movement_id'] ?? null;
$expectedMovement = filter_var($displayedMovement, FILTER_VALIDATE_INT, ['options' => ['min_range' => 0]]);
$expectedDue = $body['expected_due_at'] ?? null;
if ($docId === '') {
    json_response(['success' => false, 'message' => 'document_id is required'], 400);
}
if ((!is_int($displayedMovement) && !is_string($displayedMovement)) || $expectedMovement === false || !array_key_exists('expected_due_at', $body)
    || ($expectedDue !== null && (!is_string($expectedDue)
        || smartflow_parse_due_at_input($expectedDue) !== $expectedDue))) {
    json_response(['success' => false, 'message' => 'Open the current folder and review its movement and saved deadline before changing it.', 'deadline_error' => 'confirmation_required'], 400);
}

$dueRaw = array_key_exists('due_at', $body) ? $body['due_at'] : null;
$dueAt = smartflow_parse_due_at_input(is_string($dueRaw) || is_numeric($dueRaw) ? (string)$dueRaw : null);
if ($dueRaw !== null && $dueRaw !== '' && $dueAt === null) {
    json_response(['success' => false, 'message' => 'Invalid due_at format'], 400);
}

$pdo->beginTransaction();
// Use the custody writers' document lock so scope validation and deadline write agree.
$stmt = $pdo->prepare('SELECT id, due_at FROM documents WHERE id = :id LIMIT 1 FOR UPDATE');
$stmt->execute([':id' => $docId]);
$document = $stmt->fetch();
$caller = smartflow_require_locked_writer($pdo, ['id'=>$userId] + $caller);
$role = (string)$caller['role'];
if (!$document) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'Document not found'], 404);
}
$scope = $pdo->prepare('SELECT id, office_id FROM movements WHERE document_id = ? ORDER BY scanned_at DESC, id DESC LIMIT 1');
$scope->execute([$docId]);
$latest = $scope->fetch();
if ($role !== 'admin') {
    if ((int)($latest['office_id'] ?? 0) !== (int)$caller['office_id']) {
        $pdo->rollBack();
        json_response(['success' => false, 'message' => 'Only the current office head can change this document deadline'], 403);
    }
}
if ((int)($latest['id'] ?? 0) !== $expectedMovement || $document['due_at'] !== $expectedDue) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'The folder moved or its deadline changed. Refresh and review the current record before editing.', 'deadline_error' => 'document_changed'], 409);
}

$upd = $pdo->prepare('UPDATE documents SET due_at = :due WHERE id = :id');
$upd->execute([
    ':due' => $dueAt,
    ':id'  => $docId,
]);
$pdo->commit();

$dueInfo = $dueAt !== null
    ? smartflow_manual_due_result($dueAt)
    : [
        'due_at'          => null,
        'due_at_display'  => '—',
        'hours_until_due' => 0,
        'is_overdue'      => false,
        'is_manual_due'   => false,
        'threshold_rule'  => 'Due date cleared — office rules apply after next scan',
    ];

json_response([
    'success'  => true,
    'document' => [
        'id'              => $docId,
        'manual_due_at'   => $dueAt,
        'due_at'          => $dueInfo['due_at'] ?: null,
        'due_at_display'  => $dueInfo['due_at_display'],
        'hours_until_due' => $dueInfo['hours_until_due'],
        'is_overdue'      => $dueInfo['is_overdue'],
        'is_manual_due'   => $dueInfo['is_manual_due'] ?? ($dueAt !== null),
        'threshold_rule'  => $dueInfo['threshold_rule'],
    ],
]);
