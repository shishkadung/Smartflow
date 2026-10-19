<?php
// Private system backup and isolated restore verification. Never restores the live DB.
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
$project = dirname(__DIR__);
$api = 'C:/xampp/htdocs/Smartflow/backend/backend/api';
$mode = $argv[1] ?? 'backup';
if (!in_array($mode, ['backup', 'verify'], true)) throw new InvalidArgumentException('Use backup or verify');
// Verify takes the snapshot first and its allowed parent separately.
$backupRoot = ($mode === 'verify' ? ($argv[3] ?? null) : ($argv[2] ?? null)) ?? $project . '/backups';
$settings = [];
foreach (file($api . '/.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
    if (str_starts_with(trim($line), '#') || !str_contains($line, '=')) continue;
    [$key, $value] = explode('=', $line, 2); $settings[trim($key)] = trim($value);
}
date_default_timezone_set($settings['APP_TIMEZONE'] ?? 'Asia/Manila');
$dbName = $settings['DB_NAME'] ?? 'smartflow';
$dbHost = $settings['DB_HOST'] ?? 'localhost';
$dbUser = $settings['DB_USER'] ?? 'root';
$dbPass = $settings['DB_PASS'] ?? '';
function connectBackupDatabase(string $name = ''): PDO {
    global $dbHost, $dbUser, $dbPass;
    return new PDO('mysql:host=' . $dbHost . ($name === '' ? '' : ';dbname=' . $name) . ';charset=utf8mb4', $dbUser, $dbPass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC, PDO::ATTR_STRINGIFY_FETCHES => true]);
}
function databaseFingerprint(PDO $db): array {
    $result = [];
    foreach ($db->query("SHOW FULL TABLES WHERE Table_type='BASE TABLE'")->fetchAll(PDO::FETCH_NUM) as [$table]) {
        $quoted = '`' . str_replace('`', '``', $table) . '`';
        $columns = array_column($db->query('SHOW COLUMNS FROM ' . $quoted)->fetchAll(), 'Field');
        $primary = $db->query('SHOW KEYS FROM ' . $quoted . " WHERE Key_name='PRIMARY'")->fetchAll();
        $order = $primary ? array_column($primary, 'Column_name') : $columns;
        $orderSql = implode(',', array_map(fn($column) => ($primary ? '' : 'BINARY ') . '`' . str_replace('`', '``', $column) . '`', $order));
        $rows = $db->query('SELECT * FROM ' . $quoted . ' ORDER BY ' . $orderSql);
        $hash = hash_init('sha256'); $count = 0;
        while ($row = $rows->fetch(PDO::FETCH_NUM)) { hash_update($hash, serialize($row)); $count++; }
        $schema = $db->query('SHOW CREATE TABLE ' . $quoted)->fetch(PDO::FETCH_NUM)[1];
        // INSERT IGNORE during live schema bootstrap advances these counters.
        // Compare structural DDL separately from this changing allocation metadata.
        $schema = preg_replace('/ AUTO_INCREMENT=\d+\b/', '', $schema);
        $result[$table] = ['rows' => $count, 'data_sha256' => hash_final($hash), 'schema_sha256' => hash('sha256', $schema)];
    }
    ksort($result); return $result;
}
function backupCopy(string $from, string $to): void {
    if (!is_dir(dirname($to)) && !mkdir(dirname($to), 0700, true)) throw new RuntimeException('Could not create private backup directory');
    if (!copy($from, $to)) throw new RuntimeException('Could not copy a private backup file');
    @chmod($to, 0600);
}
function backupFiles(string $root): array {
    $files = [];
    foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS)) as $entry) {
        if ($entry->isLink()) throw new RuntimeException('Backup must not contain symbolic links');
        if (!$entry->isFile() || $entry->getFilename() === 'manifest.json') continue;
        $relative = str_replace('\\', '/', substr($entry->getPathname(), strlen($root) + 1));
        $files[$relative] = hash_file('sha256', $entry->getPathname());
    }
    ksort($files); return $files;
}
function runBackupMysql(string $tool, array $arguments, ?string $input = null): void {
    global $backupRoot, $dbHost, $dbUser, $dbPass;
    $credentials = $backupRoot . '/.client-' . bin2hex(random_bytes(8)) . '.cnf';
    $escape = fn($value) => str_replace(['\\', '"', "\r", "\n"], ['\\\\', '\\"', '\\r', '\\n'], $value);
    file_put_contents($credentials, "[client]\nhost=\"" . $escape($dbHost) . "\"\nuser=\"" . $escape($dbUser) . "\"\npassword=\"" . $escape($dbPass) . "\"\n");
    @chmod($credentials, 0600);
    try {
        $process = proc_open(array_merge(['C:/xampp/mysql/bin/' . $tool . '.exe', '--defaults-extra-file=' . $credentials], $arguments),
            [0 => $input === null ? ['pipe', 'r'] : ['file', $input, 'r'], 1 => ['file', 'NUL', 'w'], 2 => ['pipe', 'w']], $pipes);
        if (!is_resource($process)) throw new RuntimeException('Could not start database tool');
        if ($input === null) fclose($pipes[0]);
        stream_get_contents($pipes[2]); fclose($pipes[2]);
        $exit = proc_close($process);
        if ($exit !== 0) throw new RuntimeException('Database tool failed (exit ' . $exit . ')');
    } finally { if (is_file($credentials)) unlink($credentials); }
}
function restoreBackupSnapshot(string $backup, array $defaults): PDO {
    global $server, $qaDatabase, $qaCreated, $dbName;
    // Own snapshots contain no schema-switch statements. Refuse such imports.
    if (preg_match('/^\s*(USE\b|(?:CREATE|ALTER|DROP)\s+DATABASE\b)/mi', file_get_contents($backup . '/database.sql'))) throw new RuntimeException('Backup SQL must not switch or manage databases');
    $server = connectBackupDatabase();
    $qaDatabase = 'smartflow_restore_qa_' . bin2hex(random_bytes(8));
    if (!preg_match('/^smartflow_restore_qa_[a-f0-9]{16}$/', $qaDatabase) || $qaDatabase === $dbName) throw new RuntimeException('Unsafe restore target');
    foreach ($defaults as $value) if (!preg_match('/^[a-zA-Z0-9_]+$/', $value)) throw new RuntimeException('Invalid backup database defaults');
    $server->exec('CREATE DATABASE `' . $qaDatabase . '` CHARACTER SET ' . $defaults['charset_name'] . ' COLLATE ' . $defaults['collation_name']);
    $qaCreated = true;
    runBackupMysql('mysql', ['--default-character-set=utf8mb4', $qaDatabase], $backup . '/database.sql');
    return connectBackupDatabase($qaDatabase);
}
if ($mode === 'backup') {
    if (!is_dir($backupRoot) && !mkdir($backupRoot, 0700, true)) throw new RuntimeException('Could not create private backup storage');
    if (!is_file($backupRoot . '/.htaccess')) file_put_contents($backupRoot . '/.htaccess', "Require all denied\n");
}
$qaDatabase = null; $qaCreated = false;
try {
    if ($mode === 'backup') {
        $backup = $backupRoot . '/smartflow-system-' . date('Ymd-His') . '-' . bin2hex(random_bytes(3));
        mkdir($backup, 0700);
        $db = connectBackupDatabase($dbName);
        $defaults = $db->query('SELECT DEFAULT_CHARACTER_SET_NAME charset_name, DEFAULT_COLLATION_NAME collation_name FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=' . $db->quote($dbName))->fetch();
        runBackupMysql('mysqldump', ['--single-transaction', '--routines', '--triggers', '--events', '--hex-blob', '--default-character-set=utf8mb4', '--result-file=' . $backup . '/database.sql', $dbName]);
        // Fingerprint the actual dump, even when source writes overlap its creation.
        $restored = restoreBackupSnapshot($backup, $defaults);
        $tables = databaseFingerprint($restored);
        backupCopy($api . '/.env', $backup . '/private-api/.env');
        $key = trim($settings['QR_SIGNING_SECRET'] ?? '') ?: trim((string)@file_get_contents($api . '/.qr-secret'));
        if (strlen($key) < 32 || hash_equals(hash('sha256', 'smartflow-qr-v1-urbiztondo'), $key)) throw new RuntimeException('A strong existing signing key is required');
        file_put_contents($backup . '/private-api/.qr-secret', $key); @chmod($backup . '/private-api/.qr-secret', 0600);
        $_ENV['QR_SIGNING_SECRET'] = $key;
        require_once $project . '/backend/backend/api/qr-token-helper.php';
        $continuityDoc = $restored->query('SELECT id FROM documents ORDER BY id LIMIT 1')->fetchColumn();
        $continuityQr = $continuityDoc ? smartflow_qr_issue((string)$continuityDoc) : null;
        $uploads = $api . '/uploads';
        if (is_dir($uploads)) foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($uploads, FilesystemIterator::SKIP_DOTS)) as $entry) {
            if ($entry->isLink()) throw new RuntimeException('Upload backup must not follow symbolic links');
            if ($entry->isFile()) backupCopy($entry->getPathname(), $backup . '/private-api/uploads/' . substr($entry->getPathname(), strlen($uploads) + 1));
        }
        $manifest = ['format' => 2, 'created_at' => date('c'), 'source_database' => $dbName, 'database_defaults' => $defaults, 'tables' => $tables, 'continuity_qr' => $continuityQr, 'files' => backupFiles($backup)];
        file_put_contents($backup . '/manifest.json', json_encode($manifest, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR));
        echo 'Private system backup created: ' . basename($backup) . PHP_EOL;
        echo 'Includes database, private environment, stable QR key, and uploads.' . PHP_EOL;
    } else {
        $backup = realpath($argv[2] ?? ''); $root = realpath($backupRoot);
        if (!$backup || !$root || !str_starts_with(strtolower($backup), strtolower($root) . DIRECTORY_SEPARATOR)) throw new RuntimeException('Choose a system snapshot inside project backups');
        $manifest = json_decode(file_get_contents($backup . '/manifest.json'), true, 512, JSON_THROW_ON_ERROR);
        if (($manifest['format'] ?? null) !== 2 || backupFiles($backup) !== $manifest['files']) throw new RuntimeException('Backup integrity check failed');
        $restored = restoreBackupSnapshot($backup, $manifest['database_defaults']);
        $restoredTables = databaseFingerprint($restored);
        if ($restoredTables !== $manifest['tables']) {
            $differences = [];
            foreach ($manifest['tables'] as $table => $expected) if (($restoredTables[$table] ?? null) !== $expected) {
                $actual = $restoredTables[$table] ?? [];
                $differences[$table] = ['row_count_matches' => ($actual['rows'] ?? null) === $expected['rows'],
                    'data_matches' => ($actual['data_sha256'] ?? null) === $expected['data_sha256'], 'schema_matches' => ($actual['schema_sha256'] ?? null) === $expected['schema_sha256']];
                if (!$differences[$table]['schema_matches']) {
                    $quoted = '`' . str_replace('`', '``', $table) . '`';
                    $sourceLines = explode("\n", connectBackupDatabase($dbName)->query('SHOW CREATE TABLE ' . $quoted)->fetch(PDO::FETCH_NUM)[1]);
                    $restoredLines = explode("\n", $restored->query('SHOW CREATE TABLE ' . $quoted)->fetch(PDO::FETCH_NUM)[1]);
                    $differences[$table]['schema_difference'] = ['source' => array_values(array_diff($sourceLines, $restoredLines)), 'restored' => array_values(array_diff($restoredLines, $sourceLines))];
                }
            }
            file_put_contents($project . '/docs/testing/backup-restore-differences.json', json_encode($differences, JSON_PRETTY_PRINT));
            throw new RuntimeException('Restored table schema or data differs from the backup manifest; see comparison report');
        }
        $restoredApi = $backup . '/restore-check/private-api';
        backupCopy($backup . '/private-api/.env', $restoredApi . '/.env');
        backupCopy($backup . '/private-api/.qr-secret', $restoredApi . '/.qr-secret');
        $key = trim(file_get_contents($restoredApi . '/.qr-secret'));
        if (!hash_equals($manifest['files']['private-api/.qr-secret'], hash_file('sha256', $restoredApi . '/.qr-secret'))
            || strlen($key) < 32 || hash_equals(hash('sha256', 'smartflow-qr-v1-urbiztondo'), $key)) throw new RuntimeException('Restored signing key was not preserved');
        $_ENV['QR_SIGNING_SECRET'] = $key;
        require_once $project . '/backend/backend/api/qr-token-helper.php';
        $qrApplicable = ($manifest['continuity_qr'] ?? null) !== null;
        $qr = null;
        if ($qrApplicable) {
            $qr = smartflow_qr_verify((string)($manifest['continuity_qr']['qr_payload'] ?? $manifest['continuity_qr']['payload'] ?? ''));
            if (empty($qr['valid']) && ($qr['reason'] ?? '') !== 'expired') throw new RuntimeException('Restored key cannot verify the original snapshot QR');
            $read = $restored->prepare('SELECT COUNT(*) FROM documents WHERE id=?'); $read->execute([$qr['document_id']]);
            if (!$read->fetchColumn()) throw new RuntimeException('Snapshot QR refers to a missing restored document');
        } elseif (($restoredTables['documents']['rows'] ?? null) !== 0) {
            throw new RuntimeException('A populated snapshot requires an original folder QR');
        }
        $uploadCount = 0;
        foreach ($manifest['files'] as $relative => $hash) if (str_starts_with($relative, 'private-api/uploads/')) {
            backupCopy($backup . '/' . $relative, $backup . '/restore-check/' . $relative);
            if (!hash_equals($hash, hash_file('sha256', $backup . '/restore-check/' . $relative))) throw new RuntimeException('Restored upload differs');
            $uploadCount++;
        }
        $result = ['at' => date('c'), 'snapshot' => basename($backup), 'passed' => true, 'isolated_database' => true,
            'tables_verified' => count($restoredTables), 'rows_verified' => array_sum(array_column($restoredTables, 'rows')), 'users_verified' => isset($restoredTables['users']),
            'documents_verified' => isset($restoredTables['documents']), 'signing_key_preserved' => true, 'original_qr_applicable' => $qrApplicable,
            'original_qr_signature_verified' => $qrApplicable ? true : null, 'original_qr_currently_valid' => $qrApplicable ? (bool)$qr['valid'] : null,
            'uploaded_files_verified' => $uploadCount, 'live_database_restored' => false];
        if (!$qrApplicable) echo 'Original folder QR: not applicable (snapshot contains no folders); signing key preserved.' . PHP_EOL;
        echo 'Isolated restore verified: ' . count($restoredTables) . ' tables, users, documents, QR key, and uploaded files.' . PHP_EOL;
    }
} catch (Throwable $error) {
    fwrite(STDERR, 'System backup/verification failed: ' . $error->getMessage() . PHP_EOL); $failed = true;
} finally {
    if ($qaCreated && $qaDatabase !== null && isset($server)) {
        $restored = null; $server->exec('DROP DATABASE IF EXISTS `' . $qaDatabase . '`');
        if (isset($result)) $result['temporary_database_removed'] = true;
        echo 'Owned temporary restore database removed.' . PHP_EOL;
    }
    if (isset($restoredApi) && is_dir($backup . '/restore-check')) {
        $checkRoot = realpath($backup . '/restore-check');
        if ($checkRoot && str_starts_with(strtolower($checkRoot), strtolower(realpath($backupRoot)) . DIRECTORY_SEPARATOR)) {
            foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($checkRoot, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::CHILD_FIRST) as $entry) {
                if ($entry->isDir()) rmdir($entry->getPathname()); else unlink($entry->getPathname());
            }
            rmdir($checkRoot);
        }
    }
    if (isset($result)) file_put_contents($project . '/docs/testing/backup-restore-results.json', json_encode($result, JSON_PRETTY_PRINT));
}
exit(!empty($failed) ? 1 : 0);
