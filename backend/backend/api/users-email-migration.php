<?php
// GET /users-email-migration.php
// Adds email column to users table if not exists

require __DIR__ . '/config.php';

smartflow_dev_localhost_or_admin($pdo);

// Check if email column exists
$stmt = $pdo->query("
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'email'
");

$hasColumn = (int)$stmt->fetchColumn() > 0;

if ($hasColumn) {
    json_response([
        'success' => true,
        'message' => 'Email column already exists in users table'
    ]);
}

// Add email column
$pdo->exec("
    ALTER TABLE users
    ADD COLUMN email VARCHAR(120) NULL AFTER username,
    ADD UNIQUE KEY idx_email (email)
");

json_response([
    'success' => true,
    'message' => 'Email column added to users table'
]);
