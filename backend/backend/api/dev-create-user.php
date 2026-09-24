<?php
// DEV ONLY: Create a user with hashed password.
// POST body JSON:
// { "name": "...", "username": "...", "password": "...", "office_code": "ENG", "role": "staff" }
//
// IMPORTANT: Delete/disable this file before deploying.

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';

smartflow_dev_localhost_or_admin($pdo);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

$body = get_json_body();
$name = trim((string)($body['name'] ?? ''));
$username = trim((string)($body['username'] ?? ''));
$password = (string)($body['password'] ?? '');
$officeCode = strtoupper(trim((string)($body['office_code'] ?? '')));
$role = trim((string)($body['role'] ?? 'staff'));

if ($name === '' || $username === '' || $password === '' || $officeCode === '') {
    json_response([
        'success' => false,
        'message' => 'name, username, password, and office_code are required',
    ], 400);
}

// Validate role
$allowedRoles = ['admin', 'staff', 'head', 'auditor'];
if (!in_array($role, $allowedRoles, true)) {
    json_response([
        'success' => false,
        'message' => 'Invalid role. Allowed: admin, staff, auditor',
    ], 400);
}

// Find office by code
$stmtOffice = $pdo->prepare('SELECT id, name, code FROM offices WHERE code = :code LIMIT 1');
$stmtOffice->execute([':code' => $officeCode]);
$office = $stmtOffice->fetch();

if (!$office) {
    json_response([
        'success' => false,
        'message' => 'Office not found for office_code',
    ], 404);
}

// Create user
$passwordHash = password_hash($password, PASSWORD_DEFAULT);

try {
    $stmt = $pdo->prepare('
        INSERT INTO users (name, username, password_hash, office_id, role)
        VALUES (:name, :username, :password_hash, :office_id, :role)
    ');
    $stmt->execute([
        ':name' => $name,
        ':username' => $username,
        ':password_hash' => $passwordHash,
        ':office_id' => (int)$office['id'],
        ':role' => $role,
    ]);
} catch (PDOException $e) {
    // Likely duplicate username
    json_response([
        'success' => false,
        'message' => 'Could not create user (maybe username already exists)',
    ], 409);
}

json_response([
    'success' => true,
    'user' => [
        'id' => (int)$pdo->lastInsertId(),
        'name' => $name,
        'username' => $username,
        'office_id' => (int)$office['id'],
        'office_name' => $office['name'],
        'office_code' => $office['code'],
        'role' => $role,
    ],
]);

