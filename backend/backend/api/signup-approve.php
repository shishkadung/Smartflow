<?php
// POST /signup-approve.php
// Body: { "request_id": 1, "action": "approve" | "reject" }
// Admin approves or rejects a pending sign-up.

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$adminId = require_user_id();

$stmtRole = $pdo->prepare('SELECT role, username FROM users WHERE id = :id LIMIT 1');
$stmtRole->execute([':id' => $adminId]);
$admin = $stmtRole->fetch();
if (!$admin || $admin['role'] !== 'admin') {
    json_response(['success' => false, 'message' => 'Admin access required'], 403);
}

$body = get_json_body();
$requestId = (int)($body['request_id'] ?? 0);
$action = trim((string)($body['action'] ?? ''));

if ($requestId <= 0 || !in_array($action, ['approve', 'reject'], true)) {
    json_response(['success' => false, 'message' => 'request_id and action (approve|reject) are required'], 400);
}

$stmt = $pdo->prepare('
    SELECT * FROM signup_requests WHERE id = :id LIMIT 1
');
$stmt->execute([':id' => $requestId]);
$req = $stmt->fetch();

if (!$req || $req['status'] !== 'pending') {
    json_response(['success' => false, 'message' => 'Pending request not found'], 404);
}

if ($action === 'reject') {
    $pdo->prepare("
        UPDATE signup_requests
        SET status = 'rejected', approved_by = :admin, approved_at = NOW()
        WHERE id = :id
    ")->execute([':admin' => $adminId, ':id' => $requestId]);

    json_response(['success' => true, 'message' => 'Sign-up request rejected']);
}

$stmtUser = $pdo->prepare('SELECT id FROM users WHERE username = :u LIMIT 1');
$stmtUser->execute([':u' => $req['username']]);
if ($stmtUser->fetch()) {
    json_response(['success' => false, 'message' => 'Username already exists in users table'], 409);
}

$pdo->beginTransaction();
try {
    smartflow_ensure_users_email_column($pdo);
    $insert = $pdo->prepare('
        INSERT INTO users (name, username, email, password_hash, office_id, role)
        VALUES (:name, :username, :email, :hash, :office_id, :role)
    ');
    $insert->execute([
        ':name'      => $req['full_name'],
        ':username'  => $req['username'],
        ':email'     => $req['email'] !== null && $req['email'] !== '' ? $req['email'] : null,
        ':hash'      => $req['password_hash'],
        ':office_id' => (int)$req['office_id'],
        ':role'      => $req['requested_role'],
    ]);

    $pdo->prepare("
        UPDATE signup_requests
        SET status = 'approved', approved_by = :admin, approved_at = NOW()
        WHERE id = :id
    ")->execute([':admin' => $adminId, ':id' => $requestId]);

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'Could not approve request'], 500);
}

json_response([
    'success' => true,
    'message' => 'Account approved. User can sign in now.',
    'request' => [
        'request_code'   => $req['request_code'],
        'username'       => $req['username'],
        'requested_role' => $req['requested_role'],
        'approved_by'    => $admin['username'],
        'approved_at'    => date('Y-m-d H:i:s'),
    ],
]);
