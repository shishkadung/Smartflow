<?php
// GET /dev-test-email.php
// Test email sending and show detailed errors

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';
require_once __DIR__ . '/mailtrap-api-config.php';

$testEmail = 'smartflow2k26@gmail.com';
$results = [];

// Test 1: Check if API config is loaded
$results['config_loaded'] = [
    'api_token' => substr(MAILTRAP_API_TOKEN, 0, 10) . '...',
    'inbox_id' => MAILTRAP_INBOX_ID,
    'configured' => MAILTRAP_API_TOKEN !== 'YOUR_API_TOKEN_HERE'
];

// Test 2: Try to send test email via API
$testBody = "Test email from SmartFlow\nTime: " . date('Y-m-d H:i:s');
$emailResult = send_email_mailtrap_api($testEmail, 'SmartFlow Test Email', $testBody);

$results['email_test'] = $emailResult;

// Test 3: Check if user has email
$stmt = $pdo->prepare('SELECT username, email FROM users WHERE username = :username');
$stmt->execute([':username' => 'engineering.staff']);
$user = $stmt->fetch();

$results['user_check'] = [
    'found' => $user !== false,
    'username' => $user['username'] ?? null,
    'email' => $user['email'] ?? null,
    'has_email' => !empty($user['email'])
];

json_response([
    'success' => true,
    'test_results' => $results,
    'diagnosis' => $emailResult['success'] 
        ? 'Email sending works! Check your inbox.' 
        : 'Email sending failed: ' . $emailResult['message']
]);
