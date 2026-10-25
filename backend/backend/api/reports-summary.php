<?php
// GET /reports-summary.php?month=2026-04&office_id=4
// GET /reports-summary.php?period=quarter&year=2026&quarter=2&office_id=4
// GET /reports-summary.php?period=year&year=2026&office_id=4
// Builds the COA Support Summary numbers (monthly, quarterly, or annual):
//   - compliance: receipt classifications, not financial or desk-deadline compliance
//   - office_totals: documents processed by each office in the month
//   - this_office: spotlight counts for the requesting office
// Auth: Bearer token required.

require __DIR__ . '/config.php';
require_once __DIR__ . '/report-period-helper.php';
require_once __DIR__ . '/report-export-helper.php';
require_once __DIR__ . '/report-register-helper.php';
require_once __DIR__ . '/report-metrics-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

$userId = require_user_id();

$stmtUser = $pdo->prepare('
    SELECT u.role, u.name, u.office_id, o.name AS office_name, o.code AS office_code
    FROM users u
    JOIN offices o ON o.id = u.office_id
    WHERE u.id = :id AND u.is_active = 1
    LIMIT 1
');
$stmtUser->execute([':id' => $userId]);
$caller = $stmtUser->fetch();
if (!$caller || $caller['role'] !== 'admin') {
    json_response([
        'success' => false,
        'message' => 'COA summaries are available to administrators only',
    ], 403);
}
$exportAllowed = strtoupper((string)$caller['office_code']) === 'ACC';
$format = $_GET['format'] ?? 'json';
if (!in_array($format, ['json', 'csv', 'print'], true)) json_response(['success' => false, 'message' => 'Invalid report format'], 400);
if ($format !== 'json' && !$exportAllowed) json_response(['success' => false, 'message' => 'Only Accounting administrators can export municipal summaries'], 403);

$officeId = (int)($_GET['office_id'] ?? 0);
if ($officeId <= 0) {
    json_response([
        'success' => false,
        'message' => 'office_id is required',
    ], 400);
}

$range = smartflow_report_period($_GET);
$period = $range['period'];
$month = $range['month'];
$quarter = $range['quarter'];
$year = $range['year'];
$monthStart = $range['start'];
$monthEnd = smartflow_report_as_of($_GET, $range);
$periodLabel = $range['label'];

// Schema checks run before the snapshot transaction because DDL commits implicitly.
smartflow_ensure_documents_filed_columns($pdo);

// Total documents that had any activity this month.
$pdo->exec('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
$pdo->beginTransaction();
$watermarks = smartflow_report_watermarks($pdo, $_GET);
$movementWatermark = $watermarks['movement_watermark'];
$stmtTotal = $pdo->prepare('
    SELECT COUNT(DISTINCT document_id) AS c
    FROM movements
    WHERE scanned_at BETWEEN :start AND :end AND id <= :watermark
');
$stmtTotal->execute([':start' => $monthStart, ':end' => $monthEnd, ':watermark' => $movementWatermark]);
$totalDocs = (int)($stmtTotal->fetch()['c'] ?? 0);

// Compliance (per document with activity this month):
//   on_time      — receive within 72h after an OUT, OR still IN at an office (not forwarded yet)
//   unforwarded  — latest movement is OUT (sent, awaiting receive scan elsewhere)
//   delayed      — received more than 72h after the preceding OUT
$stmtDocs = $pdo->prepare('
    SELECT DISTINCT document_id
    FROM movements
    WHERE scanned_at BETWEEN :start AND :end AND id <= :watermark
');
$stmtDocs->execute([':start' => $monthStart, ':end' => $monthEnd, ':watermark' => $movementWatermark]);
$docIds = array_map(fn($r) => $r['document_id'], $stmtDocs->fetchAll());

$onTime = 0;
$unforwarded = 0;
$delayed = 0;

foreach ($docIds as $docId) {
    $stmtMv = $pdo->prepare('
        SELECT status, scanned_at
        FROM movements
        WHERE document_id = :id AND scanned_at <= :end AND id <= :watermark
        ORDER BY scanned_at ASC, id ASC
    ');
    $stmtMv->execute([':id' => $docId, ':end' => $monthEnd, ':watermark' => $movementWatermark]);
    $mvs = $stmtMv->fetchAll();
    if (!$mvs) {
        continue;
    }

    match (smartflow_report_classification($mvs, $monthStart)) {
        'on_time' => $onTime++,
        'unforwarded' => $unforwarded++,
        default => $delayed++,
    };
}

// Completion at the cutoff for the same folders (additive: the classification above is unchanged).
$completedFolders = smartflow_report_completed_count($pdo, $docIds, $monthEnd, $movementWatermark);
$completionPercent = $totalDocs > 0 ? round($completedFolders * 100 / $totalDocs, 1) : null;

// Allocate rounding remainders so non-empty reports always total 100%.
$counts = [$onTime, $unforwarded, $delayed];
$percentages = [0, 0, 0];
if ($totalDocs > 0) {
    $remainders = [];
    foreach ($counts as $i => $count) {
        $exact = $count * 100 / $totalDocs;
        $percentages[$i] = (int)floor($exact);
        $remainders[$i] = $exact - $percentages[$i];
    }
    arsort($remainders);
    $missing = 100 - array_sum($percentages);
    foreach (array_keys($remainders) as $i) {
        if ($missing-- <= 0) break;
        $percentages[$i]++;
    }
}

// Office totals: count of distinct documents that touched each office this month.
$stmtOffices = $pdo->prepare('
    SELECT o.id, o.name, o.code,
           COUNT(DISTINCT m.document_id) AS docs_processed
    FROM offices o
    LEFT JOIN movements m
        ON m.office_id = o.id
       AND m.scanned_at BETWEEN :start AND :end
       AND m.id <= :watermark
    GROUP BY o.id, o.name, o.code
    ORDER BY o.name ASC
');
$stmtOffices->execute([':start' => $monthStart, ':end' => $monthEnd, ':watermark' => $movementWatermark]);
$officeStays = smartflow_report_office_stays($pdo, $monthStart, $monthEnd, $movementWatermark);
$offices = array_map(function ($r) use ($officeStays) {
    $stay = $officeStays[(int)$r['id']] ?? ['closed' => 0, 'open' => 0, 'seconds' => 0.0];
    return [
        'office_id'      => (int)$r['id'],
        'office_name'    => $r['name'],
        'office_code'    => $r['code'],
        'docs_processed' => (int)$r['docs_processed'],
        'forwarded_stays' => $stay['closed'],
        'open_stays'      => $stay['open'],
        'avg_hours_at_office' => smartflow_report_average_hours($stay['closed'], $stay['seconds']),
    ];
}, $stmtOffices->fetchAll());
$closedStaysTotal = array_sum(array_column($officeStays, 'closed'));

// Spotlight: the requesting office's headline number.
$stmtThis = $pdo->prepare('
    SELECT COUNT(DISTINCT document_id) AS c
    FROM movements
    WHERE office_id = :oid AND scanned_at BETWEEN :start AND :end AND id <= :watermark
');
$stmtThis->execute([':oid' => $officeId, ':start' => $monthStart, ':end' => $monthEnd, ':watermark' => $movementWatermark]);
$thisOfficeDocs = (int)($stmtThis->fetch()['c'] ?? 0);
$stmtOutstanding = $pdo->prepare("SELECT COUNT(*) AS total,
    COALESCE(SUM(latest.scanned_at < :start), 0) AS carried_forward
    FROM movements latest WHERE latest.status='OUT' AND latest.id=(
        SELECT m.id FROM movements m WHERE m.document_id=latest.document_id AND m.scanned_at <= :end AND m.id <= :watermark
        ORDER BY m.scanned_at DESC, m.id DESC LIMIT 1)");
$stmtOutstanding->execute([':start' => $monthStart, ':end' => $monthEnd, ':watermark' => $movementWatermark]);
$outstanding = $stmtOutstanding->fetch();
$registers = [];
if ($format !== 'json') {
    $registers['activity_register'] = smartflow_report_register($pdo, $monthStart, $monthEnd, ['scope' => 'activity', ...$watermarks], null)['documents'];
    $registers['outstanding_register'] = smartflow_report_register($pdo, $monthStart, $monthEnd, ['scope' => 'outstanding', ...$watermarks], null)['documents'];
}
$pdo->commit();

$report = [
    'success' => true,
    'period'  => $period,
    'month'   => $month,
    'quarter' => $quarter,
    'year'    => $year,
    'period_label' => $periodLabel,
    'office_id' => $officeId,
    'export_allowed' => $exportAllowed,
    'generated_at' => date('Y-m-d H:i:s'),
    'timezone' => date_default_timezone_get(),
    'period_start' => $monthStart,
    'period_end' => $monthEnd,
    'as_of' => $monthEnd,
    ...$watermarks,
    'classification_note' => smartflow_report_classification_note(),
    'classification_basis' => ['receipt_hours' => 72, 'hours_basis' => 'Calendar hours', 'late_receipt_takes_precedence' => true],
    'outstanding_transfers' => (int)$outstanding['total'],
    'carried_forward_transfers' => (int)$outstanding['carried_forward'],
    'scope' => 'Municipal system (all offices)',
    'prepared_by' => $caller['name'] . ' · ' . $caller['office_name'],
    'submission_note' => match ($period) {
        'year'    => 'Annual custody summary for COA preparation — pair with the monthly DV and collection reports already submitted.',
        'quarter' => 'Quarterly custody summary for COA preparation — covers the three monthly DV and collection report periods.',
        default   => 'DV and collection reports are typically submitted by the 10th day of the following month (client practice).',
    },
    'totals' => [
        'documents_in_period' => $totalDocs,
        'this_office_documents' => $thisOfficeDocs,
    ],
    'compliance' => [
        'on_time' => [
            'count'   => $onTime,
            'percent' => $percentages[0],
        ],
        'unforwarded' => [
            'count'   => $unforwarded,
            'percent' => $percentages[1],
        ],
        'delayed' => [
            'count'   => $delayed,
            'percent' => $percentages[2],
        ],
    ],
    'completion' => [
        'completed' => $completedFolders,
        'of'        => $totalDocs,
        'percent'   => $completionPercent,
        'basis'     => smartflow_report_completion_note(),
    ],
    'processing_time' => [
        'average_hours'   => smartflow_report_average_hours($closedStaysTotal, (float)array_sum(array_column($officeStays, 'seconds'))),
        'forwarded_stays' => $closedStaysTotal,
        'open_stays'      => array_sum(array_column($officeStays, 'open')),
        'basis'           => smartflow_report_processing_note(),
    ],
    'office_totals' => $offices,
    ...$registers,
];
header('Cache-Control: no-store');
if ($format === 'csv') {
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="SmartFlow-custody-' . date('Ymd', strtotime($monthStart)) . '-' . $period . '.csv"');
    echo smartflow_report_csv($report);
    exit;
}
if ($format === 'print') {
    header('Content-Type: text/html; charset=utf-8');
    header('Referrer-Policy: no-referrer');
    echo smartflow_report_print($report);
    exit;
}
json_response($report);
