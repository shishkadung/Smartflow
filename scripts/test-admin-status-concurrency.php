<?php
// Real endpoints, two private-file-free servers and an owned disposable database.
declare(strict_types=1);
$project = dirname(__DIR__);
$root = sys_get_temp_dir() . '/smartflow-admin-test-' . bin2hex(random_bytes(8));
$database = 'smartflow_request_test_' . bin2hex(random_bytes(6));
$created = false;
$servers = [];
$checks = 0;
function adminCheck(bool $pass, string $message): void {
    global $checks;
    if (!$pass) throw new RuntimeException($message);
    $checks++;
    echo "PASS $message\n";
}
function adminCall(string $base, string $path, ?string $token = null, ?array $body = null): array {
    $curl = curl_init($base . '/' . $path);
    $headers = ['Content-Type: application/json'];
    if ($token !== null) $headers[] = 'Authorization: Bearer ' . $token;
    curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 15, CURLOPT_HTTPHEADER => $headers]);
    if ($body !== null) curl_setopt_array($curl, [CURLOPT_POST => true, CURLOPT_POSTFIELDS => json_encode($body, JSON_THROW_ON_ERROR)]);
    $raw = curl_exec($curl);
    if ($raw === false) throw new RuntimeException('Isolated endpoint request failed');
    $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
    curl_close($curl);
    return [$status, json_decode($raw, true, 512, JSON_THROW_ON_ERROR)];
}
$host = getenv('TEST_DB_HOST') ?: '127.0.0.1';
$dbUser = getenv('TEST_DB_USER') ?: 'root';
$dbPass = getenv('TEST_DB_PASS') ?: '';
$pdo = new PDO("mysql:host=$host;charset=utf8mb4", $dbUser, $dbPass,
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);
try {
    mkdir($root, 0700, true);
    foreach (glob($project . '/backend/backend/api/*.php') as $source) copy($source, $root . '/' . basename($source));
    adminCheck(!file_exists($root . '/.env') && !file_exists($root . '/.qr-secret'), 'server copy contains no operational settings or signing key');
    $schema = file_get_contents($project . '/backend/backend/api-schema.sql');
    if (preg_match('/^\s*(?:USE\s|(?:CREATE|DROP)\s+DATABASE\s)/im', $schema)) throw new RuntimeException('Unsafe test schema');
    $pdo->exec("CREATE DATABASE `$database` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $created = true;
    $pdo->exec("USE `$database`");
    $pdo->exec($schema);
    $insert = $pdo->prepare('INSERT INTO users(id,name,username,password_hash,office_id,role) VALUES(?,?,?,?,?,?)');
    foreach ([[101, 'a', 'admin'], [102, 'b', 'admin'], [103, 'staff', 'staff']] as [$id, $name, $role]) {
        $insert->execute([$id, 'Synthetic ' . $name, $name, password_hash('synthetic-only-password', PASSWORD_DEFAULT), 4, $role]);
    }
    $environment = array_merge(getenv(), ['DB_HOST' => $host, 'DB_NAME' => $database,
        'DB_USER' => $dbUser, 'DB_PASS' => $dbPass, 'APP_ENV' => 'test', 'APP_TIMEZONE' => 'Asia/Manila',
        'ALLOW_DEV_TOOLS' => 'false', 'MAILTRAP_API_TOKEN' => '', 'QR_SIGNING_SECRET' => bin2hex(random_bytes(32))]);
    for ($i = 0; $i < 2; $i++) {
        $socket = stream_socket_server('tcp://127.0.0.1:0', $errno, $error);
        if (!$socket) throw new RuntimeException('Could not reserve test port');
        $address = stream_socket_get_name($socket, false);
        fclose($socket);
        $server = proc_open([PHP_BINARY, '-d', 'variables_order=EGPCS', '-S', $address, '-t', $root],
            [0 => ['pipe', 'r'], 1 => ['file', $root . "/server-$i.log", 'a'], 2 => ['file', $root . "/server-$i.log", 'a']], $pipes, $root, $environment);
        if (!is_resource($server)) throw new RuntimeException('Could not start test server');
        fclose($pipes[0]);
        $servers[] = $server;
        $bases[$i] = 'http://' . $address;
        for ($attempt = 0; $attempt < 60; $attempt++) {
            if ($probe = @fsockopen('127.0.0.1', (int)substr($address, strrpos($address, ':') + 1), $errno, $error, .1)) { fclose($probe); break; }
            usleep(50000);
        }
    }
    $login = static function (string $name) use ($bases): string {
        [$status, $data] = adminCall($bases[0], 'auth-login.php', body: ['username' => $name, 'password' => 'synthetic-only-password']);
        if ($status !== 200 || !isset($data['token'])) throw new RuntimeException('Synthetic login failed');
        return $data['token'];
    };
    $a = $login('a'); $b = $login('b'); $staff = $login('staff');
    $set = static fn (string $token, int $id, mixed $active): array => adminCall($bases[0], 'users-set-active.php', $token, ['user_id' => $id, 'active' => $active]);
    adminCheck($set($staff, 102, false)[0] === 403, 'staff cannot change account status');
    adminCheck($set($a, 101, false)[0] === 403, 'admin cannot deactivate self');
    adminCheck($set($a, 102, 'false')[0] === 400, 'nonboolean status cannot bypass validation');
    adminCheck($set($a, 9999, false)[0] === 404, 'missing target is rejected');
    adminCheck($set($a, 103, false)[0] === 200 && adminCall($bases[0], 'auth-session.php', $staff)[0] === 401,
        'ordinary staff deactivation revokes its existing session');
    adminCheck($set($a, 103, true)[0] === 200 && adminCall($bases[0], 'auth-session.php', $staff)[0] === 401,
        'reactivation does not revive revoked sessions');
    adminCheck($set($a, 102, false)[0] === 200, 'another admin may be deactivated while one remains');
    adminCheck($set($a, 102, false)[0] === 200, 'repeated deactivation of an inactive admin is harmless');
    adminCheck($set($a, 102, true)[0] === 200 && adminCall($bases[0], 'auth-session.php', $b)[0] === 401,
        'admin reactivation preserves prior session revocation');
    $b = $login('b');
    // Force overlap after the authorization/count boundary without changing it.
    $pdo->exec('CREATE TRIGGER test_admin_overlap BEFORE UPDATE ON users FOR EACH ROW BEGIN IF OLD.is_active=1 AND NEW.is_active=0 THEN DO SLEEP(1); END IF; END');
    $multi = curl_multi_init(); $handles = [];
    foreach ([[$a, 102], [$b, 101]] as $i => [$token, $target]) {
        $curl = curl_init($bases[$i] . '/users-set-active.php');
        curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_POST => true, CURLOPT_TIMEOUT => 15,
            CURLOPT_POSTFIELDS => json_encode(['user_id' => $target, 'active' => false]),
            CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Authorization: Bearer ' . $token]]);
        curl_multi_add_handle($multi, $curl); $handles[] = $curl;
    }
    do {
        $status = curl_multi_exec($multi, $running);
        if ($running) curl_multi_select($multi, .25);
    } while ($running && $status === CURLM_OK);
    $statuses = [];
    foreach ($handles as $curl) {
        $statuses[] = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_multi_remove_handle($multi, $curl); curl_close($curl);
    }
    curl_multi_close($multi);
    sort($statuses);
    adminCheck($statuses === [200, 401], 'overlapping mutual deactivation allows one write and rejects the ended caller session');
    adminCheck((int)$pdo->query("SELECT COUNT(*) FROM users WHERE role='admin' AND is_active=1")->fetchColumn() === 1,
        'overlapping administrator decisions retain one active administrator');
} finally {
    foreach ($servers as $server) { proc_terminate($server); proc_close($server); }
    if ($created) {
        $pdo->exec('USE information_schema');
        $pdo->exec("DROP DATABASE `$database`");
        $read = $pdo->prepare('SELECT COUNT(*) FROM SCHEMATA WHERE SCHEMA_NAME=?'); $read->execute([$database]);
        adminCheck((int)$read->fetchColumn() === 0, 'owned disposable database removed');
    }
    if (is_dir($root)) {
        $resolved = realpath($root); $temporary = realpath(sys_get_temp_dir());
        if (!$resolved || !$temporary || !str_starts_with(strtolower($resolved), strtolower($temporary) . DIRECTORY_SEPARATOR)
            || !preg_match('/^smartflow-admin-test-[a-f0-9]{16}$/', basename($resolved))) throw new RuntimeException('Unsafe fixture cleanup');
        foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($resolved, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::CHILD_FIRST) as $entry) {
            if ($entry->isDir() && !$entry->isLink()) rmdir($entry->getPathname()); else unlink($entry->getPathname());
        }
        rmdir($resolved);
    }
}
echo "$checks isolated admin-status checks passed\n";
