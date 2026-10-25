<?php
// POST /users-admin-set-email.php
// Body: { "user_id": 12, "email": "person@example.gov.ph" }
// Administrators correct the address that receives a user's password-reset code. Staff and head accounts
// only (administrators change their own address in Profile). The audit trail keeps masked addresses only.

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/audit-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$adminId = require_user_id();
smartflow_require_admin($pdo, $adminId);
smartflow_rate_limit('admin-set-email:' . $adminId, 60, 3600);
smartflow_ensure_users_email_column($pdo);

$body = get_json_body();
$targetId = (int)($body['user_id'] ?? 0);
$email = strtolower(trim((string)($body['email'] ?? '')));
if ($targetId <= 0) {
    json_response(['success' => false, 'message' => 'user_id is required'], 400);
}
if ($email === '' || strlen($email) > 120 || !filter_var($email, FILTER_VALIDATE_EMAIL)
    || !preg_match('/^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/', $email)) {
    json_response(['success' => false, 'message' => 'Enter a valid email address'], 400);
}

$mask = static function (string $address): string {
    if (!str_contains($address, '@')) return '';
    [$local, $domain] = explode('@', $address, 2);
    return substr($local, 0, 1) . str_repeat('*', max(2, strlen($local) - 1)) . '@' . $domain;
};

$pdo->beginTransaction();
smartflow_require_locked_admin($pdo, $adminId);
$stmt = $pdo->prepare('SELECT id, username, role, email FROM users WHERE id = :id LIMIT 1 FOR UPDATE');
$stmt->execute([':id' => $targetId]);
$target = $stmt->fetch();
if (!$target) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'User not found'], 404);
}
if (!in_array((string)$target['role'], ['staff', 'head'], true)) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'Administrators change their own email in Profile.'], 403);
}
$old = strtolower(trim((string)($target['email'] ?? '')));
if ($old === $email) {
    $pdo->rollBack();
    json_response(['success' => true, 'message' => 'That is already the email address on file.', 'unchanged' => true,
        'user' => ['id' => $targetId, 'username' => $target['username'], 'email' => $email]]);
}
$dup = $pdo->prepare('SELECT id FROM users WHERE email = :e AND id != :id LIMIT 1');
$dup->execute([':e' => $email, ':id' => $targetId]);
if ($dup->fetch()) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'That email address is already used by another account.'], 409);
}
$pdo->prepare('UPDATE users SET email = :e WHERE id = :id')->execute([':e' => $email, ':id' => $targetId]);
// An unused emailed code was sent to the previous address; it must not work for the new owner of the mailbox.
$pdo->prepare('UPDATE password_resets SET used_at = NOW() WHERE user_id = :id AND used_at IS NULL')->execute([':id' => $targetId]);
$pdo->commit();

smartflow_audit_action($pdo, 'user.email_update', $adminId, 'Changed the reset email address of ' . $target['username'], [
    'target_user_id' => $targetId,
    'username' => $target['username'],
    'from' => $mask($old),
    'to' => $mask($email),
]);

json_response([
    'success' => true,
    'message' => 'Email address updated.',
    'user' => ['id' => $targetId, 'username' => $target['username'], 'email' => $email],
]);
