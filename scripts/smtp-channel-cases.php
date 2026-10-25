<?php
/** Gmail/SMTP mail channel, included only by the disposable API harness.
 * Real Gmail is never contacted: a loopback stand-in SMTP server (scripts/smtp-stub.php) receives the mail.
 * It also proves the whole recovery path: the code that is emailed really resets the password once.
 */
function smartflow_test_smtp_channel(PDO $pdo, array $tokens): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('SMTP channel cases require the disposable harness database');
    }
    require_once __DIR__ . '/../backend/backend/api/mailtrap-api-config.php';
    $smtpPort = $GLOBALS['smtpPort']; $smtpLog = $GLOBALS['smtpLog'];
    $secret = 'synthetic-app-password'; $smtpUser = 'smtp-user@synthetic.test';

    // --- Settings summary and explanations (pure functions over the private environment).
    $withEnv = static function (array $env, callable $run) {
        $saved = $_ENV;
        foreach (['SMTP_HOST', 'SMTP_PORT', 'SMTP_SECURE', 'SMTP_USERNAME', 'SMTP_PASSWORD', 'MAIL_FROM_ADDRESS', 'MAILTRAP_API_TOKEN', 'MAILTRAP_API_URL'] as $key) unset($_ENV[$key]);
        $_ENV = array_merge($_ENV, $env);
        try { return $run(); } finally { $_ENV = $saved; }
    };
    $gmail = ['SMTP_HOST' => 'smtp.gmail.com', 'SMTP_PORT' => '587', 'SMTP_SECURE' => 'tls', 'SMTP_USERNAME' => 'owner@gmail.com', 'SMTP_PASSWORD' => 'synthetic-secret-app-password'];
    $ready = $withEnv($gmail, fn() => smartflow_email_settings());
    check($ready['mode'] === 'gmail' && $ready['provider'] === 'Gmail' && $ready['configured'] && $ready['ready_for_real_delivery']
        && $ready['problems'] === [] && $ready['sender_domain'] === 'gmail.com',
        'a Gmail account with an App Password over TLS is reported ready for real delivery');
    $noPassword = $withEnv(array_diff_key($gmail, ['SMTP_PASSWORD' => 1]), fn() => smartflow_email_settings());
    check($noPassword['configured'] === false && $noPassword['ready_for_real_delivery'] === false
        && count(array_filter($noPassword['problems'], fn($p) => str_contains($p, 'App Password'))) === 1,
        'a Gmail setup without its App Password says exactly what is missing');
    $otherSender = $withEnv($gmail + ['MAIL_FROM_ADDRESS' => 'someone.else@gmail.com'], fn() => smartflow_email_settings());
    check(count(array_filter($otherSender['problems'], fn($p) => str_contains($p, 'replaces the sender'))) === 1,
        'a different sender address on Gmail is flagged because Gmail replaces it');
    $plainGmail = $withEnv(array_merge($gmail, ['SMTP_SECURE' => 'none']), fn() => smartflow_email_settings());
    check($plainGmail['ready_for_real_delivery'] === false && count(array_filter($plainGmail['problems'], fn($p) => str_contains($p, 'Encryption'))) === 1,
        'unencrypted SMTP to a real host is never ready');
    $loopback = $withEnv(array_merge($gmail, ['SMTP_HOST' => '127.0.0.1', 'SMTP_SECURE' => 'none']), fn() => smartflow_email_settings());
    check($loopback['mode'] === 'smtp' && $loopback['ready_for_real_delivery'] === false,
        'a loopback test server is never reported as real delivery');
    check(!str_contains(json_encode([$ready, $noPassword, $otherSender, $plainGmail, $loopback]), 'synthetic-secret-app-password')
        && !str_contains(json_encode($ready), 'smtp.gmail.com') && !str_contains(json_encode($ready), 'owner@'),
        'the settings summary exposes no password, host or account address');
    $auth = ['success' => false, 'driver' => 'smtp', 'code' => 535, 'stage' => 'auth', 'transport_error' => 0];
    check(str_contains(smartflow_email_explain($auth, $ready), 'Google App Password')
        && str_contains(smartflow_email_explain($auth, $loopback), 'username or password')
        && str_contains(smartflow_email_explain(['driver' => 'smtp', 'stage' => 'connect', 'transport_error' => 111], $ready), 'could not connect securely')
        && str_contains(smartflow_email_explain(['driver' => 'smtp', 'stage' => 'recipient', 'code' => 550], $ready), 'recipient address'),
        'failures are explained in plain words, naming the App Password for a Gmail sign-in refusal');

    // --- The client itself refuses unsafe use before any connection is made.
    $cfg = ['host' => 'smtp.example.test', 'port' => 25, 'secure' => 'none', 'username' => 'u', 'password' => 'p', 'from' => 'a@example.test', 'from_name' => 'X'];
    $unsafe = smartflow_smtp_send($cfg, 'b@example.test', 'S', 'B');
    check($unsafe['success'] === false && $unsafe['stage'] === 'config', 'plain SMTP to a non-loopback host is refused without connecting');
    $badTo = smartflow_smtp_send(array_merge($cfg, ['secure' => 'tls']), "victim@example.test\r\nBcc: other@example.test", 'S', 'B');
    check($badTo['success'] === false && $badTo['stage'] === 'config', 'a recipient containing header-injection characters is refused');

    // --- Extra API servers wired to the stand-in SMTP server (same disposable database and sessions).
    $servers = [];
    $start = static function (array $env) use (&$servers): string {
        $socket = stream_socket_server('tcp://127.0.0.1:0', $errno, $errstr);
        if (!$socket) throw new RuntimeException($errstr);
        $address = stream_socket_get_name($socket, false);
        fclose($socket);
        $proc = proc_open([PHP_BINARY, '-d', 'variables_order=EGPCS', '-S', $address, '-t', dirname(__DIR__)],
            [0 => ['pipe', 'r'], 1 => ['file', $GLOBALS['serverLog'], 'a'], 2 => ['file', $GLOBALS['serverLog'], 'a']], $pipes, dirname(__DIR__),
            array_merge($GLOBALS['environment'], $env));
        if (!is_resource($proc)) throw new RuntimeException('SMTP test API server could not start');
        fclose($pipes[0]);
        $servers[] = $proc;
        for ($i = 0; $i < 40; $i++) {
            $probe = @fsockopen('127.0.0.1', (int)substr($address, strrpos($address, ':') + 1), $e, $m, 0.1);
            if ($probe) { fclose($probe); break; }
            usleep(50000);
        }
        return "http://$address/backend/backend/api";
    };
    // MAIL_FROM_ADDRESS is cleared so the sender defaults to the SMTP account, as it does for Gmail.
    $smtpEnv = ['SMTP_HOST' => '127.0.0.1', 'SMTP_PORT' => (string)$smtpPort, 'SMTP_SECURE' => 'none', 'SMTP_USERNAME' => $smtpUser, 'SMTP_PASSWORD' => $secret, 'MAIL_FROM_ADDRESS' => ''];
    try {
        $good = $start($smtpEnv);
        $badAuth = $start(array_merge($smtpEnv, ['SMTP_PASSWORD' => 'wrong-synthetic-password']));
        $down = $start(array_merge($smtpEnv, ['SMTP_PORT' => '1']));
        $on = static function (string $base, callable $run) {
            $old = $GLOBALS['base']; $GLOBALS['base'] = $base;
            try { return $run(); } finally { $GLOBALS['base'] = $old; }
        };
        $insert = $pdo->prepare('INSERT INTO users (id, name, username, password_hash, office_id, role, email) VALUES (?,?,?,?,4,?,?)');
        $fixture = static function (string $label, string $role, string $email, string $password = 'test-password') use ($insert): array {
            $id = random_int(300000, 900000);
            $username = 'smtptest_' . $label . '_' . bin2hex(random_bytes(3));
            $insert->execute([$id, 'SMTP fixture ' . $label, $username, password_hash($password, PASSWORD_DEFAULT), $role, $email]);
            return [$id, $username];
        };
        $signIn = static function (string $username, string $password = 'test-password'): string {
            [$http, $login] = api('auth-login.php', null, ['username' => $username, 'password' => $password]);
            check($http === 200 && isset($login['token']), "SMTP fixture $username signs in");
            return $login['token'];
        };
        $logged = static function () use ($smtpLog): array {
            $lines = is_file($smtpLog) ? array_filter(explode("\n", (string)file_get_contents($smtpLog))) : [];
            return array_map(fn($line) => json_decode($line, true), array_values($lines));
        };
        $decodeBody = static function (string $data): string {
            [, $body] = explode("\r\n\r\n", $data, 2);
            return (string)base64_decode(str_replace(["\r", "\n"], '', $body));
        };

        // Accepted by the SMTP server.
        [, $okName] = $fixture('ok', 'admin', 'smtp-admin@synthetic.test');
        $okToken = $signIn($okName);
        $before = count($logged());
        [$http, $sent] = $on($good, fn() => api('system-email-test.php', $okToken, []));
        $messages = $logged();
        check($http === 200 && $sent['accepted'] === true && $sent['code'] === 250 && count($messages) === $before + 1,
            'the test email is accepted by the SMTP server and delivered to it');
        $message = end($messages);
        check($message['from'] === $smtpUser && $message['to'] === 'smtp-admin@synthetic.test' && $message['authed'] === true
            && str_contains($message['data'], 'Subject: SmartFlow test email') && str_contains($message['data'], 'Content-Transfer-Encoding: base64')
            && str_contains($decodeBody($message['data']), 'This is a test message from SmartFlow'),
            'the message is authenticated, addressed to the administrator only and readable');
        $json = json_encode($sent);
        check(!str_contains($json, $secret) && !str_contains($json, $smtpUser) && !str_contains($json, '127.0.0.1') && !str_contains($json, 'smtp-admin@synthetic.test'),
            'the SMTP test response exposes no password, account address, server address or full recipient');
        [, $status] = $on($good, fn() => api('system-status.php', $okToken));
        check(($status['email']['mode'] ?? '') === 'smtp' && ($status['email']['last_attempt']['accepted'] ?? null) === true
            && ($status['email']['last_attempt']['code'] ?? null) === 250 && !str_contains(json_encode($status), $secret),
            'system status reports the SMTP channel and its accepted attempt without secrets');

        // Wrong password, unreachable server, refused recipient.
        [, $badName] = $fixture('badauth', 'admin', 'smtp-admin2@synthetic.test');
        $badToken = $signIn($badName);
        $before = count($logged());
        [$http, $refused] = $on($badAuth, fn() => api('system-email-test.php', $badToken, []));
        check($http === 200 && $refused['accepted'] === false && $refused['code'] === 535 && str_contains($refused['message'], 'username or password')
            && count($logged()) === $before && !str_contains(json_encode($refused), 'wrong-synthetic-password'),
            'a refused sign-in is reported as such, sends nothing and does not echo the password');
        [, $downName] = $fixture('down', 'admin', 'smtp-admin3@synthetic.test');
        $downToken = $signIn($downName);
        [$http, $unreachable] = $on($down, fn() => api('system-email-test.php', $downToken, []));
        check($http === 200 && $unreachable['accepted'] === false && str_contains($unreachable['message'], 'could not connect securely'),
            'an unreachable mail server is reported as a connection problem');
        [, $rejName] = $fixture('rejected', 'admin', 'reject-smtp@synthetic.test');
        $rejToken = $signIn($rejName);
        [$http, $noRecipient] = $on($good, fn() => api('system-email-test.php', $rejToken, []));
        check($http === 200 && $noRecipient['accepted'] === false && $noRecipient['code'] === 550 && str_contains($noRecipient['message'], 'recipient address'),
            'a refused recipient is reported with its own plain explanation');

        // End to end: the emailed code really resets the password, exactly once.
        [, $resetName] = $fixture('reset', 'staff', 'smtp-user2@synthetic.test', 'old-synthetic-password-1');
        $before = count($logged());
        [$http, $forgot] = $on($good, fn() => api('auth-forgot-password.php', null, ['username' => $resetName]));
        $messages = $logged();
        check($http === 200 && $forgot === ['success' => true, 'message' => 'If an account exists with that username, a password reset code has been generated.']
            && count($messages) === $before + 1, 'a reset request sends one email and keeps the public answer unchanged');
        $body = $decodeBody(end($messages)['data']);
        check(end($messages)['to'] === 'smtp-user2@synthetic.test' && preg_match('/reset code is: (\d{6})/', $body, $m) === 1 && !str_contains($body, $secret),
            'the emailed message carries a six-digit code and no secret');
        $code = $m[1];
        [$http] = api('auth-reset-password.php', null, ['username' => $resetName, 'code' => $code, 'new_password' => 'new-synthetic-password-2']);
        check($http === 200, 'the emailed code resets the password');
        check(api('auth-login.php', null, ['username' => $resetName, 'password' => 'old-synthetic-password-1'])[0] === 401
            && api('auth-login.php', null, ['username' => $resetName, 'password' => 'new-synthetic-password-2'])[0] === 200,
            'after the reset only the new password signs in');
        check(api('auth-reset-password.php', null, ['username' => $resetName, 'code' => $code, 'new_password' => 'another-synthetic-password-3'])[0] >= 400,
            'the emailed code cannot be used a second time');
        $mail = (string)file_get_contents($smtpLog);
        check(!str_contains($mail, 'wrong-synthetic-password'), 'no failed-login password reached the mail server');
    } finally {
        foreach ($servers as $proc) { if (is_resource($proc)) { proc_terminate($proc); proc_close($proc); } }
    }
}
