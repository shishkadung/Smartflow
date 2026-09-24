<?php
// GET /signup-status.php?username=... OR ?request_code=REQ-0001
// Public — check pending / approved / rejected sign-up.

require __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$username = trim((string)($_GET['username'] ?? ''));
$requestCode = trim((string)($_GET['request_code'] ?? ''));

if ($username === '' && $requestCode === '') {
    json_response(['success' => false, 'message' => 'username or request_code is required'], 400);
}

if ($requestCode !== '') {
    $stmt = $pdo->prepare('
        SELECT s.*, o.name AS office_name, o.code AS office_code,
               u.name AS approved_by_name
        FROM signup_requests s
        JOIN offices o ON o.id = s.office_id
        LEFT JOIN users u ON u.id = s.approved_by
        WHERE s.request_code = :code
        LIMIT 1
    ');
    $stmt->execute([':code' => $requestCode]);
} else {
    $stmt = $pdo->prepare('
        SELECT s.*, o.name AS office_name, o.code AS office_code,
               u.name AS approved_by_name
        FROM signup_requests s
        JOIN offices o ON o.id = s.office_id
        LEFT JOIN users u ON u.id = s.approved_by
        WHERE s.username = :username
        ORDER BY s.id DESC
        LIMIT 1
    ');
    $stmt->execute([':username' => $username]);
}

$row = $stmt->fetch();
if (!$row) {
    json_response(['success' => false, 'message' => 'Sign-up request not found'], 404);
}

json_response([
    'success' => true,
    'request' => [
        'id'               => (int)$row['id'],
        'request_code'     => $row['request_code'],
        'full_name'        => $row['full_name'],
        'username'         => $row['username'],
        'email'            => $row['email'],
        'office_id'        => (int)$row['office_id'],
        'office_name'      => $row['office_name'],
        'office_code'      => $row['office_code'],
        'requested_role'   => $row['requested_role'],
        'status'           => $row['status'],
        'approved_by_name' => $row['approved_by_name'],
        'approved_at'      => $row['approved_at'],
        'created_at'       => $row['created_at'],
    ],
]);
