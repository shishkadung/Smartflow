<?php
// Completion rate and average time at each office in the COA summary, checked against hand-labelled folders,
// an independent calculation, the SQL completion rule, the cutoff and the event watermark. Disposable schema only.
declare(strict_types=1);
if (!getenv('TEST_DB_HOST')) throw new RuntimeException('Explicitly set TEST_DB_HOST to the reviewed test server; this script creates its own disposable schema.');
require __DIR__ . '/stabilization-test-helper.php';
date_default_timezone_set('Asia/Manila');

$f = new SmartflowStabilizationFixture();
try {
    $db = $f->db;
    $offices = [1 => 'ENG', 2 => 'HR', 3 => 'BUD', 4 => 'ACC', 5 => 'TRE', 6 => 'MAY'];
    $f->user(101, 'metrics_accounting_admin', 4, 'admin');
    $f->user(102, 'metrics_engineering_admin', 1, 'admin');
    foreach ($offices as $id => $code) $f->user(110 + $id, 'metrics_staff_' . strtolower($code), $id);
    $dv = 'Disbursement Voucher'; $budget = 'Approved Budget'; $other = 'Others: Memo';
    $d = fn(string $md, string $time = '08:00') => "2020-$md $time:00";
    // office, status, time, destination. 'complete' is labelled by hand for the end of September and for the whole year.
    $folders = [
        'F1 DV through Mayor back to Treasury' => ['type' => $dv, 'sep' => true, 'year' => true, 'moves' => [
            [1, 'IN', $d('09-01')], [1, 'OUT', $d('09-01', '20:00'), 3], [3, 'IN', $d('09-02')], [3, 'OUT', $d('09-03'), 4], [4, 'IN', $d('09-03', '20:00')],
            [4, 'OUT', $d('09-04'), 5], [5, 'IN', $d('09-05')], [5, 'OUT', $d('09-05', '14:00'), 6], [6, 'IN', $d('09-06')], [6, 'OUT', $d('09-06', '10:00'), 5], [5, 'IN', $d('09-07')]]],
        'F2 DV held at Budget' => ['type' => $dv, 'sep' => false, 'year' => false, 'moves' => [[1, 'IN', $d('09-10')], [1, 'OUT', $d('09-10', '14:00'), 3], [3, 'IN', $d('09-10', '20:00')]]],
        'F3 Approved Budget received at Accounting' => ['type' => $budget, 'sep' => true, 'year' => true, 'moves' => [[3, 'IN', $d('09-11')], [3, 'OUT', $d('09-11', '11:00'), 4], [4, 'IN', $d('09-11', '15:00')]]],
        'F4 Others at HR, not filed' => ['type' => $other, 'sep' => false, 'year' => false, 'moves' => [[1, 'IN', $d('09-12')], [1, 'OUT', $d('09-12', '09:00'), 2], [2, 'IN', $d('09-12', '12:00')]]],
        'F5 Others filed in September' => ['type' => $other, 'sep' => true, 'year' => true, 'filed' => $d('09-14'), 'moves' => [[2, 'IN', $d('09-13')]]],
        'F6 Others filed after the September cutoff' => ['type' => $other, 'sep' => false, 'year' => true, 'filed' => $d('10-02', '09:00'), 'moves' => [[2, 'IN', $d('09-15')]]],
        'F7 Others named like a voucher at Treasury' => ['type' => 'Others: Disbursement voucher batch', 'sep' => false, 'year' => false, 'moves' => [[6, 'IN', $d('09-16')], [6, 'OUT', $d('09-16', '09:00'), 5], [5, 'IN', $d('09-16', '12:00')]]],
        'F8 DV active only before September' => ['type' => $dv, 'sep' => false, 'year' => false, 'moves' => [[1, 'IN', $d('08-01')], [1, 'OUT', $d('08-01', '12:00'), 3]]],
        'F9 IN in September, OUT after the cutoff' => ['type' => $dv, 'sep' => false, 'year' => false, 'moves' => [[1, 'IN', $d('09-30', '20:00')], [1, 'OUT', $d('10-02'), 3]]],
        'F10 IN before September, OUT inside it' => ['type' => $dv, 'sep' => false, 'year' => false, 'moves' => [[1, 'IN', $d('08-31', '20:00')], [1, 'OUT', $d('09-01'), 3]]],
        'F11 DV completed at Accounting after Treasury' => ['type' => $dv, 'sep' => true, 'year' => true, 'moves' => [
            [1, 'IN', $d('09-17')], [1, 'OUT', $d('09-17', '09:00'), 5], [5, 'IN', $d('09-17', '10:00')], [5, 'OUT', $d('09-17', '11:00'), 6], [6, 'IN', $d('09-17', '12:00')], [6, 'OUT', $d('09-17', '13:00'), 5],
            [5, 'IN', $d('09-18')], [5, 'OUT', $d('09-18', '09:00'), 4], [4, 'IN', $d('09-18', '10:00')]]],
        'F12 DV whose last event is a legacy value' => ['type' => $dv, 'sep' => false, 'year' => false, 'moves' => [[1, 'IN', $d('09-19')], [1, 'LEGACY', $d('09-19', '09:00')]]],
        'F13 DV sent on from Treasury' => ['type' => $dv, 'sep' => false, 'year' => false, 'moves' => [[6, 'IN', $d('09-20')], [6, 'OUT', $d('09-20', '10:00'), 5], [5, 'IN', $d('09-20', '12:00')], [5, 'OUT', $d('09-20', '13:00'), 4]]],
    ];
    $insertFolder = $db->prepare('INSERT INTO documents(id,title,type,origin_office_id,created_by,filed_at,filed_by) VALUES(?,?,?,?,?,?,?)');
    $insertMove = $db->prepare('INSERT INTO movements(document_id,office_id,status,user_id,scanned_at,destination_office_id) VALUES(?,?,?,?,?,?)');
    $ids = []; $n = 0;
    foreach ($folders as $label => $folder) {
        $id = sprintf('DOC-2002-%06d', ++$n); $ids[$label] = $id;
        $first = $folder['moves'][0][0];
        $insertFolder->execute([$id, $label, $folder['type'], $first, 110 + $first, $folder['filed'] ?? null, isset($folder['filed']) ? 110 + $first : null]);
        foreach ($folder['moves'] as $m) $insertMove->execute([$id, $m[0], $m[1], 110 + $m[0], $m[2], $m[3] ?? null]);
    }
    $f->startServers();
    $admin = $f->login('metrics_accounting_admin');
    $summary = fn(array $query, string $format = 'json') => $f->call('reports-summary.php?' . http_build_query(['office_id' => 4, 'format' => $format] + $query), $admin);

    // Independent calculation of the same period, written without the SQL used by the endpoint.
    $expect = function (string $start, string $end) use ($folders, $offices): array {
        $cohort = []; $processed = array_fill_keys(array_keys($offices), []); $stays = array_fill_keys(array_keys($offices), ['closed' => 0, 'open' => 0, 'seconds' => 0]);
        foreach ($folders as $label => $folder) {
            $moves = array_values(array_filter($folder['moves'], fn($m) => $m[2] <= $end));
            foreach ($moves as $i => $m) {
                if ($m[2] >= $start) { $cohort[$label] = true; $processed[$m[0]][$label] = true; }
                if ($m[1] !== 'IN' || $m[2] < $start) continue;
                $out = null;
                foreach (array_slice($moves, $i + 1) as $later) if ($later[0] === $m[0] && $later[1] === 'OUT') { $out = $later; break; }
                if ($out) { $stays[$m[0]]['closed']++; $stays[$m[0]]['seconds'] += strtotime($out[2]) - strtotime($m[2]); } else $stays[$m[0]]['open']++;
            }
        }
        return ['cohort' => array_keys($cohort), 'processed' => array_map('count', $processed), 'stays' => $stays];
    };
    $avg = fn(array $s): ?float => $s['closed'] ? round($s['seconds'] / $s['closed'] / 3600, 1) : null;
    $num = fn(mixed $value): ?float => $value === null ? null : (float)$value;   // JSON writes 5.0 as 5

    // September: the main period -----------------------------------------------------------------------------------------
    [$status, $report] = $summary(['month' => '2020-09']);
    $expected = $expect('2020-09-01 00:00:00', '2020-09-30 23:59:59');
    $f->check($status === 200 && $report['totals']['documents_in_period'] === 12 && count($expected['cohort']) === 12, 'September cohort is the 12 folders with activity (the August-only folder is excluded)');
    $completedSep = count(array_filter($expected['cohort'], fn($label) => $folders[$label]['sep']));
    $f->check($completedSep === 4 && $report['completion']['completed'] === 4 && $report['completion']['of'] === 12 && $report['completion']['percent'] === 33.3,
        'completion is 4 of 12 folders (33.3%): the finished DV, the Approved Budget at Accounting, the filed folder and the DV completed at Accounting');
    $f->check($report['completion']['of'] === $report['totals']['documents_in_period'], 'the completion denominator is the existing documents-in-period count');
    $f->check(str_contains($report['completion']['basis'], 'not financial approval'), 'completion states that it measures the physical trail');
    $byCode = array_column($report['office_totals'], null, 'office_code');
    foreach ($offices as $id => $code) {
        $row = $byCode[$code]; $s = $expected['stays'][$id];
        $f->check($row['docs_processed'] === $expected['processed'][$id] && $row['forwarded_stays'] === $s['closed'] && $row['open_stays'] === $s['open'] && $num($row['avg_hours_at_office']) === $avg($s),
            "$code: {$row['docs_processed']} folders, {$row['forwarded_stays']} forwarded stays averaging " . ($row['avg_hours_at_office'] ?? 'none') . " h, {$row['open_stays']} still at the office");
    }
    $f->check($num($byCode['ENG']['avg_hours_at_office']) === 5.0 && $num($byCode['BUD']['avg_hours_at_office']) === 13.5 && $num($byCode['ACC']['avg_hours_at_office']) === 12.0
        && $num($byCode['TRE']['avg_hours_at_office']) === 2.3 && $num($byCode['MAY']['avg_hours_at_office']) === 1.5 && $byCode['HR']['avg_hours_at_office'] === null,
        'hand-checked averages: ENG 5.0, BUD 13.5, ACC 12.0, TRE 2.3 (2.25 rounded), MAY 1.5, HR none because nothing was forwarded');
    $f->check($report['processing_time']['forwarded_stays'] === 15 && $report['processing_time']['open_stays'] === 10 && $report['processing_time']['average_hours'] === 4.9,
        'all offices: 15 forwarded stays averaging 4.9 h (74 h in total) and 10 stays still at the office');
    $f->check($byCode['ENG']['open_stays'] === 2, 'an IN whose OUT was recorded after the cutoff stays open, and an IN before the period is not counted');

    // Existing numbers keep their meaning.
    $compliance = $report['compliance'];
    $f->check($compliance['on_time']['count'] + $compliance['unforwarded']['count'] + $compliance['delayed']['count'] === 12
        && $compliance['on_time']['percent'] + $compliance['unforwarded']['percent'] + $compliance['delayed']['percent'] === 100
        && $report['totals']['this_office_documents'] === $expected['processed'][4], 'existing classification totals, percentages and the office spotlight are unchanged');

    // Cutoff and event watermark -------------------------------------------------------------------------------------------
    [$status, $early] = $summary(['month' => '2020-09', 'as_of' => '2020-09-10 12:00:00']);
    $expectedEarly = $expect('2020-09-01 00:00:00', '2020-09-10 12:00:00');
    $earlyEng = array_column($early['office_totals'], null, 'office_code')['ENG'];
    $f->check($status === 200 && $early['completion']['of'] === 3 && $early['completion']['completed'] === 1 && $early['completion']['percent'] === 33.3
        && count($expectedEarly['cohort']) === 3, 'an earlier cutoff only counts what had happened by then (3 folders, 1 finished)');
    $f->check($earlyEng['forwarded_stays'] === 1 && $num($earlyEng['avg_hours_at_office']) === 12.0 && $earlyEng['open_stays'] === 1, 'an OUT recorded after the cutoff does not close a stay at the earlier cutoff');
    $watermark = $report['movement_watermark'];
    $db->prepare('INSERT INTO movements(document_id,office_id,status,user_id,scanned_at,destination_office_id) VALUES(?,?,?,?,?,?)')
        ->execute([$ids['F12 DV whose last event is a legacy value'], 1, 'OUT', 111, $d('09-19', '09:30'), 3]);
    [$status, $frozen] = $summary(['month' => '2020-09', 'movement_watermark' => $watermark, 'as_of' => $report['as_of']]);
    $f->check($status === 200 && $frozen['processing_time'] === $report['processing_time'] && $frozen['completion'] === $report['completion'] && $frozen['office_totals'] === $report['office_totals'],
        'a backdated event added after the watermark changes none of the new figures or the existing office totals');
    [$status, $later] = $summary(['month' => '2020-09']);
    $f->check($status === 200 && array_column($later['office_totals'], null, 'office_code')['ENG']['forwarded_stays'] === 5, 'without the watermark the late event closes one more stay');

    // The year agrees with the SQL completion rule used everywhere else ------------------------------------------------------------
    [$status, $year] = $summary(['period' => 'year', 'year' => '2020']);
    $f->check($status === 200 && $year['completion']['of'] === 13 && $year['completion']['completed'] === 5 && $year['completion']['percent'] === 38.5, 'the annual report counts 5 of 13 folders finished');
    [$status, $tray] = $f->call('office-documents.php?scope=municipal', $admin);
    $sqlComplete = count(array_filter($tray['documents'], fn($doc) => !empty($doc['trail_complete']) && str_starts_with($doc['id'], 'DOC-2002-')));
    $f->check($status === 200 && $sqlComplete === $year['completion']['completed'], "the PHP completion count ($sqlComplete) equals the SQL trail_complete rule used by the trays and alerts");

    // Exports ------------------------------------------------------------------------------------------------------------------------
    $snapshot = ['month' => '2020-09', 'movement_watermark' => $watermark, 'as_of' => $report['as_of']];   // the report as first generated, before the late event
    [, , $csv] = $summary($snapshot, 'csv');
    foreach (['"Trail completion at cutoff",Folders,Percent', '"Complete or filed",4,33.3', '"Folders with activity in the period",12,', '"All offices",4.9,15,10',
        '"Average hours at office before forwarding"', ',ENG,7,4,5,2'] as $needle) {
        $f->check(str_contains($csv, $needle), "CSV contains $needle");
    }
    $f->check(str_contains($csv, '"Documents in period",12'), 'CSV keeps its existing rows');
    [, , $print] = $summary($snapshot, 'print');
    foreach (['4 of 12 folders (33.3%)', 'Average 4.9 hours at an office before forwarding', 'Forwarded stays', 'Average hours at office'] as $needle) $f->check(str_contains($print, $needle), "printable summary contains: $needle");
    [$status, ] = $f->call('reports-summary.php?office_id=1&month=2020-09&format=csv', $f->login('metrics_engineering_admin'));
    $f->check($status === 403, 'only Accounting administrators can export the new figures');

    // An empty period shows no invented figures ---------------------------------------------------------------------------------------
    [$status, $empty] = $summary(['month' => '2019-01']);
    $f->check($status === 200 && $empty['completion']['of'] === 0 && $empty['completion']['percent'] === null && $empty['processing_time']['average_hours'] === null
        && $empty['processing_time']['forwarded_stays'] === 0, 'a period without activity reports no completion rate and no average');
    [, , $emptyCsv] = $summary(['month' => '2019-01'], 'csv');
    [, , $emptyPrint] = $summary(['month' => '2019-01'], 'print');
    $f->check(str_contains($emptyCsv, 'No forwarded folders') && str_contains($emptyPrint, 'No folders were forwarded in this period'), 'exports of an empty period say that nothing was forwarded');
    $f->assertCopies();
} finally {
    $f->close();
}
echo "{$f->checks} COA completion and time-at-office checks passed\n";
