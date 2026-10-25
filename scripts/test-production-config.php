<?php
declare(strict_types=1);
// Fail-closed environment guard: pure rules, then copied endpoints that are rejected before any database work.
// Only the final CORS section uses the shared disposable-schema fixture; set TEST_DB_HOST as for the other suites.
require __DIR__ . '/../backend/backend/api/production-config-guard.php';
require __DIR__ . '/stabilization-test-helper.php';

$checks = 0;
$check = function (bool $passed, string $message) use (&$checks): void {
    if (!$passed) throw new RuntimeException($message);
    $checks++;
    echo "PASS $message\n";
};

$valid = ['APP_ENV' => 'production', 'CORS_ALLOWED_ORIGINS' => 'https://smartflow.example.test', 'LOG_LEVEL' => 'error',
    'ALLOW_DEV_TOOLS' => 'false', 'DB_USER' => 'smartflow_app', 'DB_PASS' => 'synthetic-not-a-real-password'];
$problems = fn(array $changes, bool $envFile = true, ?string $host = 'smartflow.example.com', bool $cli = false): array =>
    smartflow_production_config_problems(array_merge($valid, $changes), $envFile, $host, $cli);
$without = fn(string $key): array => smartflow_production_config_problems(array_diff_key($valid, [$key => 1]), true, 'smartflow.example.com', false);

$root = sys_get_temp_dir() . '/smartflow-production-config-' . bin2hex(random_bytes(16));
$server = null;
$fixture = null;
try {
    // Pure rules ---------------------------------------------------------------------------------------------
    $check($problems([]) === [], 'a deliberate production configuration is accepted');
    $check($problems(['APP_ENV' => ' PRODUCTION ']) === [], 'production is recognised after trimming and case folding');
    $check($problems(['CORS_ALLOWED_ORIGINS' => 'https://a.example, https://b.example:8443']) === [], 'several exact https origins are accepted');
    foreach (['*', '', 'https://a.example,*', 'http://a.example', 'https://a.example/', 'https://a.example/app', 'a.example', 'https://'] as $cors) {
        $check($problems(['CORS_ALLOWED_ORIGINS' => $cors]) === ['CORS_ALLOWED_ORIGINS'], 'production rejects CORS value ' . json_encode($cors));
    }
    $check($without('CORS_ALLOWED_ORIGINS') === ['CORS_ALLOWED_ORIGINS'], 'production requires an explicit CORS list');
    foreach (['debug', '', 'verbose'] as $level) {
        $check($problems(['LOG_LEVEL' => $level]) === ['LOG_LEVEL'], 'production rejects LOG_LEVEL ' . json_encode($level));
    }
    $check($without('LOG_LEVEL') === ['LOG_LEVEL'], 'production requires an explicit log level');
    foreach (['info', 'WARNING', 'error'] as $level) $check($problems(['LOG_LEVEL' => $level]) === [], "production accepts LOG_LEVEL $level");
    foreach (['true', 'TRUE', '1', 'yes', 'on'] as $flag) $check($problems(['ALLOW_DEV_TOOLS' => $flag]) === ['ALLOW_DEV_TOOLS'], "production rejects ALLOW_DEV_TOOLS=$flag");
    $check($without('ALLOW_DEV_TOOLS') === [], 'an absent maintenance flag stays disabled');
    foreach (['root', 'ROOT', ''] as $user) $check($problems(['DB_USER' => $user]) === ['DB_USER'], 'production rejects database user ' . json_encode($user));
    $check($without('DB_USER') === ['DB_USER'], 'an unset database user would default to root and is rejected');
    $check($problems(['DB_PASS' => '']) === ['DB_PASS'] && $without('DB_PASS') === ['DB_PASS'], 'production requires a database password');
    $check($problems(['CORS_ALLOWED_ORIGINS' => '*', 'LOG_LEVEL' => 'debug', 'DB_USER' => 'root', 'DB_PASS' => '', 'ALLOW_DEV_TOOLS' => 'true'])
        === ['CORS_ALLOWED_ORIGINS', 'LOG_LEVEL', 'ALLOW_DEV_TOOLS', 'DB_USER', 'DB_PASS'], 'every unsafe setting is reported by name');
    $check(!str_contains(json_encode($problems(['DB_PASS' => ''])), 'synthetic'), 'reported problems contain names only, never configured values');
    foreach (['development', 'test', 'testing'] as $name) {
        $check($problems(['APP_ENV' => $name, 'CORS_ALLOWED_ORIGINS' => '*', 'LOG_LEVEL' => 'debug', 'DB_USER' => 'root', 'DB_PASS' => '', 'ALLOW_DEV_TOOLS' => 'true'], true, 'smartflow.example.com') === [],
            "APP_ENV=$name keeps its development defaults on any host");
    }
    foreach ([null, '', 'prod', 'staging'] as $name) {
        $env = $name === null ? [] : ['APP_ENV' => $name];
        $check(smartflow_production_config_problems($env, true, 'smartflow.example.com', false) === ['APP_ENV'], 'unset or unrecognised APP_ENV ' . json_encode($name) . ' is refused on a public host');
        $check(smartflow_production_config_problems($env, true, 'localhost:5173', false) === [] && smartflow_production_config_problems($env, true, 'smartflow.example.com', true) === [],
            'unset or unrecognised APP_ENV ' . json_encode($name) . ' stays usable locally and from the command line');
    }
    $check(smartflow_production_config_problems([], false, 'smartflow.example.com', false) === ['.env', 'APP_ENV'], 'a missing .env is named when no environment is configured on a public host');
    $check(smartflow_production_config_problems(['APP_ENV' => 'production'], false, 'smartflow.example.com', false) === ['CORS_ALLOWED_ORIGINS', 'LOG_LEVEL', 'DB_USER', 'DB_PASS'], 'production with an empty configuration is refused');
    foreach (['localhost', 'localhost:8000', '127.0.0.1', '127.0.0.1:8000', '[::1]:80', '10.0.2.2', '192.168.137.1', '192.168.1.10:80', '172.16.0.5', 'pc.localhost', 'smartflow.test'] as $host) {
        $check(smartflow_host_is_local($host), "$host is a local development host");
    }
    foreach ([null, '', 'smartflow.urbiztondo.gov.ph', 'smartflow', '203.0.113.9', '8.8.8.8:80', 'localhost.example.com', 'test'] as $host) {
        $check(!smartflow_host_is_local($host), json_encode($host) . ' is not treated as a local development host');
    }
    $check(smartflow_cors_origin_list(' https://a.example , ,https://b.example ') === ['https://a.example', 'https://b.example'], 'CORS origins ignore spaces and empty entries');

    // Copied endpoints, rejected before any database work ---------------------------------------------------------
    mkdir($root, 0700, true);
    foreach (glob(__DIR__ . '/../backend/backend/api/*.php') as $source) copy($source, $root . '/' . basename($source));
    $check(!file_exists($root . '/.env') && !file_exists($root . '/.qr-secret'), 'copied endpoints exclude operational configuration and signing keys');
    $managed = ['APP_ENV', 'CORS_ALLOWED_ORIGINS', 'LOG_LEVEL', 'ALLOW_DEV_TOOLS', 'DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASS', 'QR_SIGNING_SECRET', 'APP_TIMEZONE'];
    $cleanEnvironment = array_diff_key(getenv(), array_flip($managed));
    $startServer = function (string $log) use ($root, $cleanEnvironment, &$server): string {
        $socket = stream_socket_server('tcp://127.0.0.1:0', $errno, $error);
        if (!$socket) throw new RuntimeException('Could not reserve a port');
        $address = stream_socket_get_name($socket, false); fclose($socket);
        $server = proc_open([PHP_BINARY, '-d', 'variables_order=EGPCS', '-d', 'log_errors=1', '-d', 'error_log=' . $log . '.php', '-S', $address, '-t', $root],
            [0 => ['pipe', 'r'], 1 => ['file', $log, 'a'], 2 => ['file', $log, 'a']], $pipes, $root, $cleanEnvironment);
        if (!is_resource($server)) throw new RuntimeException('Could not start the copied endpoint server');
        fclose($pipes[0]);
        for ($attempt = 0; $attempt < 80; $attempt++) {
            if ($probe = @fsockopen('127.0.0.1', (int)substr($address, strrpos($address, ':') + 1), $errno, $error, .1)) { fclose($probe); return 'http://' . $address; }
            usleep(50000);
        }
        throw new RuntimeException('The copied endpoint server did not become ready');
    };
    $stopServer = function () use (&$server): void { if (is_resource($server)) { proc_terminate($server); proc_close($server); } $server = null; };
    $request = function (string $base, string $host, string $method = 'GET', array $headers = []): array {
        $curl = curl_init($base . '/auth-session.php');
        curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_HEADER => true, CURLOPT_TIMEOUT => 20, CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => array_merge(['Host: ' . $host], $headers)]);
        $raw = (string)curl_exec($curl);
        if (curl_errno($curl) !== 0) throw new RuntimeException('Synthetic endpoint transport failed');
        $status = curl_getinfo($curl, CURLINFO_HTTP_CODE); $size = curl_getinfo($curl, CURLINFO_HEADER_SIZE); curl_close($curl);
        return [$status, substr($raw, 0, $size), json_decode(substr($raw, $size), true) ?? []];
    };
    $bogusDatabase = "DB_HOST=127.0.0.1\nDB_NAME=smartflow_guard_test_never_created\nDB_USER=smartflow_guard_test\nDB_PASS=synthetic-not-a-real-password\n";
    $scenario = function (string $name, ?string $envFile, string $host, string $method = 'GET', array $headers = []) use ($root, $startServer, $stopServer, $request): array {
        $path = $root . '/.env';
        if ($envFile === null) { if (file_exists($path)) unlink($path); } else file_put_contents($path, $envFile);
        $log = $root . '/' . $name . '.log';
        $base = $startServer($log);
        try { $result = $request($base, $host, $method, $headers); } finally { $stopServer(); }
        return [...$result, (string)@file_get_contents($log) . (string)@file_get_contents($log . '.php')];
    };
    $incomplete = 'Server configuration is incomplete. Contact the system administrator.';
    $public = 'smartflow.example.com';

    $unsafe = "APP_ENV=production\nCORS_ALLOWED_ORIGINS=*\nLOG_LEVEL=debug\nALLOW_DEV_TOOLS=true\nDB_HOST=127.0.0.1\nDB_NAME=smartflow_guard_test_never_created\nDB_USER=root\nDB_PASS=\n";
    [$status, $headers, $body, $log] = $scenario('unsafe', $unsafe, $public);
    $check($status === 500 && ($body['success'] ?? null) === false && ($body['message'] ?? '') === $incomplete, 'unsafe production configuration is refused with a generic server-configuration response');
    $check(!str_contains(json_encode($body), 'CORS_ALLOWED_ORIGINS') && !stripos($headers, 'access-control-allow-origin'), 'the public response names no setting and grants no CORS access');
    $check(str_contains($log, 'CORS_ALLOWED_ORIGINS') && str_contains($log, 'LOG_LEVEL') && str_contains($log, 'DB_USER'), 'the server log lists the rejected setting names for the administrator');
    [$status, $headers, $body] = $scenario('preflight', $unsafe, $public, 'OPTIONS', ['Origin: https://evil.example', 'Access-Control-Request-Method: POST']);
    $check($status === 500 && !stripos($headers, 'access-control-allow-origin') && ($body['message'] ?? '') === $incomplete, 'an unsafe production configuration also refuses preflight requests');
    [$status, , $body, $log] = $scenario('secret', str_replace('DB_PASS=', 'DB_PASS=synthetic-secret-that-must-not-leak', $unsafe), $public);
    $check($status === 500 && !str_contains(json_encode($body), 'synthetic-secret') && !str_contains($log, 'synthetic-secret'), 'configured secrets appear in neither the response nor the server log');
    [$status, , $body] = $scenario('valid', "APP_ENV=production\nCORS_ALLOWED_ORIGINS=https://smartflow.example.test\nLOG_LEVEL=error\nALLOW_DEV_TOOLS=false\n" . $bogusDatabase, $public);
    $check($status === 500 && ($body['message'] ?? '') === 'Database connection failed', 'a deliberate production configuration passes the guard and proceeds to the database layer');
    [$status, , $body, $log] = $scenario('missing', null, $public);
    $check($status === 500 && ($body['message'] ?? '') === $incomplete && str_contains($log, '.env'), 'a missing .env is refused on a public host before any database work');
    [$status, , $body] = $scenario('typo', "APP_ENV=prod\n" . $bogusDatabase, $public);
    $check($status === 500 && ($body['message'] ?? '') === $incomplete, 'an unrecognised APP_ENV is refused on a public host');
    [$status, , $body] = $scenario('unset-public', $bogusDatabase, $public);
    $check($status === 500 && ($body['message'] ?? '') === $incomplete, 'an .env without APP_ENV is refused on a public host');
    [$status, , $body] = $scenario('unset-local', $bogusDatabase, 'localhost');
    $check($status === 500 && ($body['message'] ?? '') === 'Database connection failed', 'an .env without APP_ENV remains usable on a local development host');
    [$status, , $body] = $scenario('development-public', "APP_ENV=development\n" . $bogusDatabase, $public);
    $check($status === 500 && ($body['message'] ?? '') === 'Database connection failed', 'explicit development configuration is unchanged, including through a public tunnel host');

    // CORS list handling in the real config, using the shared disposable schema ----------------------------------------
    $fixture = new SmartflowStabilizationFixture();
    $fixture->environment['CORS_ALLOWED_ORIGINS'] = 'https://one.example, https://two.example';
    $fixture->startServers();
    $cors = function (string $origin) use ($fixture): string {
        $curl = curl_init($fixture->bases[0] . '/auth-session.php');
        curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_HEADER => true, CURLOPT_TIMEOUT => 20, CURLOPT_HTTPHEADER => ['Origin: ' . $origin]]);
        $raw = (string)curl_exec($curl); $size = curl_getinfo($curl, CURLINFO_HEADER_SIZE); curl_close($curl);
        return substr($raw, 0, $size);
    };
    $check(stripos($cors('https://two.example'), 'Access-Control-Allow-Origin: https://two.example') !== false, 'an origin listed after ", " receives its CORS header');
    $check(stripos($cors('https://one.example'), 'Access-Control-Allow-Origin: https://one.example') !== false, 'the first listed origin receives its CORS header');
    $check(stripos($cors('https://three.example'), 'Access-Control-Allow-Origin') === false, 'an unlisted origin receives no CORS header');
    $fixture->assertCopies();
} finally {
    if (is_resource($server)) { proc_terminate($server); proc_close($server); }
    if ($fixture) $fixture->close();
    if (is_dir($root)) {
        $resolved = realpath($root); $temporary = realpath(sys_get_temp_dir());
        if ($resolved && $temporary && str_starts_with(strtolower($resolved), strtolower($temporary) . DIRECTORY_SEPARATOR)
            && preg_match('/^smartflow-production-config-[a-f0-9]{32}$/D', basename($resolved))) {
            foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($resolved, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::CHILD_FIRST) as $entry) {
                if ($entry->isDir() && !$entry->isLink()) rmdir($entry->getPathname()); else unlink($entry->getPathname());
            }
            rmdir($resolved);
        }
    }
}
echo ($checks + ($fixture->checks ?? 0)) . " production configuration guard checks passed\n";
