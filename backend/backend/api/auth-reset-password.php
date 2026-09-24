<?php
// POST /auth-reset-password.php
// Body: { "username": "...", "code": "...", "new_password": "..." }
// Validates the reset code and updates the password

require __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$body = get_json_body();
$username = trim((string)($body['username'] ?? ''));
$code = trim((string)($body['code'] ?? ''));
$newPassword = (string)($body['new_password'] ?? '');

if ($username === '' || $code === '' || $newPassword === '') {
    json_response(['success' => false, 'message' => 'Username, code, and new_password are required'], 400);
}

if (strlen($newPassword) < 8) {
    json_response(['success' => false, 'message' => 'New password must be at least 8 characters'], 400);
}

// Find user by username
$stmt = $pdo->prepare('
    SELECT id, username, is_active
    FROM users
    WHERE username = :username
    LIMIT 1
');
$stmt->execute([':username' => $username]);
$user = $stmt->fetch();

if (!$user || !(int)($user['is_active'] ?? 1)) {
    json_response(['success' => false, 'message' => 'Invalid username or reset code'], 401);
}

$userId = (int)$user['id'];

// Find the most recent unused, non-expired token for this user
$stmt = $pdo->prepare('
    SELECT id, token_hash, expires_at
    FROM password_resets
    WHERE user_id = :user_id
      AND used_at IS NULL
      AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1
');
$stmt->execute([':user_id' => $userId]);
$resetRecord = $stmt->fetch();

if (!$resetRecord || !password_verify($code, $resetRecord['token_hash'])) {
    json_response(['success' => false, 'message' => 'Invalid or expired reset code'], 401);
}

// Hash and update the new password
$passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);
$pdo->prepare('UPDATE users SET password_hash = :hash WHERE id = :id')
    ->execute([':hash' => $passwordHash, ':id' => $userId]);

// Mark the reset token as used
$pdo->prepare('UPDATE password_resets SET used_at = NOW() WHERE id = :id')
    ->execute([':id' => $resetRecord['id']]);

json_response([
    'success' => true,
    'message' => 'Password reset successfully. You can now log in with your new password.',
]);
