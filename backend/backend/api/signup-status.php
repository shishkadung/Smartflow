<?php
// POST: an applicant's status key proves ownership. Legacy requests use their password.
require __DIR__ . '/config.php';
require_once __DIR__ . '/signup-status-helper.php';

header('Cache-Control: no-store');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}
$body = get_json_body();
$username = is_string($body['username'] ?? null) ? trim($body['username']) : '';
$requestCode = is_string($body['request_code'] ?? null) ? trim($body['request_code']) : '';
$statusKey = is_string($body['status_key'] ?? null) ? $body['status_key'] : '';
$password = is_string($body['password'] ?? null) ? $body['password'] : '';
smartflow_public_auth_limit('signup-status', 30, $username !== '' ? $username : $requestCode, 10);
smartflow_ensure_signup_status_key($pdo);

$stmt = $pdo->prepare('SELECT s.*, o.name AS office_name, o.code AS office_code
    FROM signup_requests s JOIN offices o ON o.id = s.office_id
    WHERE ' . ($requestCode !== '' ? 's.request_code = ?' : 's.username = ?') . ' LIMIT 1');
$stmt->execute([$requestCode !== '' ? $requestCode : $username]);
$row = $stmt->fetch();
$owned = $row && preg_match('/^[a-f0-9]{64}$/D', $statusKey)
    && is_string($row['status_key_hash'])
    && hash_equals($row['status_key_hash'], hash('sha256', $statusKey));
// Existing requests predate ownership keys. Verify credentials supplied afresh;
// never exchange a public request code for a secret or reveal whether it exists.
if (!$owned && $row && $row['status_key_hash'] === null && $username !== '' && $password !== '') {
    if ($row['status'] === 'approved') {
        $user = $pdo->prepare('SELECT username, password_hash FROM users WHERE id = ? AND is_active = 1 LIMIT 1');
        $user->execute([(int)($row['approved_user_id'] ?? 0)]);
        $account = $user->fetch();
        $owned = $account && strcasecmp($username, $account['username']) === 0
            && password_verify($password, $account['password_hash']);
        if ($owned) $row['username'] = $account['username'];
    } else {
        $owned = strcasecmp($username, $row['username']) === 0
            && password_verify($password, $row['password_hash']);
    }
}
if (!$owned) {
    json_response(['success' => false, 'message' => 'Unable to verify this sign-up request. Use your original status key or contact the municipal administrator.'], 404);
}
json_response(['success' => true, 'request' => [
    'request_code' => $row['request_code'],
    'username' => $row['username'],
    'office_name' => $row['office_name'],
    'office_code' => $row['office_code'],
    'requested_role' => $row['requested_role'],
    'status' => $row['status'],
    'approved_at' => $row['approved_at'],
]]);
