<?php
// POST /system-email-test.php
// Administrator-only check of the password-reset mail channel. The message always goes to the
// signed-in administrator's own address on file, never to a caller-supplied recipient.
// Response never contains the sending token, the provider URL or the provider's reply body.

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/audit-helper.php';
require_once __DIR__ . '/mailtrap-api-config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$adminId = require_user_id();
smartflow_require_admin($pdo, $adminId);
smartflow_rate_limit('email-test:admin:' . $adminId, 3, 300);

$stmt = $pdo->prepare('SELECT name, email FROM users WHERE id = :id AND is_active = 1 LIMIT 1');
$stmt->execute([':id' => $adminId]);
$admin = $stmt->fetch();
$email = trim((string)($admin['email'] ?? ''));
if (!$admin || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_response([
        'success' => false,
        'message' => 'Your administrator account has no valid email address. Add one under Profile, then try again.',
    ], 400);
}

$masked = static function (string $address): string {
    [$local, $domain] = explode('@', $address, 2);
    return substr($local, 0, 1) . str_repeat('*', max(2, strlen($local) - 1)) . '@' . $domain;
};

$settings = smartflow_email_settings();
$body = "Hello {$admin['name']},\n\n" .
    "This is a test message from SmartFlow, sent at " . date('Y-m-d H:i:s') . " (server time).\n" .
    "It confirms that the password-reset email channel works. No action is needed.\n\n" .
    "SmartFlow LGU System";
$result = smartflow_send_email($email, 'SmartFlow test email', $body, 'test');

$http = (int)($result['http'] ?? 0);
$code = (int)($result['code'] ?? 0);
$accepted = !empty($result['success']);
if ($accepted) {
    $message = 'The mail provider accepted a test message for ' . $masked($email) . '. Check that inbox and its spam folder; acceptance does not guarantee delivery.';
    if ($settings['mode'] === 'sandbox') {
        $message .= ' Sandbox mode sends to a test inbox, so it will not reach a real mailbox.';
    }
} else {
    $message = smartflow_email_explain($result, $settings);
}

smartflow_audit_action($pdo, 'user.email_test', $adminId, 'Sent a password-reset email channel test', [
    'accepted' => $accepted,
    'http' => $http,
    'code' => $code,
    'mode' => $settings['mode'],
]);

json_response([
    'success' => true,
    'accepted' => $accepted,
    'http' => $http,
    'code' => $code,
    'message' => $message,
    'sent_to' => $masked($email),
    'email' => $settings + ['last_attempt' => smartflow_email_last_result()],
]);
