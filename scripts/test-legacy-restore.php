<?php
// Restore only copied scripts into an owned synthetic schema, in both Windows shells.
declare(strict_types=1);

$host = getenv('TEST_DB_HOST') ?: '127.0.0.1';
$user = getenv('TEST_DB_USER') ?: 'root';
$password = getenv('TEST_DB_PASS') ?: '';
$database = 'smartflow_request_test_' . bin2hex(random_bytes(6));
$marker = bin2hex(random_bytes(16));
$fixture = sys_get_temp_dir() . '/smartflow-legacy-restore-' . bin2hex(random_bytes(16));
$server = new PDO("mysql:host=$host;charset=utf8mb4", $user, $password, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$created = false;
$checks = 0;
$check = static function (bool $passed, string $message) use (&$checks): void {
    if (!$passed) throw new RuntimeException($message);
    $checks++;
    echo "PASS $message\n";
};
$run = static function (array $command): array {
    $process = proc_open($command, [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
    if (!is_resource($process)) throw new RuntimeException('Could not start copied restore check');
    fclose($pipes[0]);
    $stdout = stream_get_contents($pipes[1]); fclose($pipes[1]);
    $stderr = stream_get_contents($pipes[2]); fclose($pipes[2]);
    return [proc_close($process), $stdout, $stderr];
};

try {
    $check(preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', $database) === 1, 'restore target uses the disposable schema prefix');
    $server->exec("CREATE DATABASE `$database` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $created = true;
    $source = new PDO("mysql:host=$host;dbname=$database;charset=utf8mb4", $user, $password, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $source->exec('CREATE TABLE restore_test_owner (marker VARCHAR(64)) ENGINE=InnoDB');
    $source->prepare('INSERT INTO restore_test_owner VALUES (?)')->execute([$marker]);
    mkdir($fixture, 0700, true);
    $script = (string)file_get_contents(__DIR__ . '/restore-database.ps1');
    $check(substr_count($script, '$DbName = "smartflow"') === 1 && substr_count($script, '$DbHost = "localhost"') === 1
        && substr_count($script, '$DbUser = "root"') === 1 && substr_count($script, '$DbPass = ""') === 1,
        'fixture redirects only known database connection literals in its copied script');
    $literal = static fn(string $value): string => "'" . str_replace("'", "''", $value) . "'";
    $script = str_replace(['$DbName = "smartflow"', '$DbHost = "localhost"', '$DbUser = "root"', '$DbPass = ""'],
        ['$DbName = ' . $literal($database), '$DbHost = ' . $literal($host), '$DbUser = ' . $literal($user), '$DbPass = ' . $literal($password)], $script);
    file_put_contents($fixture . '/restore-database.ps1', $script);
    $title = "Synthetic café, piñata, ₱ and 🗂";
    $notes = "Synthetic quote ' and line\nTwo";
    $binary = "\x00\x01\xFFsynthetic binary";
    $sql = "SET NAMES utf8mb4;\nDROP TABLE IF EXISTS restored_sample;\n"
        . "CREATE TABLE restored_sample (id INT PRIMARY KEY, title TEXT, notes LONGTEXT, sample LONGBLOB) ENGINE=InnoDB;\n"
        . 'INSERT INTO restored_sample VALUES (1, ' . $source->quote($title) . ', ' . $source->quote($notes)
        . ', UNHEX(' . $source->quote(bin2hex($binary)) . "));\n";
    foreach (['powershell.exe', 'pwsh.exe'] as $shell) {
        foreach (['utf8' => '', 'utf8-bom' => "\xEF\xBB\xBF"] as $encoding => $preamble) {
            $dump = $fixture . "/$encoding.sql";
            file_put_contents($dump, $preamble . $sql);
            $source->exec('DROP TABLE IF EXISTS restored_sample');
            file_put_contents($fixture . '/driver.ps1', "function Read-Host { 'YES' }\n& (Join-Path \$PSScriptRoot 'restore-database.ps1') -BackupFile " . $literal($dump) . "\nif (-not \$?) { exit 1 }\n");
            [$exit, $stdout, $stderr] = $run([$shell, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $fixture . '/driver.ps1']);
            $check($exit === 0 && str_contains($stdout, 'Restore completed successfully!'), "$shell restores a $encoding synthetic SQL file successfully" . ($exit !== 0 || !str_contains($stdout, 'Restore completed successfully!') ? ': exit ' . $exit . ' ' . trim($stdout . ' ' . $stderr) : ''));
            $row = $source->query('SELECT title, notes, sample FROM restored_sample')->fetch(PDO::FETCH_ASSOC);
            $check($row['title'] === $title && $row['notes'] === $notes && $row['sample'] === $binary,
                "$shell $encoding restore preserves Unicode, multiline notes and binary values");
            $check($source->query('SELECT marker FROM restore_test_owner')->fetchColumn() === $marker,
                "$shell $encoding import stays inside the marked synthetic schema");
        }
        file_put_contents($fixture . '/invalid.sql', "SYNTHETIC INVALID SQL;\n");
        file_put_contents($fixture . '/driver.ps1', "function Read-Host { 'YES' }\n& (Join-Path \$PSScriptRoot 'restore-database.ps1') -BackupFile " . $literal($fixture . '/invalid.sql') . "\nif (-not \$?) { exit 1 }\n");
        [$exit, $stdout] = $run([$shell, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $fixture . '/driver.ps1']);
        $check($exit !== 0 && str_contains($stdout, 'Restore failed'), "$shell propagates an actual SQL import failure");
    }
    echo "Legacy restore checks passed: $checks\n";
} finally {
    if ($created) {
        if (($source ?? null)?->query('SELECT marker FROM restore_test_owner')->fetchColumn() !== $marker) {
            throw new RuntimeException('Cleanup stopped: synthetic schema ownership marker changed');
        }
        $server->exec("DROP DATABASE `$database`");
        $statement = $server->prepare('SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = ?');
        $statement->execute([$database]);
        if ((int)$statement->fetchColumn() !== 0) throw new RuntimeException('Synthetic restore schema was not removed');
        echo "Cleanup: marked synthetic schema removed\n";
    }
    // Only these explicitly named files inside the newly generated fixture may be removed.
    foreach (['restore-database.ps1', 'driver.ps1', 'utf8.sql', 'utf8-bom.sql', 'invalid.sql'] as $name) {
        if (file_exists($fixture . '/' . $name)) unlink($fixture . '/' . $name);
    }
    if (is_dir($fixture)) rmdir($fixture);
}
