<?php
/** Password-reset email channel health, included only by the disposable API harness.
 * Uses a local stand-in mail provider (HTTP 202, or 404 for addresses containing "reject").
 * No real token, recipient or network mail is involved.
 */
function smartflow_test_email_channel(PDO $pdo, array $tokens): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Email channel cases require the disposable harness database');
    }
    require_once __DIR__ . '/../backend/backend/api/mailtrap-api-config.php';

    // --- Settings summary: pure function over the private environment, never exposing secrets.
    $withEnv = static function (array $env, callable $run) {
        $saved = $_ENV;
        foreach (['MAILTRAP_API_TOKEN', 'MAILTRAP_API_URL', 'MAIL_FROM_ADDRESS'] as $key) unset($_ENV[$key]);
        $_ENV = array_merge($_ENV, $env);
        try { return $run(); } finally { $_ENV = $saved; }
    };
    $none = $withEnv([], fn() => smartflow_email_settings());
    check($none['mode'] === 'not_configured' && $none['configured'] === false && $none['ready_for_real_delivery'] === false
        && count($none['problems']) >= 1, 'without a token the channel reports not configured and not ready');
    $badSandbox = $withEnv(['MAILTRAP_API_TOKEN' => 'synthetic-secret-token', 'MAILTRAP_API_URL' => 'https://sandbox.api.mailtrap.io/api/send/'],
        fn() => smartflow_email_settings());
    check($badSandbox['mode'] === 'sandbox' && $badSandbox['ready_for_real_delivery'] === false
        && count(array_filter($badSandbox['problems'], fn($p) => str_contains($p, 'inbox number'))) === 1
        && count(array_filter($badSandbox['problems'], fn($p) => str_contains($p, 'never reach real recipients'))) === 1,
        'the sandbox address without an inbox number is reported with both causes (the live 404 and the test-inbox limit)');
    $goodSandbox = $withEnv(['MAILTRAP_API_TOKEN' => 'synthetic-secret-token', 'MAILTRAP_API_URL' => 'https://sandbox.api.mailtrap.io/api/send/12345'],
        fn() => smartflow_email_settings());
    check($goodSandbox['mode'] === 'sandbox' && $goodSandbox['ready_for_real_delivery'] === false
        && count(array_filter($goodSandbox['problems'], fn($p) => str_contains($p, 'inbox number'))) === 0,
        'a complete sandbox address is still never ready for real delivery');
    $live = $withEnv(['MAILTRAP_API_TOKEN' => 'synthetic-secret-token', 'MAIL_FROM_ADDRESS' => 'smartflow@verified.example'],
        fn() => smartflow_email_settings());
    check($live['mode'] === 'live' && $live['ready_for_real_delivery'] === true && $live['problems'] === []
        && $live['sender_domain'] === 'verified.example' && !array_key_exists('host', $live),
        'the live sending address with a valid sender is ready for real delivery, and no provider host is exposed');
    $badSender = $withEnv(['MAILTRAP_API_TOKEN' => 'synthetic-secret-token', 'MAIL_FROM_ADDRESS' => 'not-an-email'],
        fn() => smartflow_email_settings());
    check($badSender['ready_for_real_delivery'] === false && count($badSender['problems']) === 1,
        'an invalid sender address blocks real-delivery readiness');
    check(!str_contains(json_encode([$none, $badSandbox, $goodSandbox, $live, $badSender]), 'synthetic-secret-token'),
        'the settings summary never contains the sending token');

    // --- Fixture administrators with random ids so persisted rate-limit buckets never collide between runs.
    $insert = $pdo->prepare('INSERT INTO users (id, name, username, password_hash, office_id, role, email) VALUES (?,?,?,?,4,?,?)');
    $fixture = static function (string $label, string $role, ?string $email) use ($insert, $pdo): array {
        $id = random_int(300000, 900000);
        $username = 'mailtest_' . $label . '_' . bin2hex(random_bytes(3));
        $insert->execute([$id, 'Mail fixture ' . $label, $username, password_hash('test-password', PASSWORD_DEFAULT), $role, $email]);
        [$http, $login] = api('auth-login.php', null, ['username' => $username, 'password' => 'test-password']);
        check($http === 200 && isset($login['token']), "email fixture $label signs in");
        return [$id, $login['token'], $username];
    };
    [$okId, $okToken] = $fixture('ok', 'admin', 'ok-admin@synthetic.test');
    [, $rejectToken] = $fixture('reject', 'admin', 'reject-admin@synthetic.test');
    [, $noEmailToken] = $fixture('noemail', 'admin', null);

    // --- Endpoint authority and method guards.
    check(api('system-email-test.php', null, [])[0] === 401, 'the email test requires a signed-in session');
    foreach (['eng', 'head'] as $who) {
        check(api('system-email-test.php', $tokens[$who], [])[0] === 403, "$who cannot run the email test");
        check(api('system-status.php', $tokens[$who])[0] === 403, "$who cannot read the email status");
    }
    $get = curl_init($GLOBALS['base'] . '/system-email-test.php');
    curl_setopt_array($get, [CURLOPT_RETURNTRANSFER => true, CURLOPT_HTTPHEADER => ["Authorization: Bearer $okToken"]]);
    curl_exec($get);
    check(curl_getinfo($get, CURLINFO_HTTP_CODE) === 405, 'the email test only accepts POST');
    curl_close($get);
    [$http, $noEmail] = api('system-email-test.php', $noEmailToken, []);
    check($http === 400 && $noEmail['success'] === false && str_contains($noEmail['message'], 'no valid email address'),
        'an administrator without an email address gets a clear instruction and nothing is sent');

    // --- Provider accepted.
    [$http, $accepted] = api('system-email-test.php', $okToken, []);
    check($http === 200 && $accepted['success'] === true && $accepted['accepted'] === true && $accepted['http'] === 202
        && str_contains($accepted['message'], 'accepted a test message')
        && str_contains($accepted['message'], 'does not guarantee delivery'),
        'an accepted provider response is reported without claiming inbox delivery');
    check(preg_match('/^o\*+@synthetic\.test$/', $accepted['sent_to']) === 1,
        'the recipient is masked in the response');
    $accepted_json = json_encode($accepted);
    check(!str_contains($accepted_json, 'synthetic-mail-token-never-real') && !str_contains($accepted_json, '127.0.0.1')
        && !str_contains($accepted_json, 'ok-admin@synthetic.test') && !str_contains($accepted_json, 'sender@verified.example'),
        'the response exposes no token, provider address, full recipient or sender address');

    // --- Provider rejected (404), as happened on the live server.
    [$http, $rejected] = api('system-email-test.php', $rejectToken, []);
    check($http === 200 && $rejected['success'] === true && $rejected['accepted'] === false && $rejected['http'] === 404
        && str_contains($rejected['message'], 'HTTP 404') && str_contains($rejected['message'], 'address setting'),
        'a provider 404 is reported with a plain cause and the setting to check');

    // --- System status carries the last attempt and no secrets.
    [$http, $status] = api('system-status.php', $okToken);
    $email = $status['email'] ?? [];
    check($http === 200 && ($email['last_attempt']['accepted'] ?? null) === false && ($email['last_attempt']['http'] ?? null) === 404
        && ($email['last_attempt']['purpose'] ?? '') === 'test' && isset($email['mode'], $email['configured'], $email['problems']),
        'system status shows the most recent mail attempt and the channel summary');
    check(!str_contains(json_encode($status), 'synthetic-mail-token-never-real') && !str_contains(json_encode($status), '@synthetic.test'),
        'system status exposes no token or recipient address');

    // --- A real reset request records its attempt through the same channel; the public answer is unchanged.
    $userId = random_int(300000, 900000);
    $username = 'mailtest_reset_' . bin2hex(random_bytes(3));
    $insert->execute([$userId, 'Mail fixture reset', $username, password_hash('test-password', PASSWORD_DEFAULT), 'staff', 'ok-user@synthetic.test']);
    [$http, $forgot] = api('auth-forgot-password.php', null, ['username' => $username]);
    check($http === 200 && $forgot === ['success' => true,
        'message' => 'If an account exists with that username, a password reset code has been generated.'],
        'the public reset answer is unchanged when the mail channel is in use');
    [, $afterReset] = api('system-status.php', $okToken);
    check(($afterReset['email']['last_attempt']['purpose'] ?? '') === 'password_reset'
        && ($afterReset['email']['last_attempt']['accepted'] ?? null) === true,
        'a password-reset email updates the last-attempt record');

    // --- Rate limit and audit.
    [$h2] = api('system-email-test.php', $okToken, []);
    [$h3] = api('system-email-test.php', $okToken, []);
    [$h4, $limited] = api('system-email-test.php', $okToken, []);
    check($h2 === 200 && $h3 === 200 && $h4 === 429 && str_contains((string)($limited['message'] ?? ''), 'Too many requests'),
        'the email test is limited to three attempts per five minutes per administrator');
    $audit = $pdo->query("SELECT COUNT(*) AS c, SUM(meta_json LIKE '%@%') AS leaks FROM audit_logs WHERE event_type = 'user.email_test'")->fetch();
    check((int)$audit['c'] >= 4 && (int)$audit['leaks'] === 0,
        'each email test is audited without storing any email address');
}
