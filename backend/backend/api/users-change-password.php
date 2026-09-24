<?php
// POST /users-change-password.php
// Body: { "current_password": "...", "new_password": "..." }

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();

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

$stmt = $pdo->prepare('SELECT password_hash FROM users WHERE id = :id LIMIT 1');
$stmt->execute([':id' => $userId]);
$row = $stmt->fetch();
if (!$row) {
    json_response(['success' => false, 'message' => 'User not found'], 404);
}

if (!password_verify($current, (string)$row['password_hash'])) {
    json_response(['success' => false, 'message' => 'Current password is incorrect'], 401);
}

$hash = password_hash($new, PASSWORD_DEFAULT);
$pdo->prepare('UPDATE users SET password_hash = :hash WHERE id = :id')
    ->execute([':hash' => $hash, ':id' => $userId]);

json_response([
    'success' => true,
    'message' => 'Password changed successfully',
]);
