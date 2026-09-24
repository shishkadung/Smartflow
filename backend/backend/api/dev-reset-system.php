<?php
// GET /dev-reset-system.php
// WARNING: Resets system to fresh state - deletes all documents, movements, and non-seed users

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';

// Only allow on localhost/XAMPP
if (!in_array($_SERVER['REMOTE_ADDR'] ?? '', ['127.0.0.1', '::1', 'localhost']) && 
    !str_contains($_SERVER['HTTP_HOST'] ?? '', 'localhost')) {
    json_response(['success' => false, 'message' => 'Only allowed on localhost'], 403);
}

$deleted = [];

// IMPORTANT: Delete child tables FIRST (foreign key constraints)

// 1. Disable foreign key checks temporarily
$pdo->exec('SET FOREIGN_KEY_CHECKS = 0');

// 2. Delete all movements (child of documents)
$pdo->exec('DELETE FROM movements');
$deleted['movements'] = $pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn();

// 3. Delete all documents
$pdo->exec('DELETE FROM documents');
$deleted['documents'] = $pdo->query('SELECT COUNT(*) FROM documents')->fetchColumn();

// 3. Delete all qr_tokens
$pdo->exec('DELETE FROM qr_tokens');
$deleted['qr_tokens'] = $pdo->query('SELECT COUNT(*) FROM qr_tokens')->fetchColumn();

// 4. Delete all audit_logs
$pdo->exec('DELETE FROM audit_logs');
$deleted['audit_logs'] = $pdo->query('SELECT COUNT(*) FROM audit_logs')->fetchColumn();

// 5. Delete all password_resets
$pdo->exec('DELETE FROM password_resets');
$deleted['password_resets'] = $pdo->query('SELECT COUNT(*) FROM password_resets')->fetchColumn();

// 6. Delete all signup_requests
$pdo->exec('DELETE FROM signup_requests');
$deleted['signup_requests'] = $pdo->query('SELECT COUNT(*) FROM signup_requests')->fetchColumn();

// 7. Delete all auth_tokens (force logout all users)
$pdo->exec('DELETE FROM auth_tokens');
$deleted['auth_tokens'] = $pdo->query('SELECT COUNT(*) FROM auth_tokens')->fetchColumn();

// 8. Delete all document_requests
$pdo->exec('DELETE FROM document_requests');
$deleted['document_requests'] = $pdo->query('SELECT COUNT(*) FROM document_requests')->fetchColumn();

// 9. Reset AUTO_INCREMENT counters (optional)
$tables = ['documents', 'movements', 'qr_tokens', 'audit_logs', 'password_resets', 'signup_requests', 'auth_tokens', 'document_requests'];
foreach ($tables as $table) {
    try {
        $pdo->exec("ALTER TABLE $table AUTO_INCREMENT = 1");
    } catch (PDOException $e) {
        // Ignore errors for tables without auto_increment
    }
}

// Re-enable foreign key checks
$pdo->exec('SET FOREIGN_KEY_CHECKS = 1');

json_response([
    'success' => true,
    'message' => 'System reset to fresh state!',
    'deleted_counts' => $deleted,
    'note' => 'All documents, movements, and transactions deleted. Demo users kept. All users logged out.'
]);
