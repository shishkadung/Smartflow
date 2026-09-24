<?php
// POST /auth-login.php
// Body: { "username": "...", "password": "..." }
// Returns a Bearer token compatible with config.php (base64 of "<user_id>|<random>").

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';

smartflow_ensure_users_active_column($pdo);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

$body = get_json_body();
$username = trim((string)($body['username'] ?? ''));
$password = (string)($body['password'] ?? '');

if ($username === '' || $password === '') {
    json_response([
        'success' => false,
        'message' => 'Username and password are required',
    ], 400);
}

$stmtPending = $pdo->prepare("
    SELECT status FROM signup_requests WHERE username = :username ORDER BY id DESC LIMIT 1
");
$stmtPending->execute([':username' => $username]);
$pending = $stmtPending->fetch();
if ($pending && $pending['status'] === 'pending') {
    json_response([
        'success' => false,
        'message' => 'Account pending admin approval. Check your sign-up status or contact LGU IT.',
    ], 403);
}

$stmt = $pdo->prepare('
    SELECT u.id, u.name, u.username, u.password_hash, u.role, u.is_active,
           o.id AS office_id, o.name AS office_name, o.code AS office_code
    FROM users u
    JOIN offices o ON o.id = u.office_id
    WHERE u.username = :username
    LIMIT 1
');
$stmt->execute([':username' => $username]);
$user = $stmt->fetch();

if (!$user || !password_verify($password, $user['password_hash'])) {
    // Use a generic message to avoid revealing which field is wrong.
    json_response([
        'success' => false,
        'message' => 'Invalid username or password',
    ], 401);
}

if (!(int)($user['is_active'] ?? 1)) {
    json_response([
        'success' => false,
        'message' => 'This account has been deactivated. Contact your municipal administrator.',
    ], 403);
}

// Generate secure token (stored in database if table exists)
$token = generate_auth_token((int)$user['id'], 86400); // 24 hour TTL

$full = smartflow_fetch_user_by_id($pdo, (int)$user['id']);

json_response([
    'success' => true,
    'token' => $token,
    'user' => smartflow_user_payload($full ?: [
        'id' => (int)$user['id'],
        'name' => $user['name'],
        'username' => $user['username'],
        'role' => $user['role'],
        'office_id' => (int)$user['office_id'],
        'office_name' => $user['office_name'],
        'office_code' => $user['office_code'],
        'is_active' => 1,
        'avatar_path' => null,
    ]),
]);
