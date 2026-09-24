<?php
// GET /dev-api-health.php — quick smoke test (local demo only).

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$checks = [];
$failed = 0;

$ping = static function (string $name, callable $fn) use (&$checks, &$failed): void {
    try {
        $fn();
        $checks[] = ['name' => $name, 'ok' => true];
    } catch (Throwable $e) {
        $failed++;
        $checks[] = [
            'name' => $name,
            'ok' => false,
            'error' => $e->getMessage(),
        ];
    }
};

$ping('database', static function () use ($pdo): void {
    $pdo->query('SELECT 1');
});

$ping('offices', static function () use ($pdo): void {
    $n = (int)$pdo->query('SELECT COUNT(*) FROM offices')->fetchColumn();
    if ($n < 1) {
        throw new RuntimeException('No offices seeded');
    }
});

$ping('signup_requests_table', static function () use ($pdo): void {
    $pdo->query('SELECT 1 FROM signup_requests LIMIT 1');
});

$ping('document_requests_table', static function () use ($pdo): void {
    $pdo->query('SELECT 1 FROM document_requests LIMIT 1');
});

$ping('documents_columns', static function () use ($pdo): void {
    $pdo->query('SELECT id, created_by, due_at, date_registered FROM documents LIMIT 1');
});

$token = null;
$officeId = 1;
$userId = 1;

$ping('login', static function () use ($pdo, &$token, &$officeId, &$userId): void {
    $stmt = $pdo->prepare('SELECT id, office_id, password_hash FROM users WHERE username = :u LIMIT 1');
    $stmt->execute([':u' => 'engineering.staff']);
    $row = $stmt->fetch();
    if (!$row || !password_verify('smartflow123', $row['password_hash'])) {
        throw new RuntimeException('engineering.staff not seeded or wrong password');
    }
    $userId = (int)$row['id'];
    $officeId = (int)$row['office_id'];
    $token = base64_encode($userId . '|' . bin2hex(random_bytes(8)));
});

$ping('document_requests_summary_endpoint', static function (): void {
    $path = __DIR__ . '/document-requests-summary.php';
    if (!is_file($path)) {
        throw new RuntimeException('document-requests-summary.php missing — run sync-backend-to-xampp.ps1');
    }
});

$ping('head_dashboard_sql', static function () use ($pdo, $officeId): void {
    $stmt = $pdo->prepare('
        SELECT COUNT(*) AS c FROM documents d
        JOIN (
            SELECT m.document_id, m.status, m.office_id
            FROM movements m
            WHERE m.id = (
                SELECT m2.id FROM movements m2
                WHERE m2.document_id = m.document_id
                ORDER BY m2.scanned_at DESC, m2.id DESC LIMIT 1
            )
        ) latest ON latest.document_id = d.id
        WHERE (latest.status = \'IN\' AND latest.office_id = :oid_in)
           OR (latest.status = \'OUT\' AND latest.office_id = :oid_out)
    ');
    $stmt->execute([':oid_in' => $officeId, ':oid_out' => $officeId]);
    $stmt->fetch();
});

json_response([
    'success' => $failed === 0,
    'message' => $failed === 0
        ? 'All health checks passed'
        : "$failed check(s) failed",
    'failed' => $failed,
    'checks' => $checks,
], $failed === 0 ? 200 : 500);
