<?php
// GET /signup-pending-list.php
// Admin: list pending sign-up requests.

require __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$adminId = require_user_id();

$stmtRole = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
$stmtRole->execute([':id' => $adminId]);
$admin = $stmtRole->fetch();
if (!$admin || $admin['role'] !== 'admin') {
    json_response(['success' => false, 'message' => 'Admin access required'], 403);
}

$stmt = $pdo->query("
    SELECT s.id, s.request_code, s.full_name, s.username, s.email,
           s.requested_role, s.created_at,
           o.name AS office_name, o.code AS office_code
    FROM signup_requests s
    JOIN offices o ON o.id = s.office_id
    WHERE s.status = 'pending'
    ORDER BY s.created_at ASC
");
$rows = $stmt->fetchAll();

json_response([
    'success' => true,
    'pending' => array_map(function ($r) {
        return [
            'id'             => (int)$r['id'],
            'request_code'   => $r['request_code'],
            'full_name'      => $r['full_name'],
            'username'       => $r['username'],
            'email'          => $r['email'],
            'requested_role' => $r['requested_role'],
            'office_name'    => $r['office_name'],
            'office_code'    => $r['office_code'],
            'created_at'     => $r['created_at'],
        ];
    }, $rows),
]);
