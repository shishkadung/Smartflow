<?php
declare(strict_types=1);

// Synthetic files only: no application config, signing material, accounts or database.
$root = sys_get_temp_dir() . '/smartflow-router-test-' . bin2hex(random_bytes(8));
$server = null;
$checks = 0;
try {
    mkdir($root . '/scripts', 0700, true);
    mkdir($root . '/backend/backend/api/logs', 0700, true);
    mkdir($root . '/backend/backend/api/cache', 0700, true);
    mkdir($root . '/.runtime', 0700, true);
    copy(__DIR__ . '/dev-router.php', $root . '/scripts/dev-router.php');
    foreach (['.qr-secret', '.env', 'schema.sql', 'backup.log', 'auth-session.php.bak', 'logs/test.log', 'cache/test.json'] as $name) {
        file_put_contents($root . '/backend/backend/api/' . $name, 'SYNTHETIC_PRIVATE_MARKER');
    }
    file_put_contents($root . '/.runtime/test.log', 'SYNTHETIC_PRIVATE_MARKER');
    file_put_contents($root . '/backend/backend/api/auth-session.php', '<?php http_response_code(401); header("Content-Type: application/json"); echo json_encode(["success"=>false,"message"=>"Synthetic authentication required"]);');
    file_put_contents($root . '/backend/backend/api/method.php', '<?php header("Content-Type: application/json"); echo json_encode(["method"=>$_SERVER["REQUEST_METHOD"],"query"=>$_GET["q"]??null]);');
    $maintenance = array_map('basename', glob(__DIR__ . '/../backend/backend/api/dev-*.php'));
    $maintenance[] = 'users-email-migration.php';
    foreach ($maintenance as $name) {
        file_put_contents($root . '/backend/backend/api/' . $name,
            '<?php file_put_contents(__DIR__ . "/executed-maintenance", "UNEXPECTED"); echo "UNEXPECTED";');
    }
    foreach (['qr-generator.js', 'qr-label-renderer.js'] as $asset) file_put_contents($root . '/backend/backend/api/' . $asset, '// synthetic public label asset');
    $socket = stream_socket_server('tcp://127.0.0.1:0', $errno, $error);
    if (!$socket) throw new RuntimeException('Could not reserve a test port');
    $address = stream_socket_get_name($socket, false);
    fclose($socket);
    $log = $root . '/server.log';
    $server = proc_open([PHP_BINARY, '-S', $address, '-t', $root, $root . '/scripts/dev-router.php'],
        [0 => ['pipe', 'r'], 1 => ['file', $log, 'a'], 2 => ['file', $log, 'a']], $pipes, $root);
    if (!is_resource($server)) throw new RuntimeException('Could not start the isolated router server');
    fclose($pipes[0]);
    for ($attempt = 0; $attempt < 40; $attempt++) {
        $probe = @fsockopen('127.0.0.1', (int)substr($address, strrpos($address, ':') + 1), $errno, $error, .1);
        if ($probe) { fclose($probe); break; }
        usleep(50000);
    }
    $request = static function (string $path, string $method = 'GET') use ($address): array {
        $curl = curl_init('http://' . $address . $path);
        curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 5, CURLOPT_PATH_AS_IS => true,
            CURLOPT_CUSTOMREQUEST => $method, CURLOPT_NOBODY => $method === 'HEAD']);
        $body = curl_exec($curl);
        if ($body === false) throw new RuntimeException('Synthetic HTTP check failed');
        $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
        return [$status, $body];
    };
    $check = static function (bool $pass, string $message) use (&$checks): void {
        if (!$pass) throw new RuntimeException($message);
        $checks++;
        echo "PASS $message\n";
    };
    foreach (['.qr-secret', '%2eqr-secret', '%252eqr-secret', '.env', '%2eenv', 'schema.sql', 'backup.log',
        'auth-session.php.bak', 'logs/test.log', 'cache/test.json', '../api/.qr-secret', '..%2fapi%2f.qr-secret',
        '..%5capi%5c.qr-secret', 'auth-session.php/.env', 'auth-session.php%00', 'missing.php'] as $path) {
        foreach (['GET', 'HEAD'] as $method) {
            [$status, $body] = $request('/backend/backend/api/' . $path, $method);
            $check($status === 404 && !str_contains($body, 'SYNTHETIC_PRIVATE_MARKER'), "$method blocks synthetic private/invalid path $path");
        }
    }
    foreach (['/.runtime/test.log', '/scripts/dev-router.php', '/backend/backend/api/', '/backend/backend/api'] as $path) {
        $check($request($path)[0] === 404, 'repository files and directory requests are not served');
    }
    [$status, $body] = $request('/backend/backend/api/auth-session.php');
    $check($status === 401 && json_decode($body, true)['success'] === false, 'a real API script executes and retains its authentication response');
    foreach (['GET', 'POST', 'OPTIONS'] as $method) {
        [$status, $body] = $request('/backend/backend/api/method.php?q=sample', $method);
        $value = json_decode($body, true);
        $check($status === 200 && $value['method'] === $method && $value['query'] === 'sample', "normal $method API requests and query parameters reach the script");
    }
    foreach (['qr-generator.js', 'qr-label-renderer.js'] as $asset) {
        [$status, $body] = $request('/backend/backend/api/' . $asset);
        $check($status === 200 && str_contains($body, 'public label asset'), 'public print-label asset remains available');
    }
    foreach ($maintenance as $name) {
        foreach (['GET', 'HEAD', 'POST', 'OPTIONS'] as $method) {
            [$status, $body] = $request('/backend/backend/api/' . $name . '?all=1', $method);
            $check($status === 404 && !str_contains($body, 'UNEXPECTED')
                && !file_exists($root . '/backend/backend/api/executed-maintenance'),
                "$method never executes maintenance route $name");
        }
    }
    foreach (['%64ev-reset-system.php', 'DEV-RESET-SYSTEM.PHP', 'dev-reset-system.php/extra',
        'users-email-migration.php/extra'] as $path) {
        $check($request('/backend/backend/api/' . $path)[0] === 404
            && !file_exists($root . '/backend/backend/api/executed-maintenance'), 'encoded/case/path-info maintenance route is unavailable');
    }
    echo "$checks isolated router checks passed\n";
} finally {
    if (is_resource($server)) { proc_terminate($server); proc_close($server); }
    if (is_dir($root) && preg_match('~[/\\\\]smartflow-router-test-[a-f0-9]{16}$~D', $root)) {
        $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::CHILD_FIRST);
        foreach ($files as $file) { if ($file->isDir()) rmdir($file->getPathname()); else unlink($file->getPathname()); }
        rmdir($root);
    }
}
