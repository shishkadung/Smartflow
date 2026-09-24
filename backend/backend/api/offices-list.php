<?php
// GET /offices

require __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

$stmt = $pdo->query('SELECT id, name, code FROM offices ORDER BY name ASC');
$offices = $stmt->fetchAll();

json_response([
    'success' => true,
    'offices' => array_map(function ($o) {
        return [
            'id' => (int)$o['id'],
            'name' => $o['name'],
            'code' => $o['code'],
        ];
    }, $offices),
]);

