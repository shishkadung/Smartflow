<?php
// GET /users-list.php
// List users for Municipal Accountant / System Administrator.
// Auth: Bearer token required (admin only).

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';
require_once __DIR__ . '/thresholds-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$adminId = require_user_id();
smartflow_require_admin($pdo, $adminId);
smartflow_ensure_users_active_column($pdo);

$stmt = $pdo->query('
    SELECT u.id, u.name, u.username, u.role, u.is_active,
           o.name AS office_name, o.code AS office_code
    FROM users u
    JOIN offices o ON o.id = u.office_id
    ORDER BY u.is_active DESC, u.role ASC, u.username ASC
');
$rows = $stmt->fetchAll();

json_response([
    'success' => true,
    'users'   => array_map(function ($r) {
        return [
            'id'          => (int)$r['id'],
            'name'        => $r['name'],
            'username'    => $r['username'],
            'role'        => $r['role'],
            'office_name' => $r['office_name'],
            'office_code' => $r['office_code'],
            'is_active'   => (bool)(int)$r['is_active'],
        ];
    }, $rows),
]);
