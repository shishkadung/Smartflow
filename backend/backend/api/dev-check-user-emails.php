<?php
// GET /dev-check-user-emails.php
// Check if users have email addresses

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';

$stmt = $pdo->query('SELECT username, email FROM users ORDER BY id');
$users = $stmt->fetchAll(PDO::FETCH_ASSOC);

json_response([
    'success' => true,
    'users' => $users,
    'email_column_exists' => true,
]);
