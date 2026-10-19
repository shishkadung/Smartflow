<?php
declare(strict_types=1);

// Runs real route/guard code with synthetic config, mail and storage. No operational DB or email.
require_once __DIR__ . '/../backend/backend/api/dev-tools-policy.php';
$root = sys_get_temp_dir() . '/smartflow-dev-security-' . bin2hex(random_bytes(8));
$server = null;
$checks = 0;
$check = static function (bool $pass, string $message) use (&$checks): void {
    if (!$pass) throw new RuntimeException($message);
    $checks++;
    echo "PASS $message\n";
};
try {
    foreach ([[], ['ALLOW_DEV_TOOLS' => 'true'], ['APP_ENV' => 'development'],
        ['APP_ENV' => 'development', 'ALLOW_DEV_TOOLS' => 'false'],
        ['APP_ENV' => 'production', 'ALLOW_DEV_TOOLS' => 'true'],
        ['APP_ENV' => ' PRODUCTION ', 'ALLOW_DEV_TOOLS' => 'true'],
        ['APP_ENV' => 'unknown', 'ALLOW_DEV_TOOLS' => 'true'],
        ['APP_ENV' => 'development', 'ALLOW_DEV_TOOLS' => 'TRUE']] as $environment) {
        $check(!smartflow_dev_tools_enabled($environment), 'missing, production, unknown or malformed maintenance opt-in fails closed');
    }
    foreach (['development', 'test', 'testing'] as $environment) {
        $check(smartflow_dev_tools_enabled(['APP_ENV' => $environment, 'ALLOW_DEV_TOOLS' => 'true']), 'explicit non-production maintenance opt-in is recognized');
    }
    mkdir($root . '/guards', 0700, true);
    mkdir($root . '/recovery', 0700, true);
    file_put_contents($root . '/synthetic.env', "# synthetic only\nSF_SYNTHETIC_FILE=file-value\nSF_SYNTHETIC_PROCESS=file-value\nSF_SYNTHETIC_SERVER=file-value\n");
    putenv('SF_SYNTHETIC_PROCESS=process-value');
    $_ENV['SF_SYNTHETIC_SERVER'] = 'server-value';
    smartflow_load_environment($root . '/synthetic.env');
    $check($_ENV['SF_SYNTHETIC_FILE'] === 'file-value' && $_ENV['SF_SYNTHETIC_PROCESS'] === 'process-value'
        && $_ENV['SF_SYNTHETIC_SERVER'] === 'server-value', 'shared read-only loader preserves explicit server/process settings over file defaults');
    unset($_ENV['SF_SYNTHETIC_FILE'], $_ENV['SF_SYNTHETIC_PROCESS'], $_ENV['SF_SYNTHETIC_SERVER']);
    putenv('SF_SYNTHETIC_PROCESS');
    $api = __DIR__ . '/../backend/backend/api';
    $routes = array_filter(array_map('basename', glob($api . '/dev-*.php')),
        static fn (string $name): bool => !in_array($name, ['dev-block.php', 'dev-tools-policy.php'], true));
    $routes[] = 'users-email-migration.php';
    foreach (array_merge($routes, ['dev-block.php', 'dev-tools-policy.php']) as $name) copy($api . '/' . $name, $root . '/guards/' . $name);
    file_put_contents($root . '/guards/.env', "APP_ENV=development\nALLOW_DEV_TOOLS=false\n");
    file_put_contents($root . '/guards/config.php', '<?php file_put_contents(__DIR__ . "/config-loaded", "SYNTHETIC"); define("SMARTFLOW_ALLOW_DEV_TOOLS", getenv("SF_TEST_MAINTENANCE") === "true");');
    file_put_contents($root . '/guards/maintenance.php', '<?php require __DIR__ . "/dev-block.php"; echo json_encode(["continued" => true, "method" => $_SERVER["REQUEST_METHOD"]]);');
    copy($api . '/auth-forgot-password.php', $root . '/recovery/auth-forgot-password.php');
    file_put_contents($root . '/recovery/config.php', <<<'PHP'
<?php
define('SMARTFLOW_ALLOW_DEV_TOOLS', ($_GET['mode'] ?? '') === 'enabled');
function get_json_body(): array { return json_decode(file_get_contents('php://input'), true) ?? []; }
function smartflow_public_auth_limit(...$arguments): void {}
function json_response($body, int $status = 200): void {
    http_response_code($status); header('Content-Type: application/json'); header('Cache-Control: no-store'); echo json_encode($body); exit;
}
class SyntheticStatement {
    public function __construct(private string $sql) {}
    public function execute(array $arguments = []): void {}
    public function fetch() {
        $name = get_json_body()['username'] ?? '';
        if ($name === 'missing') return false;
        return ['id' => 1, 'username' => 'synthetic', 'name' => 'Synthetic account', 'email' => $name === 'no-email' ? null : 'sample@example.invalid', 'is_active' => $name === 'inactive' ? 0 : 1];
    }
    public function fetchColumn() { return '2099-01-01 12:00:00'; }
}
class SyntheticDatabase {
    public function prepare(string $sql) { return new SyntheticStatement($sql); }
    public function query(string $sql) { return new SyntheticStatement($sql); }
    public function lastInsertId() { return '1'; }
}
$pdo = new SyntheticDatabase();
PHP);
    file_put_contents($root . '/recovery/mailtrap-api-config.php', <<<'PHP'
<?php
function send_email_mailtrap_api(string $to, string $subject, string $body): array {
    file_put_contents(__DIR__ . '/mail-attempted', preg_match('/reset code is: [0-9]{6}/', $body) ? 'code sent through private channel' : 'invalid');
    return ['success' => (get_json_body()['username'] ?? '') !== 'mail-failure'];
}
PHP);
    $socket = stream_socket_server('tcp://127.0.0.1:0', $errno, $error);
    if (!$socket) throw new RuntimeException('Could not reserve synthetic server port');
    $address = stream_socket_get_name($socket, false);
    fclose($socket);
    $server = proc_open([PHP_BINARY, '-S', $address, '-t', $root],
        [0 => ['pipe', 'r'], 1 => ['file', $root . '/server.log', 'a'], 2 => ['file', $root . '/server.log', 'a']], $pipes, $root);
    if (!is_resource($server)) throw new RuntimeException('Could not start synthetic server');
    fclose($pipes[0]);
    for ($attempt = 0; $attempt < 40; $attempt++) {
        $probe = @fsockopen('127.0.0.1', (int)substr($address, strrpos($address, ':') + 1), $errno, $error, .1);
        if ($probe) { fclose($probe); break; }
        usleep(50000);
    }
    $request = static function (string $path, string $method = 'GET', ?array $body = null) use ($address): array {
        $curl = curl_init('http://' . $address . $path);
        curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 5, CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_NOBODY => $method === 'HEAD', CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Origin: https://synthetic.example.invalid']]);
        if ($body !== null) curl_setopt($curl, CURLOPT_POSTFIELDS, json_encode($body, JSON_THROW_ON_ERROR));
        $text = curl_exec($curl);
        if ($text === false) throw new RuntimeException('Synthetic HTTP request failed');
        $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
        return [$status, $text];
    };
    foreach (array_merge($routes, ['dev-block.php']) as $name) {
        foreach (['GET', 'HEAD', 'POST', 'OPTIONS'] as $method) {
            [$status, $body] = $request('/guards/' . $name . '?all=1', $method);
            $check($status === 404 && !file_exists($root . '/guards/config-loaded'), "$method blocks $name before any database/configuration load even without router or Apache");
        }
        $process = proc_open([PHP_BINARY, $root . '/guards/' . $name], [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $cliPipes, $root);
        fclose($cliPipes[0]); stream_get_contents($cliPipes[1]); fclose($cliPipes[1]); stream_get_contents($cliPipes[2]); fclose($cliPipes[2]);
        $check(proc_close($process) === 1 && !file_exists($root . '/guards/config-loaded'), "CLI $name requires explicit maintenance confirmation before configuration load");
    }
    foreach ([['false', 'development', [], 1], ['true', 'production', [], 1], ['true', 'unknown', [], 1],
        ['true', 'development', [], 0], ['true', 'development', ['--method=POST'], 0]] as [$flag, $environment, $arguments, $expectedExit]) {
        if (file_exists($root . '/guards/config-loaded')) unlink($root . '/guards/config-loaded');
        $process = proc_open(array_merge([PHP_BINARY, $root . '/guards/maintenance.php', '--allow-maintenance'], $arguments),
            [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $cliPipes, $root,
            array_merge(getenv(), ['SF_TEST_MAINTENANCE' => $flag, 'APP_ENV' => $environment, 'ALLOW_DEV_TOOLS' => $flag]));
        fclose($cliPipes[0]); $stdout = stream_get_contents($cliPipes[1]); fclose($cliPipes[1]); stream_get_contents($cliPipes[2]); fclose($cliPipes[2]);
        $status = proc_close($process);
        $expectedMethod = $arguments ? 'POST' : 'GET';
        $check($status === $expectedExit && ($status !== 0 || (json_decode($stdout, true)['method'] ?? null) === $expectedMethod)
            && ($status === 0 || !file_exists($root . '/guards/config-loaded')), 'CLI maintenance checks both opt-ins before database/configuration and keeps its requested method');
    }
    $expected = ['success' => true, 'message' => 'If an account exists with that username, a password reset code has been generated.'];
    foreach (['enabled', 'disabled'] as $mode) {
        foreach (['active', 'missing', 'inactive', 'no-email', 'mail-failure'] as $username) {
            [$status, $body] = $request('/recovery/auth-forgot-password.php?mode=' . $mode, 'POST', ['username' => $username]);
            $check($status === 200 && json_decode($body, true) === $expected,
                "recovery exposes the identical generic response for $username with maintenance $mode");
        }
    }
    $check(file_get_contents($root . '/recovery/mail-attempted') === 'code sent through private channel', 'recovery still gives the generated code to its private email channel');
    $check($request('/recovery/auth-forgot-password.php', 'GET')[0] === 405, 'recovery remains POST-only');
    $check($request('/recovery/auth-forgot-password.php', 'POST', ['username' => ''])[0] === 400, 'recovery still validates the required username');
    echo "$checks synthetic developer-security checks passed\n";
} finally {
    if (is_resource($server)) { proc_terminate($server); proc_close($server); }
    if (is_dir($root) && preg_match('~[/\\\\]smartflow-dev-security-[a-f0-9]{16}$~D', $root)) {
        $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::CHILD_FIRST);
        foreach ($files as $file) { if ($file->isDir()) rmdir($file->getPathname()); else unlink($file->getPathname()); }
        rmdir($root);
    }
}
