<?php
// Minimal SMTP client for transactional mail (password-reset codes, administrator test messages).
// Used for Gmail (smtp.gmail.com with an App Password) or any other SMTP server.
//
// Safety rules:
//  - Real servers always use TLS with certificate verification (STARTTLS on 587 or implicit TLS on 465).
//  - "none" (plain) is accepted only for a loopback host, which the isolated tests use.
//  - The password is only ever sent inside AUTH; it is never logged, returned or stored.

function smartflow_smtp_is_loopback(string $host): bool {
    return in_array(strtolower($host), ['127.0.0.1', 'localhost', '::1'], true);
}

/**
 * @param array{host:string,port:int,secure:string,username:string,password:string,from:string,from_name:string,cafile?:string} $cfg
 * @return array{success:bool,driver:string,code:int,stage:string,transport_error:int}
 */
function smartflow_smtp_send(array $cfg, string $to, string $subject, string $body): array {
    $fail = static fn(string $stage, int $code = 0, int $transport = 0): array =>
        ['success' => false, 'driver' => 'smtp', 'code' => $code, 'stage' => $stage, 'transport_error' => $transport];
    $clean = static fn(string $value): string => trim(preg_replace('/[\r\n]+/', ' ', $value));

    $secure = strtolower($cfg['secure']);
    if (!in_array($secure, ['tls', 'ssl', 'none'], true)) return $fail('config');
    if ($secure === 'none' && !smartflow_smtp_is_loopback($cfg['host'])) return $fail('config');
    if (!filter_var($to, FILTER_VALIDATE_EMAIL) || !filter_var($cfg['from'], FILTER_VALIDATE_EMAIL)) return $fail('config');

    $context = stream_context_create(['ssl' => array_filter([
        'verify_peer' => true,
        'verify_peer_name' => true,
        'peer_name' => $cfg['host'],
        'cafile' => ($cfg['cafile'] ?? '') !== '' ? $cfg['cafile'] : null,
        'SNI_enabled' => true,
    ], static fn($value) => $value !== null)]);
    $scheme = $secure === 'ssl' ? 'ssl' : 'tcp';
    $errno = 0; $errstr = '';
    $fp = @stream_socket_client("$scheme://{$cfg['host']}:{$cfg['port']}", $errno, $errstr, 15, STREAM_CLIENT_CONNECT, $context);
    if (!$fp) return $fail('connect', 0, $errno ?: 1);
    stream_set_timeout($fp, 20);

    $read = static function ($fp): array {
        $code = 0; $text = '';
        while (($line = fgets($fp, 1024)) !== false) {
            $text .= $line;
            $code = (int)substr($line, 0, 3);
            if (strlen($line) < 4 || $line[3] !== '-') break;
        }
        return [$code, $text];
    };
    $send = static function ($fp, string $line) use ($read): array {
        fwrite($fp, $line . "\r\n");
        return $read($fp);
    };
    $quit = static function ($fp): void { @fwrite($fp, "QUIT\r\n"); @fclose($fp); };

    try {
        [$code] = $read($fp);
        if ($code !== 220) { $quit($fp); return $fail('greeting', $code); }
        [$code] = $send($fp, 'EHLO smartflow.local');
        if ($code !== 250) { $quit($fp); return $fail('ehlo', $code); }
        if ($secure === 'tls') {
            [$code] = $send($fp, 'STARTTLS');
            if ($code !== 220) { $quit($fp); return $fail('tls', $code); }
            if (!@stream_socket_enable_crypto($fp, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) { @fclose($fp); return $fail('tls', 0, 2); }
            [$code] = $send($fp, 'EHLO smartflow.local');
            if ($code !== 250) { $quit($fp); return $fail('ehlo', $code); }
        }
        if ($cfg['username'] !== '') {
            [$code] = $send($fp, 'AUTH LOGIN');
            if ($code !== 334) { $quit($fp); return $fail('auth', $code); }
            [$code] = $send($fp, base64_encode($cfg['username']));
            if ($code !== 334) { $quit($fp); return $fail('auth', $code); }
            [$code] = $send($fp, base64_encode($cfg['password']));
            if ($code !== 235) { $quit($fp); return $fail('auth', $code); }
        }
        [$code] = $send($fp, 'MAIL FROM:<' . $cfg['from'] . '>');
        if ($code !== 250) { $quit($fp); return $fail('sender', $code); }
        [$code] = $send($fp, 'RCPT TO:<' . $to . '>');
        if ($code !== 250 && $code !== 251) { $quit($fp); return $fail('recipient', $code); }
        [$code] = $send($fp, 'DATA');
        if ($code !== 354) { $quit($fp); return $fail('data', $code); }

        $encodedSubject = preg_match('/[^\x20-\x7E]/', $subject) ? '=?UTF-8?B?' . base64_encode($subject) . '?=' : $clean($subject);
        $fromName = $clean($cfg['from_name']);
        $headers = [
            'From: ' . ($fromName !== '' ? '"' . addcslashes($fromName, '"\\') . '" ' : '') . '<' . $cfg['from'] . '>',
            'To: <' . $to . '>',
            'Subject: ' . $encodedSubject,
            'Date: ' . gmdate('D, d M Y H:i:s') . ' +0000',
            'Message-ID: <' . bin2hex(random_bytes(12)) . '@smartflow.local>',
            'MIME-Version: 1.0',
            'Content-Type: text/plain; charset=UTF-8',
            'Content-Transfer-Encoding: base64',
        ];
        // Base64 keeps the body free of lone dots and over-long lines, so no dot-stuffing is needed.
        $message = implode("\r\n", $headers) . "\r\n\r\n" . chunk_split(base64_encode($body), 76, "\r\n") . ".";
        [$code] = $send($fp, $message);
        if ($code !== 250) { $quit($fp); return $fail('data', $code); }
        $quit($fp);
        return ['success' => true, 'driver' => 'smtp', 'code' => $code, 'stage' => 'sent', 'transport_error' => 0];
    } catch (Throwable $e) {
        @fclose($fp);
        return $fail('io', 0, 3);
    }
}
