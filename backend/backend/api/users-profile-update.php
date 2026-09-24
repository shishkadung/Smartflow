<?php
// POST /users-profile-update.php
// Body: { "name": "...", "username": "...", "email": "..." } — updates logged-in user only.

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
smartflow_ensure_users_active_column($pdo);
smartflow_ensure_users_email_column($pdo);

$body = get_json_body();
$name = trim((string)($body['name'] ?? ''));
$username = trim((string)($body['username'] ?? ''));
$email = trim((string)($body['email'] ?? ''));

if ($name === '') {
    json_response(['success' => false, 'message' => 'Name is required'], 400);
}
if ($username === '') {
    json_response(['success' => false, 'message' => 'Username is required'], 400);
}
if (strlen($username) < 3) {
    json_response(['success' => false, 'message' => 'Username must be at least 3 characters'], 400);
}
if (!preg_match('/^[a-zA-Z0-9._-]+$/', $username)) {
    json_response([
        'success' => false,
        'message' => 'Username may only use letters, numbers, dots, dashes, and underscores',
    ], 400);
}
if ($email === '') {
    json_response(['success' => false, 'message' => 'Email is required'], 400);
}
if (strlen($email) > 120 || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_response(['success' => false, 'message' => 'Enter a valid email address'], 400);
}

$current = smartflow_fetch_user_by_id($pdo, $userId);
if (!$current) {
    json_response(['success' => false, 'message' => 'User not found'], 404);
}

if (strcasecmp($username, (string)$current['username']) !== 0) {
    $stmtDup = $pdo->prepare('SELECT id FROM users WHERE username = :u AND id != :id LIMIT 1');
    $stmtDup->execute([':u' => $username, ':id' => $userId]);
    if ($stmtDup->fetch()) {
        json_response(['success' => false, 'message' => 'Username is already taken'], 409);
    }
}

$currentEmail = trim((string)($current['email'] ?? ''));
if (strcasecmp($email, $currentEmail) !== 0) {
    $stmtEmail = $pdo->prepare('SELECT id FROM users WHERE email = :e AND id != :id LIMIT 1');
    $stmtEmail->execute([':e' => $email, ':id' => $userId]);
    if ($stmtEmail->fetch()) {
        json_response(['success' => false, 'message' => 'Email is already in use'], 409);
    }
}

$upd = $pdo->prepare('UPDATE users SET name = :name, username = :username, email = :email WHERE id = :id');
$upd->execute([
    ':name'     => $name,
    ':username' => $username,
    ':email'    => $email,
    ':id'       => $userId,
]);

$updated = smartflow_fetch_user_by_id($pdo, $userId);
if (!$updated) {
    json_response(['success' => false, 'message' => 'Could not load updated profile'], 500);
}

json_response([
    'success' => true,
    'message' => 'Profile updated',
    'user'    => smartflow_user_payload($updated),
]);
