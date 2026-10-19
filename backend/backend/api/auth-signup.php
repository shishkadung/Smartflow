<?php
// POST /auth-signup.php
// Body: { full_name, username, email, password, office_id, requested_role }
// requested_role: staff | head | admin (maps from Employee / Head / Accountant|Admin UI)

require __DIR__ . '/config.php';
require_once __DIR__ . '/signup-status-helper.php';
header('Cache-Control: no-store');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$body = get_json_body();
$fullName = trim((string)($body['full_name'] ?? ''));
$username = trim((string)($body['username'] ?? ''));
$email = trim((string)($body['email'] ?? ''));
$password = (string)($body['password'] ?? '');
$officeId = (int)($body['office_id'] ?? 0);
$role = trim((string)($body['requested_role'] ?? 'staff'));
smartflow_public_auth_limit('signup', 10);
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_response(['success' => false, 'message' => 'Enter a valid email address'], 400);
}

$allowedRoles = ['staff', 'head', 'admin'];
if (!in_array($role, $allowedRoles, true)) {
    json_response(['success' => false, 'message' => 'Invalid requested role'], 400);
}

if ($fullName === '' || $username === '' || $email === '' || $password === '') {
    json_response(['success' => false, 'message' => 'All account fields are required'], 400);
}

if ($officeId <= 0) {
    json_response(['success' => false, 'message' => 'office_id is required'], 400);
}
if (mb_strlen($fullName) > 100 || !preg_match('/^[a-zA-Z0-9._-]{3,50}$/', $username) || strlen($email) > 120) {
    json_response(['success' => false, 'message' => 'Name must be at most 100 characters. Username must use 3–50 letters, numbers, dots, underscores or hyphens. Email must be at most 120 characters.'], 400);
}

if (strlen($password) < 8) {
    json_response(['success' => false, 'message' => 'Password must be at least 8 characters'], 400);
}

$stmtOffice = $pdo->prepare('SELECT id, name, code FROM offices WHERE id = :id LIMIT 1');
$stmtOffice->execute([':id' => $officeId]);
$office = $stmtOffice->fetch();
if (!$office) {
    json_response(['success' => false, 'message' => 'Office not found'], 400);
}

$stmtUser = $pdo->prepare('SELECT id FROM users WHERE username = :u LIMIT 1');
$stmtUser->execute([':u' => $username]);
if ($stmtUser->fetch()) {
    json_response(['success' => false, 'message' => 'Username is already taken'], 409);
}
$stmtEmail = $pdo->prepare('SELECT id FROM users WHERE email = :email LIMIT 1');
$stmtEmail->execute([':email' => $email]);
if ($stmtEmail->fetch()) {
    json_response(['success' => false, 'message' => 'Email is already in use'], 409);
}

// Username match is case-insensitive under utf8mb4_unicode_ci.
$stmtPending = $pdo->prepare("
    SELECT id, status, request_code FROM signup_requests WHERE username = :u LIMIT 1
");
$stmtPending->execute([':u' => $username]);
$existing = $stmtPending->fetch();
if ($existing) {
    if ($existing['status'] === 'pending') {
        json_response(['success' => false, 'message' => 'A pending sign-up already exists for this username'], 409);
    }
    if ($existing['status'] === 'approved') {
        json_response(['success' => false, 'message' => 'This username already has an approved account. Sign in instead.'], 409);
    }
}

$hash = password_hash($password, PASSWORD_DEFAULT);
smartflow_ensure_signup_status_key($pdo);
$statusKey = bin2hex(random_bytes(32));
$statusKeyHash = hash('sha256', $statusKey);

// Rejected requests keep the username unique key — update in place so the user can re-apply.
if ($existing && $existing['status'] === 'rejected') {
    $id = (int)$existing['id'];
    $requestCode = (string)$existing['request_code'];
    $stmt = $pdo->prepare('
        UPDATE signup_requests
        SET full_name = :name,
            username = :username,
            email = :email,
            password_hash = :hash,
            status_key_hash = :status_key_hash,
            office_id = :office_id,
            requested_role = :role,
            status = \'pending\',
            approved_by = NULL,
            approved_at = NULL,
            approved_user_id = NULL
        WHERE id = :id AND status = \'rejected\'
    ');
    $stmt->execute([
        ':name'      => $fullName,
        ':username'  => $username,
        ':email'     => $email,
        ':hash'      => $hash,
        ':status_key_hash' => $statusKeyHash,
        ':office_id' => $officeId,
        ':role'      => $role,
        ':id'        => $id,
    ]);
    if ($stmt->rowCount() !== 1) {
        json_response(['success' => false, 'message' => 'This request changed. Check its status before submitting again.'], 409);
    }
} else {
    $nextId = (int)$pdo->query('SELECT COALESCE(MAX(id), 0) + 1 AS n FROM signup_requests')->fetch()['n'];
    $requestCode = 'REQ-' . str_pad((string)$nextId, 4, '0', STR_PAD_LEFT);

    try {
        $stmt = $pdo->prepare('
            INSERT INTO signup_requests
                (request_code, full_name, username, email, password_hash, status_key_hash, office_id, requested_role, status)
            VALUES
                (:code, :name, :username, :email, :hash, :status_key_hash, :office_id, :role, \'pending\')
        ');
        $stmt->execute([
            ':code'      => $requestCode,
            ':name'      => $fullName,
            ':username'  => $username,
            ':email'     => $email,
            ':hash'      => $hash,
            ':status_key_hash' => $statusKeyHash,
            ':office_id' => $officeId,
            ':role'      => $role,
        ]);
    } catch (PDOException $e) {
        if ((int)($e->errorInfo[1] ?? 0) === 1062) {
            json_response([
                'success' => false,
                'message' => 'Username is already used by a pending or approved sign-up request',
            ], 409);
        }
        throw $e;
    }

    $id = (int)$pdo->lastInsertId();
}

json_response([
    'success' => true,
    'status_key' => $statusKey,
    'message' => 'Sign-up request submitted. Await admin approval.',
    'request' => [
        'id'             => $id,
        'request_code'   => $requestCode,
        'full_name'      => $fullName,
        'username'       => $username,
        'email'          => $email,
        'office_id'      => $officeId,
        'office_name'    => $office['name'],
        'office_code'    => $office['code'],
        'requested_role' => $role,
        'status'         => 'pending',
    ],
], 201);
