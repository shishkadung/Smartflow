<?php
// Mail channel for password-reset codes and administrator test messages.
// Loaded after config.php has read the server's private environment.
//
// Driver choice: SMTP (for example Gmail with an App Password) when SMTP_HOST is set, otherwise the
// Mailtrap HTTP API. Private settings (never returned by any endpoint):
//   SMTP_HOST, SMTP_PORT (default 587), SMTP_SECURE (tls | ssl | none; none only for loopback),
//   SMTP_USERNAME, SMTP_PASSWORD, MAIL_FROM_ADDRESS (defaults to SMTP_USERNAME), MAIL_FROM_NAME,
//   MAILTRAP_API_TOKEN, MAILTRAP_API_URL, MAIL_CA_BUNDLE.

require_once __DIR__ . '/smtp-mailer.php';

function smartflow_smtp_config(): ?array {
    $host = trim((string)($_ENV['SMTP_HOST'] ?? ''));
    if ($host === '') return null;
    $username = trim((string)($_ENV['SMTP_USERNAME'] ?? ''));
    $secure = strtolower(trim((string)($_ENV['SMTP_SECURE'] ?? 'tls')));
    $port = (int)($_ENV['SMTP_PORT'] ?? ($secure === 'ssl' ? 465 : 587));
    return [
        'host' => $host,
        'port' => $port > 0 && $port < 65536 ? $port : 587,
        'secure' => $secure,
        'username' => $username,
        'password' => (string)($_ENV['SMTP_PASSWORD'] ?? ''),
        'from' => trim((string)($_ENV['MAIL_FROM_ADDRESS'] ?? '')) ?: $username,
        'from_name' => trim((string)($_ENV['MAIL_FROM_NAME'] ?? 'SmartFlow')),
        'cafile' => trim((string)($_ENV['MAIL_CA_BUNDLE'] ?? '')),
    ];
}

function smartflow_smtp_is_gmail(string $host): bool {
    return in_array(strtolower($host), ['smtp.gmail.com', 'smtp.googlemail.com'], true);
}

/**
 * Safe, secret-free description of the mail channel for the administrator's System page.
 * Never returns passwords, tokens, hosts, ports or the full provider URL.
 */
function smartflow_email_settings(): array {
    $smtp = smartflow_smtp_config();
    if ($smtp !== null) {
        $gmail = smartflow_smtp_is_gmail($smtp['host']);
        $validFrom = filter_var($smtp['from'], FILTER_VALIDATE_EMAIL) !== false;
        $secureOk = in_array($smtp['secure'], ['tls', 'ssl'], true) || ($smtp['secure'] === 'none' && smartflow_smtp_is_loopback($smtp['host']));
        $configured = $smtp['username'] !== '' && $smtp['password'] !== '';
        $problems = [];
        if ($smtp['username'] === '') $problems[] = 'No SMTP username is configured.';
        if ($smtp['password'] === '') $problems[] = $gmail
            ? 'No Gmail App Password is configured. Gmail needs an App Password (2-Step Verification must be on), not the normal Gmail password.'
            : 'No SMTP password is configured.';
        if (!$secureOk) $problems[] = 'Encryption is not enabled. Real mail servers require TLS (port 587) or SSL (port 465).';
        if (!$validFrom) $problems[] = 'The sender address is not a valid email address.';
        if ($gmail && $validFrom && $smtp['username'] !== '' && strcasecmp($smtp['from'], $smtp['username']) !== 0) {
            $problems[] = 'Gmail replaces the sender with the signed-in Gmail account, so use the same address for both.';
        }
        return [
            'provider' => $gmail ? 'Gmail' : 'SMTP server',
            'mode' => $gmail ? 'gmail' : 'smtp',
            'configured' => $configured,
            'sender_domain' => $validFrom ? strtolower(substr(strrchr($smtp['from'], '@'), 1)) : null,
            'ready_for_real_delivery' => $configured && $secureOk && $validFrom && !smartflow_smtp_is_loopback($smtp['host']),
            'problems' => $problems,
        ];
    }

    $token = trim((string)($_ENV['MAILTRAP_API_TOKEN'] ?? ''));
    $url = trim((string)($_ENV['MAILTRAP_API_URL'] ?? 'https://send.api.mailtrap.io/api/send'));
    $sender = trim((string)($_ENV['MAIL_FROM_ADDRESS'] ?? 'smartflow@urbiztondo.gov.ph'));
    $parts = parse_url($url) ?: [];
    $host = strtolower((string)($parts['host'] ?? ''));
    $path = (string)($parts['path'] ?? '');
    $sandbox = str_contains($host, 'sandbox');
    // A sandbox endpoint is /api/send/{inbox id}; without the id the provider answers 404.
    $incomplete = $sandbox && !preg_match('#/api/send/\d+/?$#', $path);
    $mode = $token === '' ? 'not_configured' : ($sandbox ? 'sandbox' : ($host === 'send.api.mailtrap.io' ? 'live' : 'custom'));
    $problems = [];
    if ($token === '') $problems[] = 'No sending token is configured, so no email can be sent.';
    if ($sandbox) $problems[] = 'Sandbox mode captures messages in a test inbox; they never reach real recipients.';
    if ($incomplete) $problems[] = 'The sandbox address has no inbox number, so the provider rejects every request (HTTP 404).';
    if (!filter_var($sender, FILTER_VALIDATE_EMAIL)) $problems[] = 'The sender address is not a valid email address.';
    return [
        'provider' => 'Mailtrap',
        'mode' => $mode,
        'configured' => $token !== '',
        'sender_domain' => str_contains($sender, '@') ? strtolower(substr(strrchr($sender, '@'), 1)) : null,
        'ready_for_real_delivery' => $mode === 'live' && filter_var($sender, FILTER_VALIDATE_EMAIL) !== false,
        'problems' => $problems,
    ];
}

function smartflow_email_status_file(): string {
    $dir = __DIR__ . '/cache';
    if (!is_dir($dir)) @mkdir($dir, 0700, true);
    return $dir . '/email-status.json';
}

/** Remember only whether the provider accepted the last attempt; never the recipient, subject or body. */
function smartflow_email_record_result(array $result, string $purpose): void {
    $record = [
        'at' => date('Y-m-d H:i:s'),
        'purpose' => $purpose,
        'accepted' => !empty($result['success']),
        'http' => isset($result['http']) ? (int)$result['http'] : null,
        'code' => isset($result['code']) ? (int)$result['code'] : null,
        'stage' => isset($result['stage']) ? (string)$result['stage'] : null,
        'not_configured' => ($result['error'] ?? '') === 'Email service is not configured',
    ];
    @file_put_contents(smartflow_email_status_file(), json_encode($record), LOCK_EX);
}

function smartflow_email_last_result(): ?array {
    $file = smartflow_email_status_file();
    if (!is_file($file)) return null;
    $data = json_decode((string)@file_get_contents($file), true);
    return is_array($data) && isset($data['at']) ? $data : null;
}

/** Plain-language cause of a failed attempt for the administrator; never includes provider replies or secrets. */
function smartflow_email_explain(array $result, array $settings): string {
    if (!$settings['configured']) {
        return $settings['mode'] === 'gmail' || $settings['mode'] === 'smtp'
            ? 'The mail account is not fully configured on the server (username or App Password missing).'
            : 'No sending token is configured on the server. Ask whoever manages the server settings to add one.';
    }
    $driver = (string)($result['driver'] ?? ($settings['mode'] === 'gmail' || $settings['mode'] === 'smtp' ? 'smtp' : 'mailtrap'));
    if ($driver === 'smtp') {
        $code = (int)($result['code'] ?? 0);
        $stage = (string)($result['stage'] ?? '');
        $gmail = $settings['mode'] === 'gmail';
        if ($stage === 'config') return 'The mail settings on the server are not valid (encryption or address). Check the private mail configuration.';
        if (in_array($stage, ['connect', 'tls', 'greeting', 'io'], true) || !empty($result['transport_error'])) {
            return 'The server could not connect securely to the mail server (network, firewall or certificate problem).';
        }
        if ($stage === 'auth') {
            return $gmail
                ? "Gmail refused the sign-in (code $code). Use a Google App Password for this account (2-Step Verification must be on), not the normal Gmail password."
                : "The mail server refused the username or password (code $code).";
        }
        if ($stage === 'recipient') return "The mail server refused the recipient address (code $code). The address may not exist.";
        if (in_array($code, [421, 450, 451, 452], true)) return "The mail server is busy or limiting sending (code $code). Try again later.";
        return "The mail server did not accept the message (code $code).";
    }
    $http = (int)($result['http'] ?? 0);
    if (!empty($result['transport_error']) || $http === 0) return 'The server could not reach the mail provider (network or certificate problem).';
    if ($http === 401 || $http === 403) return "The mail provider refused the credentials (HTTP $http). The sending token is wrong or expired.";
    if ($http === 404) return 'The mail provider could not find the address it was given (HTTP 404). Check the mail provider address setting.';
    if ($http === 400 || $http === 422) return "The mail provider rejected the message (HTTP $http). The sender address is probably not verified for this account.";
    return "The mail provider did not accept the message (HTTP $http).";
}

/** Single entry point used by password recovery and the administrator test. Records only the outcome. */
function smartflow_send_email(string $to, string $subject, string $body, string $purpose = 'password_reset'): array {
    $smtp = smartflow_smtp_config();
    if ($smtp === null) return send_email_mailtrap_api($to, $subject, $body, $purpose);
    if ($smtp['username'] === '' || $smtp['password'] === '') {
        $result = ['success' => false, 'driver' => 'smtp', 'error' => 'Email service is not configured', 'stage' => 'config'];
    } else {
        $result = smartflow_smtp_send($smtp, $to, $subject, $body);
        if (empty($result['success']) && function_exists('smartflow_log')) {
            smartflow_log('warning', 'Mail server did not accept the message', ['stage' => $result['stage'] ?? '', 'code' => $result['code'] ?? 0, 'transport_error' => $result['transport_error'] ?? 0]);
        }
    }
    smartflow_email_record_result($result, $purpose);
    return $result;
}

function send_email_mailtrap_api(string $to, string $subject, string $body, string $purpose = 'password_reset'): array {
    $token = trim((string)($_ENV['MAILTRAP_API_TOKEN'] ?? ''));
    $url = trim((string)($_ENV['MAILTRAP_API_URL'] ?? 'https://send.api.mailtrap.io/api/send'));
    $sender = trim((string)($_ENV['MAIL_FROM_ADDRESS'] ?? 'smartflow@urbiztondo.gov.ph'));
    if ($token === '') {
        $result = ['success' => false, 'driver' => 'mailtrap', 'error' => 'Email service is not configured'];
        smartflow_email_record_result($result, $purpose);
        return $result;
    }
    $data = ['to' => [['email' => $to]], 'from' => ['email' => $sender, 'name' => 'SmartFlow'], 'subject' => $subject, 'text' => $body];
    $ch = curl_init($url);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($data), CURLOPT_TIMEOUT => 20,
        CURLOPT_SSL_VERIFYPEER => true, CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $token, 'Content-Type: application/json']]);
    $caBundle = trim((string)($_ENV['MAIL_CA_BUNDLE'] ?? ''));
    if ($caBundle !== '') curl_setopt($ch, CURLOPT_CAINFO, $caBundle);
    $response = curl_exec($ch);
    $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_errno($ch);
    curl_close($ch);
    $accepted = $httpCode >= 200 && $httpCode < 300;
    if (!$accepted && function_exists('smartflow_log')) smartflow_log('warning', 'Recovery email provider did not accept the request', ['http' => $httpCode, 'transport_error' => $curlError]);
    // Provider acceptance does not establish delivery to the recipient's inbox.
    $result = ['success' => $accepted, 'driver' => 'mailtrap', 'http' => $httpCode, 'transport_error' => $curlError];
    smartflow_email_record_result($result, $purpose);
    return $result;
}
