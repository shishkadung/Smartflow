<?php
// GET /dev-update-emails-plus.php
// Update all users to use Gmail plus addressing (all go to same inbox)
// Example: smartflow2k26+username@gmail.com

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';

// Get all users
$stmt = $pdo->query('SELECT id, username FROM users ORDER BY id');
$users = $stmt->fetchAll(PDO::FETCH_ASSOC);

$baseEmail = 'smartflow2k26';
$updated = [];
$errors = [];

foreach ($users as $user) {
    // Create plus address: smartflow2k26+engineering.staff@gmail.com
    $plusEmail = $baseEmail . '+' . $user['username'] . '@gmail.com';
    
    try {
        $update = $pdo->prepare('UPDATE users SET email = :email WHERE id = :id');
        $update->execute([
            ':email' => $plusEmail,
            ':id' => $user['id']
        ]);
        $updated[] = $user['username'] . ' → ' . $plusEmail;
    } catch (PDOException $e) {
        $errors[] = $user['username'] . ': ' . $e->getMessage();
    }
}

json_response([
    'success' => true,
    'message' => 'All users updated with Gmail plus addressing',
    'updated' => $updated,
    'errors' => $errors,
    'note' => 'All emails will be sent to smartflow2k26@gmail.com (Gmail ignores the +part)'
]);
