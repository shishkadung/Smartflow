<?php
// POST /users-change-password.php
// Body: { "current_password": "...", "new_password": "..." }

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';
require_once __DIR__ . '/audit-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
smartflow_ensure_users_password_reset_columns($pdo);

$body = get_json_body();
$current = (string)($body['current_password'] ?? '');
$new = (string)($body['new_password'] ?? '');

if ($current === '' || $new === '') {
    json_response(['success' => false, 'message' => 'current_password and new_password are required'], 400);
}
if (strlen($new) < 8) {
    json_response(['success' => false, 'message' => 'New password must be at least 8 characters'], 400);
}
if ($current === $new) {
    json_response(['success' => false, 'message' => 'New password must be different from current password'], 400);
}

$pdo->beginTransaction();
$stmt = $pdo->prepare('SELECT id, role, office_id, password_hash, is_active FROM users WHERE id = :id LIMIT 1 FOR UPDATE');
$stmt->execute([':id' => $userId]);
$row = $stmt->fetch();
if (!$row) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'User not found'], 404);
}

smartflow_require_locked_writer($pdo, $row, true);
if (!password_verify($current, (string)$row['password_hash'])) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'Current password is incorrect'], 400);
}

$hash = password_hash($new, PASSWORD_DEFAULT);
// Choosing a password also ends any administrator-issued temporary password.
$pdo->prepare('UPDATE users SET password_hash = :hash, must_change_password = 0, temp_password_expires_at = NULL WHERE id = :id')
    ->execute([':hash' => $hash, ':id' => $userId]);
revoke_user_tokens($userId);
$pdo->commit();

smartflow_audit_action($pdo, 'user.password_change', $userId, 'Changed own password');

json_response([
    'success' => true,
    'message' => 'Password changed. Sign in again with your new password.',
    'reauthenticate' => true,
]);
