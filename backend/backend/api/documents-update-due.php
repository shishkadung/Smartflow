<?php
// POST /documents-update-due.php
// Body: { "document_id": "DOC-2026-000001", "due_at": "2026-05-30 17:00:00" }
// Pass due_at as null or "" to clear. Roles: admin, head.

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
smartflow_ensure_documents_due_column($pdo);

$stmtUser = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
$stmtUser->execute([':id' => $userId]);
$role = (string)$stmtUser->fetchColumn();
if ($role !== 'admin' && $role !== 'head') {
    json_response(['success' => false, 'message' => 'Only admin or department head can set document due dates'], 403);
}

$body = get_json_body();
$docId = trim((string)($body['document_id'] ?? ''));
if ($docId === '') {
    json_response(['success' => false, 'message' => 'document_id is required'], 400);
}

$dueRaw = array_key_exists('due_at', $body) ? $body['due_at'] : null;
$dueAt = smartflow_parse_due_at_input(is_string($dueRaw) || is_numeric($dueRaw) ? (string)$dueRaw : null);

$stmt = $pdo->prepare('SELECT id FROM documents WHERE id = :id LIMIT 1');
$stmt->execute([':id' => $docId]);
if (!$stmt->fetch()) {
    json_response(['success' => false, 'message' => 'Document not found'], 404);
}

$upd = $pdo->prepare('UPDATE documents SET due_at = :due WHERE id = :id');
$upd->execute([
    ':due' => $dueAt,
    ':id'  => $docId,
]);

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
        'due_at'          => $dueInfo['due_at'] ?: null,
        'due_at_display'  => $dueInfo['due_at_display'],
        'hours_until_due' => $dueInfo['hours_until_due'],
        'is_overdue'      => $dueInfo['is_overdue'],
        'is_manual_due'   => $dueInfo['is_manual_due'] ?? ($dueAt !== null),
        'threshold_rule'  => $dueInfo['threshold_rule'],
    ],
]);
