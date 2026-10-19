<?php
// Consistent JSON/CSV/print reads while a synthetic registration commits.
declare(strict_types=1);
require __DIR__ . '/stabilization-test-helper.php';
date_default_timezone_set('Asia/Manila');
$fixture = new SmartflowStabilizationFixture(static function (string $name, string $source): string {
    if ($name !== 'reports-summary.php') return $source;
    $anchor = '$totalDocs = (int)($stmtTotal->fetch()[\'c\'] ?? 0);';
    if (substr_count($source, $anchor) !== 1) throw new RuntimeException('Report scheduling anchor changed');
    $barrier = <<<'PHP'

// Test-only scheduling; query and classification logic remain unchanged.
if (is_file(__DIR__ . '/pause-report')) {
    file_put_contents(__DIR__ . '/report-ready', 'ready');
    $until = microtime(true) + 20;
    while (!is_file(__DIR__ . '/report-release')) {
        if (microtime(true) > $until) throw new RuntimeException('Report test barrier timed out');
        usleep(10000);
    }
}
PHP;
    return str_replace($anchor, $anchor . $barrier, $source);
});
$pending = null;
try {
    $fixture->user(101, 'accounting_admin', 4, 'admin');
    $fixture->user(102, 'engineering_admin', 1, 'admin');
    $fixture->user(103, 'accounting_staff', 4);
    $fixture->startServers();
    $admin = $fixture->login('accounting_admin');
    $otherAdmin = $fixture->login('engineering_admin');
    $staff = $fixture->login('accounting_staff');
    $db = $fixture->db;
    $periodDate = new DateTimeImmutable('first day of previous month 12:00:00');
    $query = ['office_id' => 4, 'month' => $periodDate->format('Y-m')];
    $folder = static function (int $number) use ($db, $periodDate): void {
        $id = 'DOC-2001-' . str_pad((string)$number, 6, '0', STR_PAD_LEFT);
        $db->beginTransaction();
        $db->prepare('INSERT INTO documents(id,title,type,origin_office_id,created_by) VALUES (?,"Synthetic report folder","Others: Snapshot test",4,101)')->execute([$id]);
        $db->prepare('INSERT INTO movements(document_id,office_id,status,user_id,scanned_at) VALUES (?,4,"IN",101,?)')->execute([$id, $periodDate->format('Y-m-d H:i:s')]);
        $db->commit();
    };
    $request = static fn(string $format, array $period = []): string => 'reports-summary.php?' . http_build_query(array_replace($query, ['format' => $format], $period));
    $coherent = static function (array $report, int $count): bool {
        $acc = array_values(array_filter($report['office_totals'], static fn(array $office): bool => $office['office_code'] === 'ACC'));
        return $report['totals']['documents_in_period'] === $count && $report['totals']['this_office_documents'] === $count
            && $report['compliance']['on_time']['count'] === $count && $report['compliance']['on_time']['percent'] === ($count ? 100 : 0)
            && array_sum(array_column($report['compliance'], 'count')) === $count
            && array_sum(array_column($report['compliance'], 'percent')) === ($count ? 100 : 0)
            && count($acc) === 1 && $acc[0]['docs_processed'] === $count;
    };
    $fixture->check($fixture->call($request('json'), $staff)[0] === 403, 'staff cannot obtain municipal summaries');
    $fixture->check($fixture->call($request('csv'), $otherAdmin)[0] === 403 && $fixture->call($request('print'), $otherAdmin)[0] === 403,
        'non-Accounting administrators cannot export CSV or print summaries');
    [$status, $empty] = $fixture->call($request('json'), $admin);
    $fixture->check($status === 200 && $coherent($empty, 0), 'empty summary has coherent zero counts and percentages');
    $folder(1);
    foreach (['month', 'quarter', 'year'] as $period) {
        [$status, $report] = $fixture->call($request('json', ['period' => $period, 'year' => (int)$periodDate->format('Y'),
            'quarter' => (int)ceil((int)$periodDate->format('n') / 3)]), $admin);
        $fixture->check($status === 200 && $coherent($report, 1), "stable $period JSON summary agrees across denominator, classifications and office counts");
    }
    [$status, $otherReport] = $fixture->call($request('json'), $otherAdmin);
    $fixture->check($status === 200 && !$otherReport['export_allowed'] && $coherent($otherReport, 1), 'non-Accounting admin JSON monitoring remains available');
    foreach (['json', 'csv', 'print'] as $index => $format) {
        $count = $index + 1;
        foreach (['report-ready', 'report-release'] as $file) if (is_file($fixture->root . '/' . $file)) unlink($fixture->root . '/' . $file);
        file_put_contents($fixture->root . '/pause-report', 'pause');
        $pending = $fixture->begin($request($format), $admin);
        [$multi] = $pending;
        $until = microtime(true) + 15;
        while (!is_file($fixture->root . '/report-ready')) {
            curl_multi_exec($multi, $running);
            if (!$running || microtime(true) > $until) throw new RuntimeException('Report did not reach the denominator scheduling barrier');
            curl_multi_select($multi, .05); usleep(10000);
        }
        $folder($count + 1);
        $fixture->check((int)$db->query('SELECT COUNT(*) FROM documents')->fetchColumn() === $count + 1,
            "$format overlapping folder/IN transaction commits before remaining report reads");
        unlink($fixture->root . '/pause-report');
        file_put_contents($fixture->root . '/report-release', 'continue');
        [$status, $report, $raw] = $fixture->finish($pending); $pending = null;
        if ($format === 'json') $matches = $coherent($report, $count);
        elseif ($format === 'csv') $matches = str_contains($raw, '"Documents in period",' . $count)
            && str_contains($raw, '"On time",' . $count . ',100') && str_contains($raw, '"Accounting Office",ACC,' . $count);
        else $matches = str_contains($raw, 'Documents in period: ' . $count . '</strong>')
            && str_contains($raw, '<td>On time</td><td>' . $count . '</td><td>100%</td>')
            && str_contains($raw, '<td>ACC</td><td>' . $count . '</td>');
        $fixture->check($status === 200 && $matches, "$format response retains one coherent database snapshot during the overlapping registration");
        [$status, $latest] = $fixture->call($request('json'), $admin);
        $fixture->check($status === 200 && $coherent($latest, $count + 1), "$format follow-up read sees the committed registration coherently");
    }
    $fixture->assertCopies();
} finally {
    file_put_contents($fixture->root . '/report-release', 'continue');
    if ($pending !== null) { [$multi, $curl] = $pending; curl_multi_remove_handle($multi, $curl); curl_close($curl); curl_multi_close($multi); }
    $fixture->close();
}
echo "{$fixture->checks} isolated report snapshot checks passed\n";
