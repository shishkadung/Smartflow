<?php
/** Stand-in SMTP server for the disposable API harness only. Listens on loopback, no TLS, no relaying.
 * Usage: php smtp-stub.php <port> <logfile> <expected-user> <expected-password>
 * It accepts AUTH LOGIN for the expected credentials (anything else gets 535), refuses recipients that
 * contain "reject" (550), and appends one JSON line per accepted message to the log file.
 */
if (PHP_SAPI !== 'cli' || $argc < 5) exit(2);
[, $port, $logFile, $expectedUser, $expectedPass] = $argv;
$server = stream_socket_server("tcp://127.0.0.1:$port", $errno, $errstr);
if (!$server) { fwrite(STDERR, "listen failed: $errstr\n"); exit(1); }

$reply = static function ($client, string $text): void { fwrite($client, $text . "\r\n"); };
while (true) {
    $client = @stream_socket_accept($server, 3600);
    if (!$client) continue;
    stream_set_timeout($client, 10);
    $reply($client, '220 smtp-stub ready');
    $state = ['user' => null, 'authed' => false, 'from' => null, 'to' => null, 'stage' => 'cmd'];
    while (($line = fgets($client, 8192)) !== false) {
        $line = rtrim($line, "\r\n");
        if ($state['stage'] === 'user') {
            $state['user'] = base64_decode($line); $state['stage'] = 'pass'; $reply($client, '334 UGFzc3dvcmQ6'); continue;
        }
        if ($state['stage'] === 'pass') {
            $state['stage'] = 'cmd';
            if ($state['user'] === $expectedUser && base64_decode($line) === $expectedPass) { $state['authed'] = true; $reply($client, '235 2.7.0 Accepted'); }
            else $reply($client, '535 5.7.8 Username and Password not accepted');
            continue;
        }
        if ($state['stage'] === 'data') {
            $data = $line . "\r\n";
            while (($more = fgets($client, 8192)) !== false) {
                if (rtrim($more, "\r\n") === '.') break;
                $data .= $more;
            }
            file_put_contents($logFile, json_encode(['from' => $state['from'], 'to' => $state['to'], 'authed' => $state['authed'], 'data' => $data]) . "\n", FILE_APPEND | LOCK_EX);
            $state['stage'] = 'cmd';
            $reply($client, '250 2.0.0 OK queued');
            continue;
        }
        $verb = strtoupper(strtok($line, ' '));
        switch ($verb) {
            case 'EHLO': case 'HELO': fwrite($client, "250-smtp-stub\r\n250 AUTH LOGIN\r\n"); break;
            case 'AUTH': $state['stage'] = 'user'; $reply($client, '334 VXNlcm5hbWU6'); break;
            case 'MAIL':
                if (!$state['authed']) { $reply($client, '530 5.7.0 Authentication required'); break; }
                preg_match('/<([^>]*)>/', $line, $m); $state['from'] = $m[1] ?? ''; $reply($client, '250 2.1.0 OK'); break;
            case 'RCPT':
                preg_match('/<([^>]*)>/', $line, $m); $to = $m[1] ?? '';
                if (str_contains($to, 'reject')) { $reply($client, '550 5.1.1 No such user'); break; }
                $state['to'] = $to; $reply($client, '250 2.1.5 OK'); break;
            case 'DATA': $state['stage'] = 'data'; $reply($client, '354 End data with <CR><LF>.<CR><LF>'); break;
            case 'QUIT': $reply($client, '221 2.0.0 Bye'); break 2;
            default: $reply($client, '502 5.5.1 Command not implemented');
        }
    }
    fclose($client);
}
