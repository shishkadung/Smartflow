<?php
// POST /signup-approve.php
// Body: { "request_id": 1, "action": "approve" | "reject" }
// Admin approves or rejects a pending sign-up.

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';
require_once __DIR__ . '/audit-helper.php';
require_once __DIR__ . '/signup-status-helper.php';

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

// Runtime DDL must finish before the approval/user creation transaction.
smartflow_ensure_signup_status_key($pdo);
smartflow_ensure_users_email_column($pdo);
$pdo->beginTransaction();
try {
$stmt = $pdo->prepare('
    SELECT * FROM signup_requests WHERE id = :id LIMIT 1 FOR UPDATE
');
$stmt->execute([':id' => $requestId]);
$req = $stmt->fetch();
$admin = smartflow_require_locked_admin($pdo, $adminId);
} catch (PDOException $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    $conflict = in_array((int)($e->errorInfo[1] ?? 0), [1205, 1213], true);
    json_response(['success' => false, 'message' => $conflict
        ? 'Account or request changed while waiting. Refresh and review it again.'
        : 'Could not review request'], $conflict ? 409 : 500);
}

if (!$req || $req['status'] !== 'pending') {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'Pending request not found'], 404);
}

if ($action === 'reject') {
    $pdo->prepare("
        UPDATE signup_requests
        SET status = 'rejected', approved_by = :admin, approved_at = NOW(), approved_user_id = NULL
        WHERE id = :id
    ")->execute([':admin' => $adminId, ':id' => $requestId]);
    $pdo->commit();

    smartflow_audit_action($pdo, 'signup.reject', $adminId, 'Rejected sign-up for ' . $req['username'], [
        'request_code'   => $req['request_code'],
        'username'       => $req['username'],
        'office_id'      => (int)$req['office_id'],
        'requested_role' => $req['requested_role'],
    ]);

    json_response(['success' => true, 'message' => 'Sign-up request rejected']);
}

$stmtUser = $pdo->prepare('SELECT id FROM users WHERE username = :u LIMIT 1');
$stmtUser->execute([':u' => $req['username']]);
if ($stmtUser->fetch()) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'Username already exists in users table'], 409);
}

try {
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
    $approvedUserId = (int)$pdo->lastInsertId();

    $pdo->prepare("
        UPDATE signup_requests
        SET status = 'approved', approved_by = :admin, approved_at = NOW(), approved_user_id = :user_id
        WHERE id = :id
    ")->execute([':admin' => $adminId, ':id' => $requestId, ':user_id' => $approvedUserId]);

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    if ($e instanceof PDOException && (int)($e->errorInfo[1] ?? 0) === 1062) {
        json_response(['success' => false, 'message' => 'Username or email already belongs to an account. Ask the applicant to use different account details.'], 409);
    }
    json_response(['success' => false, 'message' => 'Could not approve request'], 500);
}

smartflow_audit_action($pdo, 'signup.approve', $adminId, 'Approved sign-up for ' . $req['username'] . ' (' . $req['requested_role'] . ')', [
    'request_code'   => $req['request_code'],
    'username'       => $req['username'],
    'office_id'      => (int)$req['office_id'],
    'requested_role' => $req['requested_role'],
]);

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
