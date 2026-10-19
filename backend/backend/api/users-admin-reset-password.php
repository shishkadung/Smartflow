<?php
// POST /users-admin-reset-password.php
// Body: { "user_id": 12 }
// Backup for users whose reset email does not work. An administrator issues a temporary password that is
// shown once in this response and never stored in readable form. The user must replace it at the next
// sign-in, and it stops working after 24 hours. Existing sessions of that user end immediately.
// Limits: staff and head accounts only (never your own or another administrator's), active accounts only.

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/audit-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$adminId = require_user_id();
smartflow_require_admin($pdo, $adminId);
smartflow_rate_limit('admin-password-reset:' . $adminId, 10, 3600);
smartflow_ensure_users_password_reset_columns($pdo);

$body = get_json_body();
$targetId = (int)($body['user_id'] ?? 0);
if ($targetId <= 0) {
    json_response(['success' => false, 'message' => 'user_id is required'], 400);
}
if ($targetId === $adminId) {
    json_response(['success' => false, 'message' => 'Use Change password in your own profile instead.'], 403);
}

$pdo->beginTransaction();
smartflow_require_locked_admin($pdo, $adminId);
$stmt = $pdo->prepare('SELECT id, name, username, role, is_active FROM users WHERE id = :id LIMIT 1 FOR UPDATE');
$stmt->execute([':id' => $targetId]);
$target = $stmt->fetch();
if (!$target) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'User not found'], 404);
}
if (!in_array((string)$target['role'], ['staff', 'head'], true)) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'Administrator accounts cannot be reset here.'], 403);
}
if (!(int)$target['is_active']) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'Activate the account before resetting its password.'], 409);
}

// 12 characters from an alphabet without look-alikes (no 0/O, 1/l/I).
$alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
$temporary = '';
for ($i = 0; $i < 12; $i++) {
    $temporary .= $alphabet[random_int(0, strlen($alphabet) - 1)];
}

$pdo->prepare('UPDATE users SET password_hash = :hash, must_change_password = 1,
        temp_password_expires_at = DATE_ADD(NOW(), INTERVAL 24 HOUR) WHERE id = :id')
    ->execute([':hash' => password_hash($temporary, PASSWORD_DEFAULT), ':id' => $targetId]);
// Retire emailed codes and end every session so only the temporary password can start a new one.
$pdo->prepare('UPDATE password_resets SET used_at = NOW() WHERE user_id = :id AND used_at IS NULL')->execute([':id' => $targetId]);
revoke_user_tokens($targetId);
$expires = (string)$pdo->query('SELECT temp_password_expires_at FROM users WHERE id = ' . $targetId)->fetchColumn();
$pdo->commit();

smartflow_audit_action($pdo, 'user.password_admin_reset', $adminId, 'Issued a temporary password for ' . $target['username'], [
    'target_user_id' => $targetId,
    'username' => $target['username'],
    'role' => $target['role'],
]);

json_response([
    'success' => true,
    'message' => 'Temporary password issued. It is shown only once.',
    'user' => ['id' => $targetId, 'name' => $target['name'], 'username' => $target['username']],
    'temporary_password' => $temporary,
    'expires_at' => $expires,
    'must_change_password' => true,
]);
