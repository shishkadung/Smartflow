<?php
// POST: revoke only the presented session. Repeating a completed logout is safe.
require __DIR__ . '/config.php';

header('Cache-Control: no-store');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}
$token = get_bearer_token();
if (!$token) {
    json_response(['success' => false, 'message' => 'Missing or invalid token'], 401);
}
$stmt = $pdo->prepare('UPDATE auth_tokens SET is_revoked = 1 WHERE token_hash = ?');
$stmt->execute([hash('sha256', $token)]);
json_response(['success' => true, 'message' => 'Signed out']);
