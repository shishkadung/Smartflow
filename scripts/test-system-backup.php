<?php
// Actual dump/restore checks using owned disposable databases and synthetic private files only.
// Run: C:\xampp\php\php.exe scripts\test-system-backup.php
declare(strict_types=1);

$fixture = sys_get_temp_dir() . '/smartflow-backup-test-' . bin2hex(random_bytes(16));
$project = $fixture . '/project';
$api = $fixture . '/private-api';
$sourceDatabase = 'smartflow_request_test_' . bin2hex(random_bytes(6));
$marker = bin2hex(random_bytes(16));
$sourceCreated = false;
$checks = 0;
$check = static function (bool $passed, string $message) use (&$checks): void {
    if (!$passed) throw new RuntimeException($message);
    $checks++;
    echo "PASS $message\n";
};
$run = static function (array $command, ?callable $whilePaused = null, string $stage = '') use ($fixture): array {
    $ready = $fixture . '/backup-ready';
    $release = $fixture . '/backup-release';
    foreach ([$ready, $release] as $barrier) if (is_file($barrier)) unlink($barrier);
    $environment = array_merge(getenv(), ['BACKUP_TEST_STAGE' => $stage, 'BACKUP_TEST_READY' => $ready, 'BACKUP_TEST_RELEASE' => $release]);
    $process = proc_open($command, [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, null, $environment);
    if (!is_resource($process)) throw new RuntimeException('Could not start synthetic backup check');
    fclose($pipes[0]);
    try {
        if ($whilePaused !== null) {
            $until = microtime(true) + 20;
            while (!is_file($ready)) {
                if (microtime(true) > $until) throw new RuntimeException('Synthetic backup scheduling barrier timed out');
                usleep(10000);
            }
            $whilePaused();
        }
    } catch (Throwable $error) {
        proc_terminate($process);
        fclose($pipes[1]); fclose($pipes[2]); proc_close($process);
        throw $error;
    } finally { if ($whilePaused !== null) file_put_contents($release, 'continue'); }
    $stdout = stream_get_contents($pipes[1]); fclose($pipes[1]);
    $stderr = stream_get_contents($pipes[2]); fclose($pipes[2]);
    return [proc_close($process), $stdout, $stderr];
};
$schemas = static function (PDO $connection): array {
    return $connection->query("SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME LIKE 'smartflow_restore_qa_%' ORDER BY SCHEMA_NAME")->fetchAll(PDO::FETCH_COLUMN);
};
$host = getenv('TEST_DB_HOST') ?: '127.0.0.1';
$user = getenv('TEST_DB_USER') ?: 'root';
$password = getenv('TEST_DB_PASS') ?: '';
$server = new PDO('mysql:host=' . $host . ';charset=utf8mb4', $user, $password,
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$existingQa = $schemas($server);

try {
    foreach ([$api . '/uploads/avatars', $api . '/uploads/nested', $project . '/scripts',
        $project . '/docs/testing', $project . '/backend/backend/api'] as $directory) mkdir($directory, 0700, true);
    $original = (string)file_get_contents(__DIR__ . '/backup-system.php');
    $projectLine = '$project = dirname(__DIR__);';
    $apiLine = '$api = \'C:/xampp/htdocs/Smartflow/backend/backend/api\';';
    $check(substr_count($original, $projectLine) === 1 && substr_count($original, $apiLine) === 1,
        'fixture redirects only the known project and API paths');
    $copy = str_replace([$projectLine, $apiLine], ['$project = ' . var_export($project, true) . ';',
        '$api = ' . var_export($api, true) . ';'], $original);
    // Scheduling only: run the actual copied dump/import/fingerprint logic unchanged.
    $pause = <<<'PHP'
        if (getenv('BACKUP_TEST_STAGE') === '%s') {
            file_put_contents(getenv('BACKUP_TEST_READY'), 'ready');
            $until = microtime(true) + 20;
            while (!is_file(getenv('BACKUP_TEST_RELEASE'))) {
                if (microtime(true) > $until) throw new RuntimeException('Synthetic backup release timed out');
                usleep(10000);
            }
        }

PHP;
    foreach (["        runBackupMysql('mysqldump'," => 'before_dump',
        '        $restored = restoreBackupSnapshot($backup, $defaults);' => 'after_dump'] as $anchor => $stage) {
        $check(substr_count($copy, $anchor) === 1, "$stage scheduling anchor matches copied source");
        $copy = str_replace($anchor, sprintf($pause, $stage) . $anchor, $copy);
    }
    $script = $project . '/scripts/backup-system.php';
    file_put_contents($script, $copy);
    copy(__DIR__ . '/verify-system-backup.ps1', $project . '/scripts/verify-system-backup.ps1');
    copy(__DIR__ . '/../backend/backend/api/qr-token-helper.php', $project . '/backend/backend/api/qr-token-helper.php');
    $check(preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', $sourceDatabase) === 1,
        'source database has the exact disposable harness prefix');
    $server->exec("CREATE DATABASE `$sourceDatabase` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $sourceCreated = true;
    $source = new PDO("mysql:host=$host;dbname=$sourceDatabase;charset=utf8mb4", $user, $password,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $source->exec('CREATE TABLE users (id INT PRIMARY KEY AUTO_INCREMENT, username VARCHAR(50), name VARCHAR(100)) ENGINE=InnoDB');
    $source->exec('CREATE TABLE documents (id VARCHAR(50) PRIMARY KEY, title VARCHAR(150), notes LONGTEXT, sample LONGBLOB, optional_note VARCHAR(100) NULL) ENGINE=InnoDB');
    $source->exec('CREATE TABLE backup_test_owner (id INT PRIMARY KEY, marker VARCHAR(64)) ENGINE=InnoDB');
    $source->exec("INSERT INTO users (username, name) VALUES ('synthetic-backup', 'Synthetic backup user')");
    $source->prepare('INSERT INTO documents VALUES (?, ?, ?, ?, ?)')->execute(['DOC-2001-000001',
        'Synthetic café folder', "Synthetic quote ' and line\nTwo", "\x00\x01\xFFsynthetic binary", null]);
    $source->prepare('INSERT INTO backup_test_owner VALUES (1, ?)')->execute([$marker]);
    $fileKey = bin2hex(random_bytes(32));
    $envKey = bin2hex(random_bytes(32));
    file_put_contents($api . '/.qr-secret', $fileKey);
    file_put_contents($api . '/uploads/avatars/sample.bin', "Synthetic avatar\x00\xFE");
    file_put_contents($api . '/uploads/nested/attachment.txt', "Synthetic attachment\nNo operational records\n");
    $environment = "DB_HOST=$host\nDB_NAME=$sourceDatabase\nDB_USER=$user\nDB_PASS=$password\nAPP_TIMEZONE=Asia/Manila\n";
    $defaultRoot = $project . '/backups';
    $customRoot = $fixture . '/custom backups';
    $snapshots = [];
    foreach (['default' => $defaultRoot, 'custom' => $customRoot] as $kind => $root) {
        $settings = $environment . ($kind === 'custom' ? "QR_SIGNING_SECRET=$envKey\n" : '');
        file_put_contents($api . '/.env', $settings);
        $command = [PHP_BINARY, $script, 'backup'];
        if ($kind === 'custom') $command[] = $root;
        [$exit, $stdout, $stderr] = $run($command);
        $check($exit === 0 && str_contains($stdout, 'Private system backup created:'), "$kind root creates an actual database/files snapshot");
        $matches = glob($root . '/smartflow-system-*', GLOB_ONLYDIR);
        $check(count($matches) === 1, "$kind root contains exactly its new owned snapshot");
        $snapshot = $snapshots[$kind] = $matches[0];
        $manifest = json_decode(file_get_contents($snapshot . '/manifest.json'), true, 512, JSON_THROW_ON_ERROR);
        $check($manifest['format'] === 2 && $manifest['source_database'] === $sourceDatabase
            && count($manifest['tables']) === 3 && array_sum(array_column($manifest['tables'], 'rows')) === 3,
            "$kind manifest records the actual three synthetic tables and rows");
        $check(file_get_contents($snapshot . '/private-api/.env') === $settings
            && file_get_contents($snapshot . '/private-api/.qr-secret') === ($kind === 'custom' ? $envKey : $fileKey),
            "$kind snapshot preserves synthetic settings and the effective stable signing key");
        foreach (['avatars/sample.bin', 'nested/attachment.txt'] as $relative) {
            $check(hash_file('sha256', $api . '/uploads/' . $relative) === hash_file('sha256', $snapshot . '/private-api/uploads/' . $relative),
                "$kind snapshot preserves nested synthetic upload $relative");
        }
        $verify = [PHP_BINARY, $script, 'verify', $snapshot];
        if ($kind === 'custom') $verify[] = $root;
        [$exit, $stdout, $stderr] = $run($verify);
        $check($exit === 0 && str_contains($stdout, 'Isolated restore verified:'), "$kind snapshot verifies through an actual isolated restore");
        $result = json_decode(file_get_contents($project . '/docs/testing/backup-restore-results.json'), true, 512, JSON_THROW_ON_ERROR);
        $check($result['passed'] && $result['isolated_database'] && !$result['live_database_restored']
            && $result['tables_verified'] === 3 && $result['rows_verified'] === 3 && $result['users_verified'] && $result['documents_verified']
            && $result['signing_key_preserved'] && $result['original_qr_applicable'] && $result['original_qr_signature_verified'] && $result['original_qr_currently_valid']
            && $result['uploaded_files_verified'] === 2 && $result['temporary_database_removed'],
            "$kind restore verifies database data/schema, original QR, signing key and uploads");
        $check(!file_exists($snapshot . '/restore-check') && glob($root . '/.client-*.cnf') === []
            && $schemas($server) === $existingQa, "$kind verification removes restored private files, tool credentials and temporary databases");
        [$exit] = $run($verify);
        $check($exit === 0, "$kind snapshot can be verified again after cleanup");
    }
    $snapshot = $snapshots['default'];
    foreach ([$defaultRoot, $customRoot, $fixture . '/outside'] as $directory) if (!is_dir($directory)) mkdir($directory, 0700, true);
    $siblingRoot = $project . '/backups-sibling';
    mkdir($siblingRoot);
    foreach (['allowed root itself' => [$defaultRoot, $defaultRoot], 'outside path' => [$fixture . '/outside', $defaultRoot],
        'sibling with matching prefix' => [$siblingRoot, $defaultRoot], 'custom snapshot under the wrong root' => [$snapshots['custom'], $defaultRoot],
        'snapshot as its own root' => [$snapshot, $snapshot], 'missing snapshot' => [$fixture . '/missing', $defaultRoot],
        'missing allowed root' => [$snapshot, $fixture . '/missing-root']] as $case => [$candidate, $allowed]) {
        [$exit, $stdout, $stderr] = $run([PHP_BINARY, $script, 'verify', $candidate, $allowed]);
        $check($exit !== 0 && str_contains($stderr, 'Choose a system snapshot inside project backups'),
            "verification rejects $case");
    }
    $check(!file_exists($snapshot . '/.htaccess') && !file_exists($snapshot . '/restore-check'),
        'rejected snapshot-as-root verification leaves the snapshot unchanged');
    $check(!file_exists($fixture . '/missing-root'), 'verification does not create a missing allowed backup root');
    $upload = $snapshot . '/private-api/uploads/nested/attachment.txt';
    $originalUpload = file_get_contents($upload);
    file_put_contents($upload, 'Synthetic tampering');
    [$exit, $stdout, $stderr] = $run([PHP_BINARY, $script, 'verify', $snapshot]);
    $check($exit !== 0 && str_contains($stderr, 'Backup integrity check failed'), 'changed private upload fails manifest integrity before restore');
    file_put_contents($upload, $originalUpload);
    $manifestPath = $snapshot . '/manifest.json';
    $manifestText = file_get_contents($manifestPath);
    $manifest = json_decode($manifestText, true, 512, JSON_THROW_ON_ERROR);
    $databaseDump = file_get_contents($snapshot . '/database.sql');
    file_put_contents($snapshot . '/database.sql', $databaseDump . "\nUSE synthetic_forbidden_switch;\n");
    $manifest['files']['database.sql'] = hash_file('sha256', $snapshot . '/database.sql');
    file_put_contents($manifestPath, json_encode($manifest, JSON_THROW_ON_ERROR));
    [$exit, $stdout, $stderr] = $run([PHP_BINARY, $script, 'verify', $snapshot]);
    $check($exit !== 0 && str_contains($stderr, 'must not switch or manage databases'),
        'manifest-consistent SQL cannot switch outside the owned restore database' . ($exit !== 0 && !str_contains($stderr, 'must not switch or manage databases') ? ': ' . trim($stderr) : ''));
    file_put_contents($snapshot . '/database.sql', $databaseDump);
    file_put_contents($manifestPath, $manifestText);
    file_put_contents($snapshot . '/private-api/.qr-secret', bin2hex(random_bytes(32)));
    $manifest['files']['database.sql'] = hash_file('sha256', $snapshot . '/database.sql');
    $manifest['files']['private-api/.qr-secret'] = hash_file('sha256', $snapshot . '/private-api/.qr-secret');
    file_put_contents($manifestPath, json_encode($manifest, JSON_THROW_ON_ERROR));
    [$exit, $stdout, $stderr] = $run([PHP_BINARY, $script, 'verify', $snapshot]);
    $check($exit !== 0 && str_contains($stderr, 'Restored key cannot verify'), 'an incorrect restored key fails original QR continuity after database restore');
    $check(!file_exists($snapshot . '/restore-check') && glob($defaultRoot . '/.client-*.cnf') === []
        && $schemas($server) === $existingQa, 'failed QR verification also removes restored private files, credentials and owned databases');
    file_put_contents($snapshot . '/private-api/.qr-secret', $fileKey);
    file_put_contents($manifestPath, $manifestText);
    $manifest = json_decode($manifestText, true, 512, JSON_THROW_ON_ERROR);
    $manifest['continuity_qr'] = null;
    file_put_contents($manifestPath, json_encode($manifest, JSON_THROW_ON_ERROR));
    [$exit, $stdout, $stderr] = $run([PHP_BINARY, $script, 'verify', $snapshot]);
    $check($exit !== 0 && str_contains($stderr, 'A populated snapshot requires an original folder QR'),
        'populated snapshots cannot bypass original QR continuity by declaring it not applicable');
    $check(!file_exists($snapshot . '/restore-check') && glob($defaultRoot . '/.client-*.cnf') === []
        && $schemas($server) === $existingQa, 'rejected populated QR N/A check cleans all owned restore material');
    file_put_contents($manifestPath, $manifestText);

    // Execute only the copied wrapper, whose neighboring PHP script is redirected above.
    $powershell = 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe';
    foreach (['default' => $defaultRoot, 'custom' => $customRoot] as $kind => $root) {
        $wrapper = [$powershell, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File',
            $project . '/scripts/verify-system-backup.ps1', '-Snapshot', $snapshots[$kind], '-Php', PHP_BINARY];
        if ($kind === 'custom') array_push($wrapper, '-BackupRoot', $root);
        [$exit, $stdout, $stderr] = $run($wrapper);
        $check($exit === 0 && str_contains($stdout, 'Isolated restore verified:'), "copied PowerShell wrapper verifies $kind root without touching the operational script");
    }
    $check(file_get_contents($api . '/.qr-secret') === $fileKey
        && $source->query('SELECT marker FROM backup_test_owner WHERE id = 1')->fetchColumn() === $marker
        && (int)$source->query('SELECT COUNT(*) FROM documents')->fetchColumn() === 1,
        'backup verification preserves its synthetic source database and private source key');
    $check($schemas($server) === $existingQa, 'all successful and failed restore checks leave no new restore schema');

    file_put_contents($api . '/.env', $environment);
    foreach (['before_dump', 'after_dump'] as $stage) {
        $root = $fixture . '/' . $stage . ' backups';
        $writer = static function () use ($source, $stage): void {
            $source->beginTransaction();
            if ($stage === 'before_dump') $source->exec("UPDATE documents SET title='Committed overlapping write' WHERE id='DOC-2001-000001'");
            else $source->exec('DELETE FROM documents');
            $source->commit();
        };
        [$exit, $stdout, $stderr] = $run([PHP_BINARY, $script, 'backup', $root], $writer, $stage);
        $check($exit === 0 && str_contains($stdout, 'Private system backup created:'), "$stage overlapping source write completes during a successful backup");
        $matches = glob($root . '/smartflow-system-*', GLOB_ONLYDIR);
        $check(count($matches) === 1, "$stage creates exactly one snapshot");
        $manifest = json_decode(file_get_contents($matches[0] . '/manifest.json'), true, 512, JSON_THROW_ON_ERROR);
        $check($manifest['tables']['documents']['rows'] === 1 && $manifest['continuity_qr']['document_id'] === 'DOC-2001-000001',
            "$stage manifest and continuity QR describe the dumped folder, including after source deletion");
        $dump = file_get_contents($matches[0] . '/database.sql');
        $check(str_contains($dump, 'Committed overlapping write'), "$stage SQL contains the committed title captured by the dump");
        [$exit, $stdout, $stderr] = $run([PHP_BINARY, $script, 'verify', $matches[0], $root]);
        $check($exit === 0 && str_contains($stdout, 'Isolated restore verified:'), "$stage actual isolated restore matches the snapshot manifest");
        $check(!file_exists($matches[0] . '/restore-check') && glob($root . '/.client-*.cnf') === []
            && $schemas($server) === $existingQa, "$stage backup and verification clean owned databases, private copies and credentials");
    }
    $check((int)$source->query('SELECT COUNT(*) FROM documents')->fetchColumn() === 0
        && $source->query('SELECT marker FROM backup_test_owner WHERE id=1')->fetchColumn() === $marker,
        'backup and verification preserve overlapping source deletion and its ownership marker');

    $emptyRoot = $fixture . '/empty backups';
    [$exit, $stdout, $stderr] = $run([PHP_BINARY, $script, 'backup', $emptyRoot]);
    $check($exit === 0, 'an initialized system with users and no folders backs up successfully');
    $matches = glob($emptyRoot . '/smartflow-system-*', GLOB_ONLYDIR);
    $check(count($matches) === 1, 'empty-folder backup creates exactly one snapshot');
    $emptySnapshot = $matches[0];
    $emptyManifest = json_decode(file_get_contents($emptySnapshot . '/manifest.json'), true, 512, JSON_THROW_ON_ERROR);
    $check($emptyManifest['continuity_qr'] === null && $emptyManifest['tables']['documents']['rows'] === 0,
        'empty-folder snapshot records zero folders and no fabricated continuity QR');
    [$exit, $stdout, $stderr] = $run([PHP_BINARY, $script, 'verify', $emptySnapshot, $emptyRoot]);
    $check($exit === 0 && str_contains($stdout, 'Original folder QR: not applicable'), 'empty-folder actual restore passes with an explicit original-QR N/A result');
    $result = json_decode(file_get_contents($project . '/docs/testing/backup-restore-results.json'), true, 512, JSON_THROW_ON_ERROR);
    $check($result['passed'] && $result['tables_verified'] === 3 && $result['rows_verified'] === 2
        && $result['users_verified'] && $result['documents_verified'] && $result['signing_key_preserved']
        && $result['original_qr_applicable'] === false && $result['original_qr_signature_verified'] === null
        && $result['original_qr_currently_valid'] === null && $result['uploaded_files_verified'] === 2
        && $result['temporary_database_removed'] && !$result['live_database_restored'],
        'empty-folder result verifies data/schema, existing signing-key bytes and uploads without claiming an original QR check');
    [$exit] = $run([PHP_BINARY, $script, 'verify', $emptySnapshot, $emptyRoot]);
    $check($exit === 0 && !file_exists($emptySnapshot . '/restore-check') && glob($emptyRoot . '/.client-*.cnf') === []
        && $schemas($server) === $existingQa, 'empty-folder snapshot verifies repeatedly and leaves no temporary restore material');
    file_put_contents($emptySnapshot . '/private-api/.qr-secret', 'weak');
    $emptyManifest['files']['private-api/.qr-secret'] = hash_file('sha256', $emptySnapshot . '/private-api/.qr-secret');
    file_put_contents($emptySnapshot . '/manifest.json', json_encode($emptyManifest, JSON_THROW_ON_ERROR));
    [$exit, $stdout, $stderr] = $run([PHP_BINARY, $script, 'verify', $emptySnapshot, $emptyRoot]);
    $check($exit !== 0 && str_contains($stderr, 'Restored signing key was not preserved'), 'empty-folder N/A does not bypass strong signing-key checks');
    $check(!file_exists($emptySnapshot . '/restore-check') && glob($emptyRoot . '/.client-*.cnf') === []
        && $schemas($server) === $existingQa && (int)$source->query('SELECT COUNT(*) FROM documents')->fetchColumn() === 0
        && file_get_contents($api . '/.qr-secret') === $fileKey, 'failed empty-folder key check cleans up and leaves source folders/key unchanged');
} finally {
    $source = null;
    if ($sourceCreated && preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', $sourceDatabase)) {
        $server->exec("DROP DATABASE IF EXISTS `$sourceDatabase`");
    }
    // A failed child may only be cleaned if its unique copied marker proves ownership.
    foreach (array_diff($schemas($server), $existingQa) as $qa) {
        if (!preg_match('/^smartflow_restore_qa_[a-f0-9]{16}$/D', $qa)) continue;
        try { $owned = $server->query("SELECT marker FROM `$qa`.backup_test_owner WHERE id = 1")->fetchColumn() === $marker; }
        catch (PDOException) { $owned = false; }
        if ($owned) $server->exec("DROP DATABASE `$qa`");
    }
    $resolved = realpath($fixture);
    $temporary = realpath(sys_get_temp_dir());
    if ($resolved !== false && $temporary !== false
        && str_starts_with(strtolower($resolved), strtolower($temporary) . DIRECTORY_SEPARATOR)
        && preg_match('/^smartflow-backup-test-[a-f0-9]{32}$/D', basename($resolved))) {
        foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($resolved, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::CHILD_FIRST) as $entry) {
            if ($entry->isDir() && !$entry->isLink()) rmdir($entry->getPathname()); else unlink($entry->getPathname());
        }
        rmdir($resolved);
    }
}
$read = $server->prepare('SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = ?');
$read->execute([$sourceDatabase]);
$check((int)$read->fetchColumn() === 0 && !file_exists($fixture), 'synthetic private fixture and source database are removed');
echo "$checks system backup/restore checks passed\n";
