<?php
// Synthetic custody report contract and snapshot checks. Never select the live schema.
declare(strict_types=1);
if (!getenv('TEST_DB_HOST')) throw new RuntimeException('Explicitly set TEST_DB_HOST to the reviewed test server; this script creates its own disposable schema.');
require __DIR__ . '/stabilization-test-helper.php';
date_default_timezone_set('Asia/Manila');

$fixture = new SmartflowStabilizationFixture(static function (string $name, string $source): string {
    if ($name !== 'report-register-helper.php') return $source;
    $anchor = '$total = (int)$count->fetchColumn();';
    if (substr_count($source, $anchor) !== 1) throw new RuntimeException('Register scheduling anchor changed');
    $barrier = <<<'PHP'

// Test-only scheduling after the real count; query logic is unchanged.
if (is_file(__DIR__ . '/pause-register')) {
    file_put_contents(__DIR__ . '/register-ready', 'ready');
    $until = microtime(true) + 20;
    while (!is_file(__DIR__ . '/register-release')) {
        if (microtime(true) > $until) throw new RuntimeException('Register test barrier timed out');
        usleep(10000);
    }
}
PHP;
    return str_replace($anchor, $anchor . $barrier, $source);
});
$pending = null;
try {
    $fixture->user(101, 'report_accounting_admin', 4, 'admin');
    $fixture->user(102, 'report_engineering_admin', 1, 'admin');
    $fixture->user(103, 'report_sender', 1);
    $fixture->user(104, 'report_receiver', 3);
    $fixture->user(105, 'report_accounting_receiver', 4);
    $fixture->user(106, 'report_head', 4, 'head');
    $db = $fixture->db;
    $db->prepare('UPDATE users SET name=? WHERE id=103')->execute(['  @Named <Sender>']);
    $db->exec("CREATE TABLE movement_destination_corrections (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, movement_id INT UNSIGNED NOT NULL,
        document_id VARCHAR(50) NOT NULL, previous_destination_office_id INT UNSIGNED NOT NULL,
        destination_office_id INT UNSIGNED NOT NULL, reason VARCHAR(1000) NOT NULL,
        corrected_by INT UNSIGNED NOT NULL, corrected_by_office_id INT UNSIGNED NOT NULL,
        corrected_at DATETIME NOT NULL, INDEX correction_movement(movement_id,id)) ENGINE=InnoDB");
    $folder = static function (int $number, string $title = 'Synthetic custody folder', string $type = 'Others: Register test') use ($db): string {
        $id = 'DOC-2001-' . str_pad((string)$number, 6, '0', STR_PAD_LEFT);
        $db->prepare('INSERT INTO documents(id,title,type,origin_office_id,created_by) VALUES(?,?,?,1,103)')->execute([$id, $title, $type]);
        return $id;
    };
    $movement = static function (string $id, int $office, string $status, string $at, ?int $destination = null) use ($db): int {
        $actor = match ($office) { 1 => 103, 3 => 104, default => 105 };
        $db->prepare('INSERT INTO movements(document_id,office_id,status,user_id,scanned_at,destination_office_id) VALUES(?,?,?,?,?,?)')
            ->execute([$id, $office, $status, $actor, $at, $destination]);
        return (int)$db->lastInsertId();
    };
    $one = $folder(1, 'Timely receipt across offices');
    $movement($one, 1, 'IN', '2020-09-01 08:00:00');
    $movement($one, 1, 'OUT', '2020-09-02 08:00:00', 3);
    $movement($one, 3, 'IN', '2020-09-03 08:00:00');
    $movement($one, 3, 'OUT', '2020-10-02 08:00:00', 4);
    $movement($one, 4, 'IN', '2020-10-03 08:00:00');
    $two = $folder(2, 'Late receipt then sent again');
    $movement($two, 1, 'IN', '2020-09-01 08:00:00');
    $movement($two, 1, 'OUT', '2020-09-02 08:00:00', 3);
    // Historical unknown event values are ignored by the existing classifier.
    $movement($two, 1, 'LEGACY', '2020-09-06 08:00:00');
    $movement($two, 3, 'IN', '2020-09-06 09:00:00');
    $latestTwoOut = $movement($two, 3, 'OUT', '2020-09-07 08:00:00', 4);
    $three = $folder(3, 'Earlier outstanding transfer');
    $movement($three, 1, 'IN', '2020-08-01 08:00:00');
    $correctedOut = $movement($three, 1, 'OUT', '2020-08-02 08:00:00', 4);
    $db->prepare('INSERT INTO movement_destination_corrections(movement_id,document_id,previous_destination_office_id,destination_office_id,reason,corrected_by,corrected_by_office_id,corrected_at) VALUES(?,?,3,4,?,103,1,?)')
        ->execute([$correctedOut, $three, 'Synthetic correction after September cutoff', '2020-10-01 08:00:00']);
    $movement($three, 4, 'IN', '2020-10-02 08:00:00');
    $four = $folder(4, 'Still held without forwarding');
    $movement($four, 1, 'IN', '2020-09-10 08:00:00');
    $five = $folder(5, 'Receipt exactly seventy two hours later');
    $movement($five, 1, 'IN', '2020-08-31 08:00:00');
    $movement($five, 1, 'OUT', '2020-08-31 12:00:00', 4);
    $movement($five, 4, 'IN', '2020-09-03 12:00:00');
    $six = $folder(6, 'Same timestamp ordered by movement ID');
    $movement($six, 1, 'IN', '2020-09-15 08:00:00');
    $movement($six, 1, 'OUT', '2020-09-16 08:00:00', 4);
    $movement($six, 4, 'IN', '2020-09-16 08:00:00');
    $seven = $folder(7, 'Current custody excludes future events');
    $movement($seven, 1, 'IN', date('Y-m-d H:i:s', time() - 60));
    $movement($seven, 1, 'OUT', date('Y-m-d H:i:s', time() + 86400), 4);
    $eight = $folder(8, '  =DANGEROUS <script>alert(1)</script> %_ custody');
    $movement($eight, 1, 'IN', '2020-09-20 08:00:00');

    $fixture->startServers();
    $admin = $fixture->login('report_accounting_admin');
    $otherAdmin = $fixture->login('report_engineering_admin');
    $staff = $fixture->login('report_sender');
    $head = $fixture->login('report_head');
    $query = ['month' => '2020-09'];
    $path = static fn(array $extra = []): string => 'reports-register.php?' . http_build_query(array_replace($query, $extra));
    $byId = static function (array $result, string $id): ?array {
        foreach ($result['documents'] ?? [] as $document) if ($document['document_id'] === $id) return $document;
        return null;
    };
    $fixture->check($fixture->call($path())[0] === 401, 'register requires authenticated access');
    $fixture->check($fixture->call($path(), $staff)[0] === 403 && $fixture->call($path(), $head)[0] === 403, 'staff and heads cannot read municipal registers');
    $fixture->check($fixture->call($path(), $admin, [])[0] === 405, 'register rejects write methods');
    [$status, $report] = $fixture->call($path(), $admin);
    $fixture->check($status === 200 && $report['total'] === 6 && count($report['documents']) === 6 && $report['page_size'] === 25, 'activity register returns complete server-paged period cohort');
    $fixture->check($fixture->call($path(), $otherAdmin)[1]['total'] === 6, 'non-Accounting admin retains municipal preview authority');
    $first = $byId($report, $one);
    $fixture->check($first['current_office_code'] === 'BUD' && $first['current_status'] === 'IN' && $first['movement_count'] === 3
        && $first['last_sent_at'] === '2020-09-02 08:00:00' && $first['last_received_at'] === '2020-09-03 08:00:00', 'historical movement and named handoff evidence excludes later custody');
    $fixture->check($first['recorded_by'] === 'Synthetic report_receiver' && $first['received_by'] === 'Synthetic report_receiver'
        && $first['sent_by'] === '  @Named <Sender>' && $first['receipt_wait_hours'] === null, 'register includes actual recorded receiver and sender without fabricating pending wait');
    $fixture->check($byId($report, $two)['classification'] === 'delayed' && $byId($report, $two)['current_status'] === 'OUT', 'late receipt keeps existing classification precedence after a later OUT');
    $fixture->check($byId($report, $four)['classification'] === 'on_time' && $byId($report, $five)['classification'] === 'on_time'
        && $byId($report, $six)['classification'] === 'on_time', 'in-custody, exactly 72-hour and same-time movement controls preserve receipt semantics');
    $fixture->check($report['as_of'] === '2020-09-30 23:59:59' && $report['timezone'] === 'Asia/Manila', 'historical report declares municipal cutoff and timezone');
    [$status, $outstanding] = $fixture->call($path(['scope' => 'outstanding']), $admin);
    $carry = $byId($outstanding, $three);
    $fixture->check($status === 200 && $outstanding['total'] === 2 && $byId($report, $three) === null && $carry['carried_forward'], 'outstanding includes old OUT with no period activity, separate from activity cohort');
    $fixture->check($carry['destination_office_code'] === 'BUD' && $carry['movement_count'] === 2 && $carry['receipt_wait_hours'] > 1400,
        'historical destination correction, trail count and wait use report cutoff');
    [$status, $year] = $fixture->call($path(['period' => 'year', 'year' => '2020']), $admin);
    $fixture->check($status === 200 && $year['total'] === 7 && $byId($year, $one)['current_office_code'] === 'ACC'
        && $byId($year, $three)['destination_office_id'] === null, 'annual activity uses annual cutoff and does not label received folders outstanding');
    [$status, $quarter] = $fixture->call($path(['period' => 'quarter', 'year' => '2020', 'quarter' => 3]), $admin);
    $fixture->check($status === 200 && $quarter['total'] === 7 && $quarter['period_start'] === '2020-07-01 00:00:00', 'quarter register includes all three months');
    [$status, $current] = $fixture->call($path(['month' => date('Y-m'), 'q' => $seven]), $admin);
    $fixture->check($status === 200 && $current['total'] === 1 && $byId($current, $seven)['current_status'] === 'IN'
        && $current['as_of'] <= date('Y-m-d H:i:s'), 'current period clamps cutoff at now and excludes future OUT');
    [$status, $office] = $fixture->call($path(['office_id' => 3]), $admin);
    $fixture->check($status === 200 && $office['total'] === 2 && $byId($office, $one) !== null && $byId($office, $two) !== null, 'office filter means latest custody or sending office rather than all office touches');
    foreach (['on_time' => 5, 'delayed' => 1, 'unforwarded' => 0] as $classification => $count) {
        [$status, $filtered] = $fixture->call($path(['classification' => $classification]), $admin);
        $fixture->check($status === 200 && $filtered['total'] === $count, "classification filter $classification agrees with summary semantics");
    }
    $fixture->check($fixture->call($path(['scope' => 'outstanding', 'classification' => 'unforwarded']), $admin)[1]['total'] === 1,
        'outstanding is custody state and can contain a delayed classified folder');
    foreach ([$one, 'Timely receipt', '%_'] as $search) {
        [$status, $searched] = $fixture->call($path(['q' => $search]), $admin);
        $fixture->check($status === 200 && $searched['total'] === 1, 'search matches literal folder ID/title characters including SQL wildcard symbols');
    }
    $fixture->check($fixture->call($path(['q' => 'Others: Register test']), $admin)[1]['total'] === 6, 'search includes folder type');
    [$status, $pageOne] = $fixture->call($path(['page_size' => 2]), $admin);
    [$statusTwo, $pageTwo] = $fixture->call($path(['page_size' => 2, 'page' => 2]), $admin);
    $fixture->check($status === 200 && $statusTwo === 200 && $pageOne['total'] === 6 && $pageOne['total_pages'] === 3
        && count($pageOne['documents']) === 2 && count($pageTwo['documents']) === 2
        && !array_intersect(array_column($pageOne['documents'], 'document_id'), array_column($pageTwo['documents'], 'document_id')), 'SQL paging retains whole-query totals and nonoverlapping pages');
    $fixture->check($fixture->call($path(['page' => 99]), $admin)[1]['documents'] === [], 'past-end page remains empty without silently changing the committed page');
    foreach ([['scope' => 'invalid'], ['classification' => 'invalid'], ['month' => '2020-13'], ['period' => 'week'], ['period' => 'quarter', 'quarter' => 5],
        ['page' => 0], ['page' => '1x'], ['page_size' => 51], ['office_id' => '-1'], ['q' => str_repeat('x', 201)], ['q' => ['nested']],
        ['as_of' => '2020-09-31 00:00:00'], ['as_of' => '2020-08-31 23:59:59'], ['as_of' => '2020-10-01 00:00:00'], ['as_of' => '2020-09-05T00:00:00Z'], ['as_of' => "2020-09-05 00:00:00\0"]] as $invalid) {
        $fixture->check($fixture->call($path($invalid), $admin)[0] === 400, 'invalid register query is rejected without returning an unrelated view');
    }
    $fixture->check($fixture->call($path(['office_id' => 99999]), $admin)[0] === 404, 'unknown office filter is explicit');
    [$status, $empty] = $fixture->call($path(['q' => 'no matching synthetic folder']), $admin);
    $fixture->check($status === 200 && $empty['total'] === 0 && $empty['total_pages'] === 0 && $empty['documents'] === [], 'verified empty register retains honest zero totals');
    $summaryPath = 'reports-summary.php?' . http_build_query(['month' => '2020-09', 'office_id' => 4]);
    [$status, $summary] = $fixture->call($summaryPath, $admin);
    $fixture->check($status === 200 && $summary['totals']['documents_in_period'] === 6 && $summary['compliance']['on_time']['count'] === 5
        && $summary['compliance']['delayed']['count'] === 1 && $summary['outstanding_transfers'] === 2 && $summary['carried_forward_transfers'] === 1,
        'summary classifications reconcile to register and separate carried outstanding counts');
    $frozenAt = '2020-09-05 23:59:59';
    [$status, $frozen] = $fixture->call($path(['as_of' => $frozenAt]), $admin);
    [$summaryStatus, $frozenSummary] = $fixture->call($summaryPath . '&as_of=' . rawurlencode($frozenAt), $admin);
    $fixture->check($status === 200 && $summaryStatus === 200 && $frozen['total'] === 3 && $frozenSummary['totals']['documents_in_period'] === 3
        && $frozenSummary['compliance']['unforwarded']['count'] === 1 && $byId($frozen, $two)['classification'] === 'unforwarded'
        && $byId($frozen, $two)['last_received_at'] === '2020-09-01 08:00:00' && $frozenSummary['as_of'] === $frozen['as_of'],
        'explicit cutoff keeps summary counts, category and underlying receipt evidence aligned');
    $fixture->check($fixture->call($summaryPath . '&as_of=2020-10-01%2000:00:00', $admin)[0] === 400,
        'summary and export reject out-of-period explicit cutoff');
    $fixture->check($fixture->call($path(['month' => date('Y-m'), 'as_of' => date('Y-m-d H:i:s', time() + 60)]), $admin)[0] === 400,
        'explicit future cutoff cannot expose future movements');
    foreach (['csv', 'print'] as $format) {
        $fixture->check($fixture->call($summaryPath . '&format=' . $format, $otherAdmin)[0] === 403, "$format export stays Accounting-admin only");
        [$status, , $raw] = $fixture->call($summaryPath . '&format=' . $format, $admin);
        $fixture->check($status === 200 && str_contains($raw, $one) && str_contains($raw, $three) && str_contains($raw, 'Synthetic report_receiver')
            && str_contains($raw, 'Outstanding transfers at cutoff') && str_contains($raw, 'Activity register') && str_contains($raw, '72 calendar hours'), "$format contains full activity and carried-transfer registers with named evidence and classification basis");
        $fixture->check(!str_contains($raw, '2020-10-03 08:00:00'), "$format cannot leak after-cutoff receipt evidence");
        $safe = $format === 'csv' ? str_contains($raw, "'  =DANGEROUS") && str_contains($raw, "'  @Named <Sender>")
            : !str_contains($raw, '<script>') && str_contains($raw, '&lt;script&gt;') && str_contains($raw, '&lt;Sender&gt;');
        $fixture->check($safe, "$format escapes untrusted folder titles and personnel names for its output context");
        [$frozenStatus, , $frozenRaw] = $fixture->call($summaryPath . '&format=' . $format . '&as_of=' . rawurlencode($frozenAt), $admin);
        $fixture->check($frozenStatus === 200 && str_contains($frozenRaw, $frozenAt) && !str_contains($frozenRaw, '2020-09-06 09:00:00')
            && !str_contains($frozenRaw, $eight), "$format reuses reviewed cutoff for its full register and receipt evidence");
    }

    // A movement and a new registration commit between the count and page read.
    file_put_contents($fixture->root . '/pause-register', 'pause');
    $pending = $fixture->begin($path(['page_size' => 50]), $admin);
    [$multi] = $pending;
    $until = microtime(true) + 15;
    while (!is_file($fixture->root . '/register-ready')) {
        curl_multi_exec($multi, $running);
        if (!$running || microtime(true) > $until) throw new RuntimeException('Register did not reach its count barrier');
        curl_multi_select($multi, .05); usleep(10000);
    }
    $db->beginTransaction();
    $nine = $folder(9, 'Concurrent synthetic registration');
    $movement($nine, 1, 'IN', '2020-09-29 08:00:00');
    $movement($one, 4, 'IN', '2020-09-28 08:00:00');
    $db->commit();
    unlink($fixture->root . '/pause-register');
    file_put_contents($fixture->root . '/register-release', 'continue');
    [$status, $consistent] = $fixture->finish($pending); $pending = null;
    $fixture->check($status === 200 && $consistent['total'] === 6 && count($consistent['documents']) === 6
        && $byId($consistent, $nine) === null && $byId($consistent, $one)['current_office_code'] === 'BUD', 'count and page custody evidence share one snapshot during concurrent commits');
    [$status, $latest] = $fixture->call($path(['page_size' => 50]), $admin);
    $fixture->check($status === 200 && $latest['total'] === 7 && $byId($latest, $one)['current_office_code'] === 'ACC', 'next register read sees the committed registration and custody together');
    [$status, $reviewed] = $fixture->call($path(['as_of' => '2020-09-25 23:59:59']), $admin);
    $fixture->check($status === 200 && $reviewed['total'] === 6 && $byId($reviewed, $nine) === null && $byId($reviewed, $one)['current_office_code'] === 'BUD',
        'reviewed cutoff continues excluding later registrations and custody after a fresh commit');
    // A timestamp alone would include this append at exactly the old cutoff,
    // the backdated folder above, and a new correction to an older OUT.
    $db->beginTransaction();
    $ten = $folder(10, 'Same-second append after report preview');
    $movement($ten, 1, 'IN', $summary['as_of']);
    $db->prepare('UPDATE movements SET destination_office_id=5 WHERE id=?')->execute([$latestTwoOut]);
    $db->prepare('INSERT INTO movement_destination_corrections(movement_id,document_id,previous_destination_office_id,destination_office_id,reason,corrected_by,corrected_by_office_id,corrected_at) VALUES(?,?,4,5,?,104,3,?)')
        ->execute([$latestTwoOut, $two, 'Synthetic same-second correction after preview', $summary['as_of']]);
    $db->commit();
    $watermarks = array_intersect_key($summary, array_flip(['as_of', 'movement_watermark', 'correction_watermark']));
    [$status, $fixed] = $fixture->call($path($watermarks), $admin);
    [$summaryStatus, $fixedSummary] = $fixture->call($summaryPath . '&' . http_build_query($watermarks), $admin);
    $fixture->check($status === 200 && $summaryStatus === 200 && $fixed['total'] === 6 && $byId($fixed, $nine) === null && $byId($fixed, $ten) === null
        && $byId($fixed, $one)['current_office_code'] === 'BUD' && $fixedSummary['compliance'] === $summary['compliance']
        && $fixedSummary['office_totals'] === $summary['office_totals'], 'event watermarks exclude same-second and backdated appends from summary, classification, office totals and register');
    $fixture->check($byId($fixed, $two)['destination_office_code'] === 'ACC'
        && $byId($fixture->call($path(), $admin)[1], $two)['destination_office_code'] === 'TRE',
        'correction watermark restores reviewed destination even when a new correction shares the cutoff timestamp');
    foreach (['csv', 'print'] as $format) {
        [$status, , $raw] = $fixture->call($summaryPath . '&format=' . $format . '&' . http_build_query($watermarks), $admin);
        $destinationMatches = false;
        if ($format === 'csv') {
            foreach (explode("\r\n", $raw) as $line) {
                $cells = str_getcsv($line, ',', '"', '');
                if (($cells[0] ?? null) === $two) $destinationMatches = ($cells[6] ?? null) === 'Accounting Office (ACC)';
            }
        } elseif (preg_match('/<strong>' . preg_quote($two, '/') . '<\/strong>.*?<\/tr>/s', $raw, $match)) {
            $destinationMatches = str_contains($match[0], 'Accounting Office (ACC)') && !str_contains($match[0], 'Municipal Treasury');
        }
        $fixture->check($status === 200 && !str_contains($raw, $nine) && !str_contains($raw, $ten) && $destinationMatches,
            "$format shares preview event watermarks across both full registers and destination evidence");
    }
    foreach (['movement_watermark' => -1, 'correction_watermark' => 999999999, 'movement_watermark[]' => '1'] as $key => $value) {
        $fixture->check($fixture->call($path() . '&' . rawurlencode($key) . '=' . rawurlencode((string)$value), $admin)[0] === 400,
            'register rejects invalid or unavailable event watermarks');
    }
    $fixture->check($fixture->call($summaryPath . '&movement_watermark=999999999', $admin)[0] === 400,
        'summary rejects event watermarks beyond its current read snapshot');
    [$status, $beforeEvents] = $fixture->call($path(['movement_watermark' => 0, 'correction_watermark' => 0]), $admin);
    $fixture->check($status === 200 && $beforeEvents['total'] === 0, 'zero movement watermark represents a verified empty event set');
    $fixture->assertCopies();
} finally {
    file_put_contents($fixture->root . '/register-release', 'continue');
    if ($pending !== null) { [$multi, $curl] = $pending; curl_multi_remove_handle($multi, $curl); curl_close($curl); curl_multi_close($multi); }
    $fixture->close();
}
echo "{$fixture->checks} isolated custody register checks passed\n";
