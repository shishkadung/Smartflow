<?php
// POST /auth-forgot-password.php
// Body: { "username": "..." }
// Generates a password reset token and emails it (falls back to showing code for dev)

require __DIR__ . '/config.php';
require_once __DIR__ . '/mailtrap-api-config.php'; // Using Mailtrap API instead of SMTP

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$body = get_json_body();
$username = trim((string)($body['username'] ?? ''));

if ($username === '') {
    json_response(['success' => false, 'message' => 'Username is required'], 400);
}

// Find user by username (including email if available)
$stmt = $pdo->prepare('
    SELECT id, username, name, email, is_active
    FROM users
    WHERE username = :username
    LIMIT 1
');
$stmt->execute([':username' => $username]);
$user = $stmt->fetch();

// Always return generic success message to prevent username enumeration
if (!$user || !(int)($user['is_active'] ?? 1)) {
    json_response([
        'success' => true,
        'message' => 'If an account exists with that username, a password reset code has been generated.',
    ]);
}

$userId = (int)$user['id'];

// Generate a 6-digit numeric code for easy mobile entry
$resetCode = str_pad((string)random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
$tokenHash = password_hash($resetCode, PASSWORD_DEFAULT);

// Invalidate any existing unused tokens for this user
$pdo->prepare('
    UPDATE password_resets
    SET used_at = NOW()
    WHERE user_id = :user_id AND used_at IS NULL
')->execute([':user_id' => $userId]);

// Use MySQL NOW() so expires_at matches NOW() checks in auth-reset-password.php
// (PHP date() can use a different timezone than MySQL on XAMPP)
$pdo->prepare('
    INSERT INTO password_resets (user_id, token_hash, expires_at)
    VALUES (:user_id, :token_hash, DATE_ADD(NOW(), INTERVAL 1 HOUR))
')->execute([
    ':user_id' => $userId,
    ':token_hash' => $tokenHash,
]);

$expiresAt = (string)$pdo->query('SELECT expires_at FROM password_resets WHERE id = ' . (int)$pdo->lastInsertId())->fetchColumn();

$userEmail = $user['email'] ?? null;
$emailSent = false;

// Try to send email via Mailtrap API if user has email
if (!empty($userEmail)) {
    $emailBody = "Hello {$user['name']},\n\n" .
        "Your SmartFlow password reset code is: $resetCode\n\n" .
        "This code expires at $expiresAt (1 hour from now).\n\n" .
        "If you did not request this reset, please ignore this email.\n\n" .
        "SmartFlow LGU System";
    
    $emailResult = send_email_mailtrap_api($userEmail, 'SmartFlow Password Reset Code', $emailBody);
    $emailSent = $emailResult['success'];
}

$response = [
    'success' => true,
    'message' => 'If an account exists with that username, a password reset code has been generated.',
    'expires_at' => $expiresAt,
];

// Always include reset code for demo purposes (in production, remove this line)
$response['dev_reset_code'] = $resetCode;
$response['email_sent'] = $emailSent; // true = sent via email, false = show code only

json_response($response);
