<?php
declare(strict_types=1);

require_once __DIR__ . '/report-metrics-helper.php';
require_once __DIR__ . '/thresholds-helper.php';

/** Thresholds that turn monthly numbers into a "recurring bottleneck"; they are returned with every response. */
function smartflow_performance_rules(): array
{
    return [
        'min_visits_per_month' => 3,
        'slow_month_late_percent' => 25,
        'recurring_slow_months' => 3,
        'trend_min_forwarded' => 3,
        'trend_min_change_hours' => 2,
        'trend_min_change_percent' => 10,
        'default_desk_limit_hours' => smartflow_threshold_defaults()['max_hours'],
    ];
}

function smartflow_performance_basis(): string
{
    return 'A visit is one IN at an office. Each month is measured at its own end (the current month up to now), so past months do not change when later folders are forwarded. '
        . 'Average hours counts forwarded visits only: the hours between the IN and that office\'s next OUT. A visit is late when its hours (or, if the folder is still at the office, the hours so far) exceed the office\'s desk limit for that folder type; a folder whose trail was finished by receiving it is not counted as waiting. '
        . 'A month is slow when it has at least 3 visits and at least 25% of them were late. An office is a recurring bottleneck when it was slow in at least 3 months and in at least half of the months that had enough visits. '
        . 'Trend compares the earlier half of the window with the later half and needs at least 3 forwarded visits in each.';
}

/**
 * Calendar months ending at $endMonth, oldest first. Each month is measured up to its last second, or up to $now for the current month.
 *
 * @return list<array{month:string, start:string, cutoff:string}>
 */
function smartflow_performance_months(string $endMonth, int $count, string $now): array
{
    $end = DateTimeImmutable::createFromFormat('!Y-m-d', $endMonth . '-01');
    $months = [];
    for ($back = $count - 1; $back >= 0; $back--) {
        $first = $end->modify("-{$back} months");
        $last = $first->format('Y-m-t 23:59:59');
        $months[] = ['month' => $first->format('Y-m'), 'start' => $first->format('Y-m-01 00:00:00'), 'cutoff' => min($last, $now)];
    }

    return $months;
}

function smartflow_performance_cell(): array
{
    return ['visits' => 0, 'forwarded' => 0, 'open' => 0, 'completed' => 0, 'seconds' => 0, 'late' => 0];
}

/**
 * Classifies every IN received in each month, as known at that month's cutoff.
 *
 * @param array<string, array{type:string, filed_at:?string, moves:list<array{office_id:int, office_code:string, status:string, scanned_at:string}>}> $folders moves oldest first
 * @param array<int, array<string,int>> $limits office id => lowercase folder type => desk limit in hours
 * @param list<array{month:string, start:string, cutoff:string}> $months
 * @return array{month: array<int, array<string, array>>, type: array<int, array<string, array>>}
 */
function smartflow_performance_visits(array $folders, array $limits, array $months, int $defaultHours): array
{
    $byMonth = [];
    $byType = [];
    foreach ($folders as $folder) {
        $type = (string)$folder['type'];
        $typeKey = strtolower(trim($type));
        foreach ($months as $month) {
            $known = [];
            foreach ($folder['moves'] as $movement) {
                if ($movement['scanned_at'] > $month['cutoff']) {
                    break;
                }
                $known[] = $movement;
            }
            $last = count($known) - 1;
            foreach ($known as $i => $in) {
                if ($in['status'] !== 'IN' || $in['scanned_at'] < $month['start']) {
                    continue;
                }
                $out = null;
                for ($j = $i + 1; $j <= $last; $j++) {
                    if ($known[$j]['status'] === 'OUT' && $known[$j]['office_id'] === $in['office_id']) {
                        $out = $known[$j];
                        break;
                    }
                }
                if ($out !== null) {
                    $kind = 'forwarded';
                    $end = $out['scanned_at'];
                } elseif ($i === $last && smartflow_report_trail_complete($known, $type, $folder['filed_at'], $month['cutoff'])) {
                    $kind = 'completed';
                    $filedAt = $folder['filed_at'];
                    $end = ($filedAt !== null && $filedAt <= $month['cutoff'] && $filedAt > $in['scanned_at']) ? $filedAt : $in['scanned_at'];
                } else {
                    $kind = 'open';
                    $end = $month['cutoff'];
                }
                $seconds = max(0, strtotime($end) - strtotime($in['scanned_at']));
                $limit = $limits[$in['office_id']][$typeKey] ?? $defaultHours;
                $late = $seconds > $limit * 3600;
                $cells = [&$byMonth[$in['office_id']][$month['month']], &$byType[$in['office_id']][$type]];
                foreach ($cells as &$cell) {
                    $cell ??= smartflow_performance_cell();
                    $cell['visits']++;
                    $cell[$kind]++;
                    if ($kind === 'forwarded') {
                        $cell['seconds'] += $seconds;
                    }
                    if ($late) {
                        $cell['late']++;
                    }
                }
                unset($cell);
            }
        }
    }

    return ['month' => $byMonth, 'type' => $byType];
}

function smartflow_performance_cell_view(array $cell): array
{
    return [
        'visits' => $cell['visits'],
        'forwarded' => $cell['forwarded'],
        'open' => $cell['open'],
        'completed' => $cell['completed'],
        'avg_hours' => smartflow_report_average_hours($cell['forwarded'], (float)$cell['seconds']),
        'late' => $cell['late'],
        'late_percent' => $cell['visits'] > 0 ? round($cell['late'] * 100 / $cell['visits'], 1) : null,
    ];
}

function smartflow_performance_add(array $a, array $b): array
{
    foreach ($a as $key => $value) {
        $a[$key] = $value + $b[$key];
    }

    return $a;
}

/** Earlier half versus later half of the window, by average hours of forwarded visits. */
function smartflow_performance_trend(array $cells, array $rules): array
{
    $half = intdiv(count($cells), 2);
    $earlier = $later = smartflow_performance_cell();
    foreach ($cells as $i => $cell) {
        if ($i < $half) {
            $earlier = smartflow_performance_add($earlier, $cell);
        } else {
            $later = smartflow_performance_add($later, $cell);
        }
    }
    $minimum = $rules['trend_min_forwarded'];
    if ($earlier['forwarded'] < $minimum || $later['forwarded'] < $minimum) {
        return ['direction' => 'insufficient', 'earlier_avg_hours' => null, 'later_avg_hours' => null, 'change_hours' => null];
    }
    $before = $earlier['seconds'] / $earlier['forwarded'] / 3600;
    $after = $later['seconds'] / $later['forwarded'] / 3600;
    $change = $after - $before;
    $direction = 'steady';
    if (abs($change) >= $rules['trend_min_change_hours'] && abs($change) * 100 >= $before * $rules['trend_min_change_percent']) {
        $direction = $change > 0 ? 'slower' : 'faster';
    }

    return ['direction' => $direction, 'earlier_avg_hours' => round($before, 1), 'later_avg_hours' => round($after, 1), 'change_hours' => round($change, 1)];
}

/**
 * @param list<array{id:int, code:string, name:string}> $offices
 * @param list<array{month:string, start:string, cutoff:string}> $months
 * @param array{month: array<int, array<string, array>>, type: array<int, array<string, array>>} $visits
 */
function smartflow_performance_report(array $offices, array $months, array $visits, array $rules): array
{
    $municipal = array_map(static fn () => smartflow_performance_cell(), $months);
    $rows = [];
    foreach ($offices as $office) {
        $cells = [];
        $series = [];
        $total = smartflow_performance_cell();
        $slowMonths = [];
        $activeMonths = 0;
        foreach ($months as $i => $month) {
            $cell = $visits['month'][$office['id']][$month['month']] ?? smartflow_performance_cell();
            $cells[] = $cell;
            $total = smartflow_performance_add($total, $cell);
            $municipal[$i] = smartflow_performance_add($municipal[$i], $cell);
            $enough = $cell['visits'] >= $rules['min_visits_per_month'];
            $slow = $enough && $cell['late'] * 100 >= $rules['slow_month_late_percent'] * $cell['visits'];
            $activeMonths += $enough ? 1 : 0;
            if ($slow) {
                $slowMonths[] = $month['month'];
            }
            $series[] = ['month' => $month['month']] + smartflow_performance_cell_view($cell) + ['slow' => $slow];
        }
        $recurring = count($slowMonths) >= $rules['recurring_slow_months'] && count($slowMonths) * 2 >= $activeMonths;
        $types = [];
        foreach ($visits['type'][$office['id']] ?? [] as $type => $cell) {
            $types[] = ['type' => (string)$type] + smartflow_performance_cell_view($cell);
        }
        usort($types, static fn (array $a, array $b) => [$b['late'], $b['avg_hours'] ?? -1, $a['type']] <=> [$a['late'], $a['avg_hours'] ?? -1, $b['type']]);
        $rows[] = [
            'office_id' => $office['id'], 'office_code' => $office['code'], 'office_name' => $office['name'],
            'months' => $series,
            'totals' => smartflow_performance_cell_view($total),
            'trend' => smartflow_performance_trend($cells, $rules),
            'bottleneck' => ['recurring' => $recurring, 'slow_months' => count($slowMonths), 'active_months' => $activeMonths, 'slow_month_list' => $slowMonths],
            'types' => array_slice($types, 0, 5),
        ];
    }
    $municipalTotal = smartflow_performance_cell();
    $municipalSeries = [];
    foreach ($months as $i => $month) {
        $municipalTotal = smartflow_performance_add($municipalTotal, $municipal[$i]);
        $municipalSeries[] = ['month' => $month['month']] + smartflow_performance_cell_view($municipal[$i]);
    }
    $bottlenecks = array_values(array_filter($rows, static fn (array $row) => $row['bottleneck']['recurring']));
    usort($bottlenecks, static fn (array $a, array $b) => [$b['totals']['late_percent'] ?? 0, $a['office_code']] <=> [$a['totals']['late_percent'] ?? 0, $b['office_code']]);

    return [
        'offices' => $rows,
        'municipal' => ['months' => $municipalSeries, 'totals' => smartflow_performance_cell_view($municipalTotal), 'trend' => smartflow_performance_trend($municipal, $rules)],
        'bottlenecks' => array_map(static fn (array $row) => [
            'office_id' => $row['office_id'], 'office_code' => $row['office_code'], 'office_name' => $row['office_name'],
            'slow_months' => $row['bottleneck']['slow_months'], 'active_months' => $row['bottleneck']['active_months'], 'late_percent' => $row['totals']['late_percent'],
        ], $bottlenecks),
    ];
}

/**
 * Folders with an IN in the window, with every movement up to the cutoff. Call inside the report snapshot transaction.
 *
 * @return array<string, array{type:string, filed_at:?string, moves:list<array{office_id:int, office_code:string, status:string, scanned_at:string}>}>
 */
function smartflow_performance_load_folders(PDO $pdo, string $windowStart, string $cutoff): array
{
    $stmt = $pdo->prepare("SELECT DISTINCT document_id FROM movements WHERE status = 'IN' AND scanned_at BETWEEN :start AND :end");
    $stmt->execute([':start' => $windowStart, ':end' => $cutoff]);
    $ids = array_map(static fn (array $row) => (string)$row['document_id'], $stmt->fetchAll());
    $folders = [];
    foreach (array_chunk($ids, 400) as $chunk) {
        $slots = implode(',', array_fill(0, count($chunk), '?'));
        $stmtDocs = $pdo->prepare("SELECT id, type, filed_at FROM documents WHERE id IN ($slots)");
        $stmtDocs->execute($chunk);
        foreach ($stmtDocs->fetchAll() as $row) {
            $folders[$row['id']] = ['type' => (string)$row['type'], 'filed_at' => $row['filed_at'], 'moves' => []];
        }
        $stmtMoves = $pdo->prepare("
            SELECT m.document_id, m.office_id, o.code AS office_code, m.status, m.scanned_at
            FROM movements m JOIN offices o ON o.id = m.office_id
            WHERE m.document_id IN ($slots) AND m.scanned_at <= ?
            ORDER BY m.document_id, m.scanned_at ASC, m.id ASC
        ");
        $stmtMoves->execute([...$chunk, $cutoff]);
        foreach ($stmtMoves->fetchAll() as $row) {
            if (isset($folders[$row['document_id']])) {
                $folders[$row['document_id']]['moves'][] = [
                    'office_id' => (int)$row['office_id'], 'office_code' => (string)$row['office_code'],
                    'status' => (string)$row['status'], 'scanned_at' => (string)$row['scanned_at'],
                ];
            }
        }
    }

    return $folders;
}

/** @return array<int, array<string,int>> office id => lowercase folder type => desk limit in hours (active rules only) */
function smartflow_performance_limits(PDO $pdo): array
{
    $limits = [];
    foreach ($pdo->query('SELECT office_id, document_type, max_hours FROM processing_thresholds WHERE is_active = 1')->fetchAll() as $row) {
        $limits[(int)$row['office_id']][strtolower(trim((string)$row['document_type']))] = (int)$row['max_hours'];
    }

    return $limits;
}
