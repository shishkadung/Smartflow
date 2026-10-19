<?php
// Shared private-file-free fixture for the bounded stabilization regressions.
declare(strict_types=1);

final class SmartflowStabilizationFixture
{
    public string $root;
    public string $database;
    public PDO $db;
    public array $bases = [];
    public array $environment;
    public int $checks = 0;
    private array $servers = [];
    private array $copies = [];
    private bool $created = false;

    public function __construct(?callable $copyTransform = null)
    {
        $this->root = sys_get_temp_dir() . '/smartflow-stabilization-test-' . bin2hex(random_bytes(16));
        $this->database = 'smartflow_request_test_' . bin2hex(random_bytes(6));
        $host = getenv('TEST_DB_HOST') ?: '127.0.0.2';
        $user = getenv('TEST_DB_USER') ?: 'root';
        $pass = getenv('TEST_DB_PASS') ?: '';
        $this->environment = array_merge(getenv(), ['DB_HOST' => $host, 'DB_NAME' => $this->database,
            'DB_USER' => $user, 'DB_PASS' => $pass, 'APP_ENV' => 'test', 'APP_TIMEZONE' => 'Asia/Manila',
            'ALLOW_DEV_TOOLS' => 'false', 'MAILTRAP_API_TOKEN' => '', 'QR_SIGNING_SECRET' => bin2hex(random_bytes(32))]);
        $this->db = $this->connect(false);
        try {
            mkdir($this->root, 0700, true);
            foreach (glob(__DIR__ . '/../backend/backend/api/*.php') as $source) {
                $name = basename($source);
                $contents = (string)file_get_contents($source);
                $copy = $copyTransform ? $copyTransform($name, $contents, $this->root) : $contents;
                file_put_contents($this->root . '/' . $name, $copy);
                $this->copies[$name] = ['source' => hash('sha256', $contents), 'copy' => hash('sha256', $copy)];
            }
            $this->check(!file_exists($this->root . '/.env') && !file_exists($this->root . '/.qr-secret') && !is_dir($this->root . '/uploads'),
                'fixture excludes operational configuration, signing keys and uploads');
            $schema = (string)file_get_contents(__DIR__ . '/../backend/backend/api-schema.sql');
            if (preg_match('/^\s*(?:USE\s|(?:CREATE|ALTER|DROP)\s+DATABASE\s)/im', $schema)
                || !preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', $this->database)) throw new RuntimeException('Unsafe fixture schema');
            $this->db->exec("CREATE DATABASE `{$this->database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
            $this->created = true;
            $this->db->exec("USE `{$this->database}`");
            $this->db->exec($schema);
            $this->db->exec("SET time_zone = '+08:00'");
        } catch (Throwable $error) { $this->close(); throw $error; }
    }

    public function connect(bool $select = true): PDO
    {
        return new PDO('mysql:host=' . $this->environment['DB_HOST'] . ($select ? ';dbname=' . $this->database : '') . ';charset=utf8mb4',
            $this->environment['DB_USER'], $this->environment['DB_PASS'],
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);
    }

    public function check(bool $passed, string $message): void
    {
        if (!$passed) throw new RuntimeException($message);
        $this->checks++;
        echo "PASS $message\n";
    }

    public function user(int $id, string $name, int $office, string $role = 'staff'): void
    {
        $this->db->prepare('INSERT INTO users(id,name,username,password_hash,office_id,role) VALUES(?,?,?,?,?,?)')
            ->execute([$id, 'Synthetic ' . $name, $name, password_hash('synthetic-only-password', PASSWORD_DEFAULT), $office, $role]);
    }

    public function startServers(int $count = 1): void
    {
        for ($i = 0; $i < $count; $i++) {
            $socket = stream_socket_server('tcp://127.0.0.1:0', $errno, $error);
            if (!$socket) throw new RuntimeException('Could not reserve fixture port');
            $address = stream_socket_get_name($socket, false); fclose($socket);
            $server = proc_open([PHP_BINARY, '-d', 'variables_order=EGPCS', '-S', $address, '-t', $this->root],
                [0 => ['pipe', 'r'], 1 => ['file', $this->root . "/server-$i.log", 'a'], 2 => ['file', $this->root . "/server-$i.log", 'a']],
                $pipes, $this->root, $this->environment);
            if (!is_resource($server)) throw new RuntimeException('Could not start copied endpoint server');
            fclose($pipes[0]); $this->servers[] = $server; $this->bases[] = 'http://' . $address;
            $ready = false;
            for ($attempt = 0; $attempt < 60; $attempt++) {
                if ($probe = @fsockopen('127.0.0.1', (int)substr($address, strrpos($address, ':') + 1), $errno, $error, .1)) {
                    fclose($probe); $ready = true; break;
                }
                usleep(50000);
            }
            if (!$ready) throw new RuntimeException('Copied endpoint server did not become ready');
        }
    }

    public function begin(string $path, ?string $token = null, ?array $body = null, int $server = 0): array
    {
        $multi = curl_multi_init(); $curl = curl_init($this->bases[$server] . '/' . $path);
        $headers = ['Content-Type: application/json'];
        if ($token !== null) $headers[] = 'Authorization: Bearer ' . $token;
        curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 25, CURLOPT_HTTPHEADER => $headers]);
        if ($body !== null) curl_setopt_array($curl, [CURLOPT_POST => true, CURLOPT_POSTFIELDS => json_encode($body, JSON_THROW_ON_ERROR)]);
        curl_multi_add_handle($multi, $curl);
        return [$multi, $curl];
    }

    public function finish(array $pending): array
    {
        [$multi, $curl] = $pending;
        do { curl_multi_exec($multi, $running); if ($running) curl_multi_select($multi, .05); } while ($running);
        $raw = curl_multi_getcontent($curl);
        $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $failed = curl_errno($curl) !== 0;
        curl_multi_remove_handle($multi, $curl); curl_close($curl); curl_multi_close($multi);
        if ($failed || $status === 0) throw new RuntimeException('Synthetic endpoint transport failed');
        return [$status, json_decode($raw, true), $raw];
    }

    public function call(string $path, ?string $token = null, ?array $body = null, int $server = 0): array
    {
        return $this->finish($this->begin($path, $token, $body, $server));
    }

    public function login(string $name, int $server = 0): string
    {
        [$status, $result] = $this->call('auth-login.php', body: ['username' => $name, 'password' => 'synthetic-only-password'], server: $server);
        if ($status !== 200 || !isset($result['token'])) throw new RuntimeException('Synthetic login failed');
        return $result['token'];
    }

    public function waitForLock(array $pending, string $needle): void
    {
        [$multi] = $pending;
        $read = $this->db->prepare('SELECT trx_query FROM information_schema.INNODB_TRX t JOIN information_schema.PROCESSLIST p ON p.ID=t.trx_mysql_thread_id WHERE p.DB=? AND t.trx_state="LOCK WAIT"');
        $until = microtime(true) + 15;
        do {
            curl_multi_exec($multi, $running);
            $read->execute([$this->database]);
            foreach ($read->fetchAll(PDO::FETCH_COLUMN) as $query) if (str_contains(strtolower((string)$query), strtolower($needle))) return;
            if (!$running) throw new RuntimeException('Request ended before the intended resource wait');
            curl_multi_select($multi, .05); usleep(25000);
        } while (microtime(true) < $until);
        throw new RuntimeException('Intended resource row wait was not observed');
    }

    public function assertCopies(): void
    {
        foreach ($this->copies as $name => $hashes) {
            if (hash_file('sha256', __DIR__ . '/../backend/backend/api/' . $name) !== $hashes['source']
                || hash_file('sha256', $this->root . '/' . $name) !== $hashes['copy']) throw new RuntimeException('Fixture or source changed during the test');
        }
        $this->check(true, 'reviewed application sources and copied endpoint logic remain unchanged during the test');
    }

    public function close(): void
    {
        foreach ($this->servers as $server) { proc_terminate($server); proc_close($server); }
        $this->servers = [];
        if ($this->created) {
            if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', $this->database)) throw new RuntimeException('Unsafe fixture database cleanup');
            $this->db->exec('USE information_schema'); $this->db->exec("DROP DATABASE `{$this->database}`");
            $this->created = false;
            $read = $this->db->prepare('SELECT COUNT(*) FROM SCHEMATA WHERE SCHEMA_NAME=?'); $read->execute([$this->database]);
            $this->check((int)$read->fetchColumn() === 0, 'owned disposable database removed');
        }
        if (is_dir($this->root)) {
            $resolved = realpath($this->root); $temporary = realpath(sys_get_temp_dir());
            if (!$resolved || !$temporary || !str_starts_with(strtolower($resolved), strtolower($temporary) . DIRECTORY_SEPARATOR)
                || !preg_match('/^smartflow-stabilization-test-[a-f0-9]{32}$/D', basename($resolved))) throw new RuntimeException('Unsafe fixture file cleanup');
            foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($resolved, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::CHILD_FIRST) as $entry) {
                if ($entry->isDir() && !$entry->isLink()) rmdir($entry->getPathname()); else unlink($entry->getPathname());
            }
            rmdir($resolved);
            $this->check(!file_exists($resolved), 'private-free fixture, synthetic rate/cache files and server logs removed');
        }
    }
}
