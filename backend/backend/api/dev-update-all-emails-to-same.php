<?php
// GET /dev-update-all-emails-to-same.php
// Update ALL users to use smartflow2k26@gmail.com for testing

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';

$testEmail = 'smartflow2k26@gmail.com';

// Update all users to the same test email
$stmt = $pdo->prepare('UPDATE users SET email = :email');
$stmt->execute([':email' => $testEmail]);

$countStmt = $pdo->prepare('SELECT COUNT(*) FROM users WHERE email = :email');
$countStmt->execute([':email' => $testEmail]);
$updatedCount = $countStmt->fetchColumn();

json_response([
    'success' => true,
    'message' => 'All users updated to use ' . $testEmail,
    'users_with_test_email' => (int)$updatedCount,
    'note' => 'All password reset codes will be sent to smartflow2k26@gmail.com'
]);
