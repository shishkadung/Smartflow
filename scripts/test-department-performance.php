<?php
// Department performance (Objective 6): monthly visits per office, average hours, late visits, trend and recurring bottlenecks.
// Every folder is one visit with a known outcome, so the endpoint is compared with a plain calculation of the same data,
// with the COA summary's per-office stays, and with hand-checked anchors. Disposable schema only.
declare(strict_types=1);
if (!getenv('TEST_DB_HOST')) throw new RuntimeException('Explicitly set TEST_DB_HOST to the reviewed test server; this script creates its own disposable schema.');
require __DIR__ . '/stabilization-test-helper.php';
date_default_timezone_set('Asia/Manila');

$f = new SmartflowStabilizationFixture();
$statements = function () use ($f): int { return (int)$f->db->query("SHOW GLOBAL STATUS LIKE 'Questions'")->fetch(PDO::FETCH_NUM)[1]; };
try {
    $db = $f->db;
    $codes = [1 => 'ENG', 2 => 'HR', 3 => 'BUD', 4 => 'ACC', 5 => 'TRE', 6 => 'MAY'];
    $f->user(301, 'perf_accounting_admin', 4, 'admin');
    $f->user(302, 'perf_engineering_admin', 1, 'admin');
    $f->user(303, 'perf_staff', 4);
    $f->user(304, 'perf_head', 4, 'head');
    foreach ($codes as $id => $code) $f->user(310 + $id, 'perf_clerk_' . strtolower($code), $id);
    $f->startServers();
    $admin = $f->login('perf_accounting_admin');   // the first request creates the runtime schema, including the threshold table
    $db->exec("INSERT INTO processing_thresholds(office_id,document_type,max_hours,out_unconfirmed_hours,is_active) VALUES
        (2,'Others: Slow review',200,24,1), (1,'Others: Tight',12,24,1), (3,'Others: Tight',12,24,0)
        ON DUPLICATE KEY UPDATE max_hours=VALUES(max_hours), is_active=VALUES(is_active)");
    $limits = [1 => ['others: tight' => 12], 2 => ['others: slow review' => 200]];   // active rules used by the calculation; the rest use 48 h

    $months = ['2020-04', '2020-05', '2020-06', '2020-07', '2020-08', '2020-09'];
    $visits = [];   // office, month, type, hours, kind, plus optional filed hours
    $add = function (int $office, string $month, string $type, int $hours, string $kind = 'forwarded', ?int $filedAfter = null, bool $manual = false) use (&$visits) {
        $visits[] = compact('office', 'month', 'type', 'hours', 'kind', 'filedAfter', 'manual');
    };
    $matrix = [   // office => month => [on time visits at 10 h, late visits at 60 h]
        5 => ['2020-04' => [1, 3], '2020-05' => [2, 3], '2020-06' => [4, 0], '2020-07' => [1, 3], '2020-08' => [2, 2], '2020-09' => [4, 0]],
        3 => ['2020-04' => [4, 0], '2020-05' => [3, 1], '2020-06' => [4, 0], '2020-07' => [3, 0], '2020-08' => [2, 2], '2020-09' => [4, 0]],
    ];
    foreach ($matrix as $office => $perMonth) foreach ($perMonth as $month => [$fast, $slow]) {
        for ($i = 0; $i < $fast; $i++) $add($office, $month, 'Others: Test', 10);
        for ($i = 0; $i < $slow; $i++) $add($office, $month, 'Others: Test', 60);
    }
    foreach ($months as $i => $month) {
        for ($k = 0; $k < 3; $k++) {
            $add(4, $month, 'Others: Test', $i < 3 ? 10 : 30);      // ACC gets slower
            $add(1, $month, 'Others: Test', $i < 3 ? 40 : 12);      // ENG gets faster
            $add(6, $month, 'Others: Test', $i < 3 ? 10 : 11);      // MAY is steady
            $add(2, $month, 'Others: Slow review', $i < 3 ? 100 : 105);   // HR is slow in hours but inside its 200 h limit; 5% change
        }
    }
    $add(3, '2020-06', 'Others: Tight', 20);                  // BUD rule for this type is inactive: not late
    $add(1, '2020-09', 'Others: Tight', 20);                  // ENG rule is active (12 h): late
    $add(6, '2020-09', 'Others: Test', 0, 'open');            // still at the Mayor's Office at the cutoff
    $add(4, '2020-09', 'Others: Memo', 0, 'completed', 24);   // filed one day after receipt
    $add(2, '2020-09', 'Others: Memo', 0, 'completed', 120);  // filed five days after receipt: over the 48 h limit
    $add(6, '2020-09', 'Disbursement Voucher', 2, 'forwarded', null, true);   // MAY forwards the DV to Treasury ...
    $add(5, '2020-09', 'Disbursement Voucher', 0, 'completed', null, true);   // ... and Treasury's receipt finishes the trail

    // Rows ------------------------------------------------------------------------------------------------------------------------
    $folder = $db->prepare('INSERT INTO documents(id,title,type,origin_office_id,created_by,filed_at,filed_by) VALUES(?,?,?,?,?,?,?)');
    $move = $db->prepare('INSERT INTO movements(document_id,office_id,status,user_id,scanned_at,destination_office_id) VALUES(?,?,?,?,?,?)');
    $n = 0;
    $db->beginTransaction();
    foreach ($visits as &$v) {
        if ($v['manual']) continue;
        $id = sprintf('DOC-2003-%06d', ++$n); $actor = 310 + $v['office'];
        $day = $v['kind'] === 'open' ? '05' : ($v['kind'] === 'completed' ? '03' : '02');
        $in = "{$v['month']}-$day 08:00:00"; $v['in'] = $in;
        $filed = isset($v['filedAfter']) ? date('Y-m-d H:i:s', strtotime($in) + $v['filedAfter'] * 3600) : null;
        $folder->execute([$id, "Visit $n", $v['type'], $v['office'], $actor, $filed, $filed ? $actor : null]);
        $move->execute([$id, $v['office'], 'IN', $actor, $in, null]);
        if ($v['kind'] === 'forwarded') $move->execute([$id, $v['office'], 'OUT', $actor, date('Y-m-d H:i:s', strtotime($in) + $v['hours'] * 3600), $v['office'] % 6 + 1]);
    }
    // One Disbursement Voucher: the Mayor's Office forwards it in two hours and Treasury receives it after the Mayor, which ends the trail.
    $dv = sprintf('DOC-2003-%06d', ++$n);
    $folder->execute([$dv, 'Voucher through the Mayor', 'Disbursement Voucher', 6, 316, null, null]);
    $move->execute([$dv, 6, 'IN', 316, '2020-09-10 08:00:00', null]);
    $move->execute([$dv, 6, 'OUT', 316, '2020-09-10 10:00:00', 5]);
    $move->execute([$dv, 5, 'IN', 315, '2020-09-11 08:00:00', null]);
    unset($v);
    $db->commit();
    $db->query('ANALYZE TABLE movements, documents, offices, users, processing_thresholds')->fetchAll();

    // Plain calculation of the expected figures ------------------------------------------------------------------------------------
    $expect = function (array $window) use ($visits, $limits): array {
        $cells = [];
        foreach ($visits as $v) {
            if (!in_array($v['month'], $window, true)) continue;
            $cutoff = date('Y-m-t 23:59:59', strtotime($v['month'] . '-01'));
            $seconds = match ($v['kind']) { 'forwarded' => $v['hours'] * 3600, 'open' => strtotime($cutoff) - strtotime($v['in']), default => ($v['filedAfter'] ?? 0) * 3600 };
            $limit = $limits[$v['office']][strtolower($v['type'])] ?? 48;
            $c = &$cells[$v['office']][$v['month']];
            $c ??= ['visits' => 0, 'forwarded' => 0, 'open' => 0, 'completed' => 0, 'seconds' => 0, 'late' => 0];
            $c['visits']++; $c[$v['kind']]++;
            if ($v['kind'] === 'forwarded') $c['seconds'] += $seconds;
            if ($seconds > $limit * 3600) $c['late']++;
            unset($c);
        }
        return $cells;
    };
    $get = fn(array $query, ?string $token = null) => $f->call('department-performance.php?' . http_build_query($query), $token ?? $admin);
    $num = fn(mixed $value): ?float => $value === null ? null : (float)$value;
    $office = fn(array $report, string $code): array => array_column($report['offices'], null, 'office_code')[$code];

    // Six months ending September 2020 -------------------------------------------------------------------------------------------
    [$status, $report] = $get(['months' => 6, 'end_month' => '2020-09']);
    $f->check($status === 200 && $report['window']['list'] === $months && $report['window']['start_month'] === '2020-04' && $report['window']['end_month'] === '2020-09', 'a six month window ending September 2020 lists April to September');
    $f->check(count($report['offices']) === 6 && $report['rules']['min_visits_per_month'] === 3 && $report['rules']['slow_month_late_percent'] === 25 && $report['rules']['recurring_slow_months'] === 3,
        'all six offices and the bottleneck rules are returned with the data');
    $expected = $expect($months);
    $allMatch = true; $detail = '';
    foreach ($codes as $id => $code) {
        $row = $office($report, $code);
        foreach ($row['months'] as $i => $cell) {
            $e = $expected[$id][$months[$i]] ?? ['visits' => 0, 'forwarded' => 0, 'open' => 0, 'completed' => 0, 'seconds' => 0, 'late' => 0];
            $avg = $e['forwarded'] ? round($e['seconds'] / $e['forwarded'] / 3600, 1) : null;
            if ($cell['visits'] !== $e['visits'] || $cell['forwarded'] !== $e['forwarded'] || $cell['open'] !== $e['open'] || $cell['completed'] !== $e['completed'] || $cell['late'] !== $e['late'] || $num($cell['avg_hours']) !== $avg) {
                $allMatch = false; $detail .= " $code {$months[$i]}";
            }
        }
    }
    $f->check($allMatch, 'every office and month (36 cells) matches the plain calculation of visits, forwarded, open, completed, average hours and late visits' . $detail);

    $tre = $office($report, 'TRE'); $bud = $office($report, 'BUD');
    $f->check($tre['bottleneck'] === ['recurring' => true, 'slow_months' => 4, 'active_months' => 6, 'slow_month_list' => ['2020-04', '2020-05', '2020-07', '2020-08']] && $tre['totals']['visits'] === 26 && $tre['totals']['late'] === 11 && $num($tre['totals']['late_percent']) === 42.3,
        'Treasury is a recurring bottleneck: slow in April, May, July and August (11 of 26 visits late, 42.3%)');
    $f->check($bud['bottleneck']['recurring'] === false && $bud['bottleneck']['slow_month_list'] === ['2020-05', '2020-08'], 'Budget is slow in two months, including a month with exactly 25% late, so it is not recurring');
    $f->check(array_column($report['bottlenecks'], 'office_code') === ['TRE'] && $report['bottlenecks'][0]['slow_months'] === 4, 'the bottleneck list names Treasury only');
    $f->check($office($report, 'ENG')['months'][5]['late'] === 1 && $office($report, 'BUD')['months'][2]['late'] === 0, 'an active office limit makes a visit late and an inactive one is ignored');
    $may = $office($report, 'MAY')['months'][5]; $treSep = $tre['months'][5]; $hrSep = $office($report, 'HR')['months'][5];
    $f->check($may['open'] === 1 && $may['late'] === 1 && $may['slow'] === false, 'a folder still at the office is counted as open and late once over the limit (1 of 5 visits is below the slow-month share)');
    $f->check($treSep['completed'] === 1 && $treSep['late'] === 0 && $treSep['visits'] === 5, 'a visit that ended the trail is completed, not waiting, so it is not counted late');
    $f->check($hrSep['completed'] === 1 && $hrSep['late'] === 1, 'a folder filed five days after receipt is completed and counted late against the 48 h limit');

    $trendOf = fn(string $code): array => $office($report, $code)['trend'];
    $acc = $trendOf('ACC'); $eng = $trendOf('ENG'); $mayTrend = $trendOf('MAY'); $hr = $trendOf('HR');
    $f->check($acc['direction'] === 'slower' && $num($acc['earlier_avg_hours']) === 10.0 && $num($acc['later_avg_hours']) === 30.0 && $num($acc['change_hours']) === 20.0, 'Accounting got slower: 10.0 h in the earlier months, 30.0 h in the later months (+20.0 h)');
    $f->check($eng['direction'] === 'faster' && $num($eng['earlier_avg_hours']) === 40.0 && $num($eng['later_avg_hours']) === 12.8 && $num($eng['change_hours']) === -27.2, 'Engineering got faster: 40.0 h to 12.8 h (-27.2 h; nine visits of 12 h and one of 20 h in the later months)');
    $f->check($mayTrend['direction'] === 'steady' && $hr['direction'] === 'steady' && $num($hr['change_hours']) === 5.0, 'a small change is steady, including 100 h to 105 h (5 h but only 5%)');

    $municipal = $report['municipal'];
    $sumVisits = array_sum(array_map(fn($row) => $row['totals']['visits'], $report['offices']));
    $f->check($municipal['totals']['visits'] === $sumVisits && count($municipal['months']) === 6 && $municipal['totals']['late'] === array_sum(array_map(fn($row) => $row['totals']['late'], $report['offices'])),
        'the municipal row is the sum of the offices');
    $types = $tre['types'];
    $f->check($types[0]['type'] === 'Others: Test' && $types[0]['late'] === 11, 'the slowest folder types are listed for each office');

    // The COA summary and this report describe the same stays -----------------------------------------------------------------------
    $consistent = true; $where = '';
    foreach ($months as $i => $month) {
        [$s, $coa] = $f->call('reports-summary.php?' . http_build_query(['office_id' => 4, 'month' => $month]), $admin);
        foreach (array_column($coa['office_totals'], null, 'office_code') as $code => $row) {
            $cell = $office($report, $code)['months'][$i];
            if ($s !== 200 || $cell['forwarded'] !== $row['forwarded_stays'] || $num($cell['avg_hours']) !== $num($row['avg_hours_at_office']) || $cell['open'] + $cell['completed'] !== $row['open_stays']) { $consistent = false; $where .= " $code $month"; }
        }
    }
    $f->check($consistent, 'for every month and office the forwarded visits, average hours and still-at-office count equal the COA summary (36 comparisons)' . $where);

    // Other windows --------------------------------------------------------------------------------------------------------------------
    [$status, $three] = $get(['months' => 3, 'end_month' => '2020-09']);
    $f->check($status === 200 && $three['window']['list'] === ['2020-07', '2020-08', '2020-09'] && count($office($three, 'TRE')['months']) === 3 && $office($three, 'TRE')['bottleneck']['slow_months'] === 2 && $office($three, 'TRE')['bottleneck']['recurring'] === false,
        'a three month window only looks at July to September (Treasury was slow in two of those months)');
    [$status, $year] = $get(['months' => 12, 'end_month' => '2020-09']);
    $f->check($status === 200 && count($year['window']['list']) === 12 && $office($year, 'ACC')['trend']['direction'] === 'insufficient' && $office($year, 'ACC')['trend']['change_hours'] === null && $office($year, 'TRE')['bottleneck']['recurring'] === true,
        'a window whose earlier half has no visits reports an insufficient trend instead of inventing one, and still finds the recurring bottleneck');
    [$status, $empty] = $get(['months' => 3, 'end_month' => '2019-03']);
    $f->check($status === 200 && $empty['bottlenecks'] === [] && $empty['municipal']['totals']['visits'] === 0 && $empty['municipal']['totals']['avg_hours'] === null && $office($empty, 'TRE')['totals']['late_percent'] === null && $office($empty, 'TRE')['trend']['direction'] === 'insufficient',
        'a window without activity has no averages, percentages or bottlenecks');
    [$status, $current] = $get([]);
    $f->check($status === 200 && $current['window']['months'] === 6 && $current['window']['end_month'] === date('Y-m') && $current['window']['cutoff'] <= date('Y-m-d H:i:s'), 'by default the report covers the last six months up to now');

    // Access and input -----------------------------------------------------------------------------------------------------------------
    $f->check($f->call('department-performance.php')[0] === 401, 'a session is required');
    foreach (['perf_staff', 'perf_head'] as $user) $f->check($get(['months' => 6], $f->login($user))[0] === 403, "$user cannot read department performance");
    $f->check($get(['months' => 6, 'end_month' => '2020-09'], $f->login('perf_engineering_admin'))[0] === 200, 'an administrator of any office can read the view');
    foreach ([['months' => 2], ['months' => 13], ['months' => 'abc'], ['end_month' => '2099-01'], ['end_month' => '2000-01'], ['end_month' => '2020-13'], ['end_month' => 'last month']] as $bad) {
        $f->check($get($bad)[0] === 400, 'rejects ' . json_encode($bad));
    }
    $c = curl_init($f->bases[0] . '/department-performance.php'); curl_setopt_array($c, [CURLOPT_POST => true, CURLOPT_RETURNTRANSFER => true, CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $admin]]);
    curl_exec($c); $f->check(curl_getinfo($c, CURLINFO_HTTP_CODE) === 405, 'only GET is accepted'); curl_close($c);

    $before = $statements(); $get(['months' => 12, 'end_month' => '2020-09']); $used = $statements() - $before - 1;
    $f->check($used < 60, "a twelve month report used $used SQL statements regardless of the number of folders");
    $f->assertCopies();
} finally {
    $f->close();
}
echo "{$f->checks} department performance checks passed\n";
