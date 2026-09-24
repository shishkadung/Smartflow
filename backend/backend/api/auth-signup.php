<?php
// POST /auth-signup.php
// Body: { full_name, username, email, password, office_id, requested_role }
// requested_role: staff | head | admin (maps from Employee / Head / Accountant|Admin UI)

require __DIR__ . '/config.php';

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

$stmtPending = $pdo->prepare("
    SELECT id, status FROM signup_requests WHERE username = :u LIMIT 1
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

$nextId = (int)$pdo->query('SELECT COALESCE(MAX(id), 0) + 1 AS n FROM signup_requests')->fetch()['n'];
$requestCode = 'REQ-' . str_pad((string)$nextId, 4, '0', STR_PAD_LEFT);

$stmt = $pdo->prepare('
    INSERT INTO signup_requests
        (request_code, full_name, username, email, password_hash, office_id, requested_role, status)
    VALUES
        (:code, :name, :username, :email, :hash, :office_id, :role, \'pending\')
');
$stmt->execute([
    ':code'      => $requestCode,
    ':name'      => $fullName,
    ':username'  => $username,
    ':email'     => $email,
    ':hash'      => $hash,
    ':office_id' => $officeId,
    ':role'      => $role,
]);

$id = (int)$pdo->lastInsertId();

json_response([
    'success' => true,
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
