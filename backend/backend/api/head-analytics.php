<?php
// GET /head-analytics.php?office_id=1&month=2026-05
// Office performance: each document belongs to exactly one category per month.

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/routing-helper.php';
smartflow_ensure_documents_filed_columns($pdo);
require_once __DIR__ . '/office-access-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}
$userId = require_user_id();
$officeId = (int)($_GET['office_id'] ?? 0);
$month = trim((string)($_GET['month'] ?? date('Y-m')));
if ($officeId <= 0) {
    json_response(['success' => false, 'message' => 'office_id is required'], 400);
}
smartflow_require_office_scope($pdo, $userId, $officeId);
if (!preg_match('/^(\d{4})-(0[1-9]|1[0-2])$/', $month, $parts) || (int)$parts[1] < 1000) {
    json_response(['success' => false, 'message' => 'month must be a valid YYYY-MM'], 400);
}
$monthStart = $month . '-01 00:00:00';
$monthEnd = date('Y-m-t 23:59:59', strtotime($monthStart));
smartflow_ensure_processing_thresholds($pdo);
$trailCompleteSql = smartflow_sql_trail_complete('m.document_id');

// Pair each IN visit with its first following OUT. IDs break ties when both
// scans occur in the same second. Only the final visit can end by completion:
// explicit filing uses its recorded time; fixed routes finish on final receipt.
$visitsSql = "
    SELECT m.document_id, m.scanned_at AS in_scanned_at,
           COALESCE((
               SELECT m2.scanned_at FROM movements m2
               WHERE m2.document_id = m.document_id
                 AND m2.office_id = m.office_id AND m2.status = 'OUT'
                 AND (m2.scanned_at > m.scanned_at
                      OR (m2.scanned_at = m.scanned_at AND m2.id > m.id))
               ORDER BY m2.scanned_at, m2.id LIMIT 1
           ), CASE WHEN m.id = (
               SELECT last_m.id FROM movements last_m
               WHERE last_m.document_id = m.document_id
               ORDER BY last_m.scanned_at DESC, last_m.id DESC LIMIT 1
           ) AND {$trailCompleteSql} THEN COALESCE(d.filed_at, m.scanned_at) END) AS out_scanned_at,
           COALESCE(pt.max_hours, :default_hours) AS max_hours
    FROM movements m
    JOIN documents d ON d.id = m.document_id
    LEFT JOIN processing_thresholds pt
        ON pt.office_id = m.office_id AND pt.document_type = d.type AND pt.is_active = 1
    WHERE m.office_id = :oid AND m.status = 'IN'
      AND m.scanned_at BETWEEN :start AND :end
";
// A late visit takes priority over an open visit, which takes priority over
// completed on-time visits. Returns therefore cannot count in two categories.
$documentsSql = "
    SELECT v.document_id,
           MAX(CASE WHEN COALESCE(v.out_scanned_at, NOW()) >
               DATE_ADD(v.in_scanned_at, INTERVAL v.max_hours HOUR) THEN 1 ELSE 0 END) AS is_delayed,
           MAX(v.out_scanned_at IS NULL) AS is_unforwarded,
           MAX(TIMESTAMPDIFF(SECOND, v.in_scanned_at,
               COALESCE(v.out_scanned_at, NOW()))) AS seconds_at
    FROM ({$visitsSql}) v
    GROUP BY v.document_id
";
$bindings = [':oid' => $officeId, ':start' => $monthStart, ':end' => $monthEnd,
    ':default_hours' => smartflow_threshold_defaults()['max_hours']];
$stmt = $pdo->prepare("SELECT COUNT(*) AS processed,
    COALESCE(SUM(is_delayed), 0) AS delayed_count,
    COALESCE(SUM(CASE WHEN is_delayed = 0 AND is_unforwarded = 1 THEN 1 ELSE 0 END), 0) AS unforwarded_count,
    COALESCE(SUM(CASE WHEN is_delayed = 0 AND is_unforwarded = 0 THEN 1 ELSE 0 END), 0) AS on_time_count
    FROM ({$documentsSql}) classified");
$stmt->execute($bindings);
$counts = $stmt->fetch();
$processed = (int)$counts['processed'];
$categories = ['on_time' => (int)$counts['on_time_count'],
    'unforwarded' => (int)$counts['unforwarded_count'], 'delayed' => (int)$counts['delayed_count']];

// Allocate rounding remainders so populated percentage tiles total exactly 100.
$percentages = []; $remainders = [];
foreach ($categories as $key => $count) {
    $percentages[$key] = $processed > 0 ? intdiv($count * 100, $processed) : 0;
    $remainders[$key] = $processed > 0 ? ($count * 100) % $processed : 0;
}
if ($processed > 0) {
    arsort($remainders, SORT_NUMERIC);
    $remaining = 100 - array_sum($percentages);
    foreach (array_keys($remainders) as $key) {
        if ($remaining-- <= 0) break;
        $percentages[$key]++;
    }
}

$stmtSlow = $pdo->prepare("SELECT document_id, FLOOR(seconds_at / 3600) AS hours_at
    FROM ({$documentsSql}) classified WHERE is_delayed = 1
    ORDER BY seconds_at DESC, document_id LIMIT 10");
$stmtSlow->execute($bindings);
$slowDocs = array_map(static fn ($r) => [
    'document_id' => $r['document_id'], 'hours' => (int)$r['hours_at'],
], $stmtSlow->fetchAll());

json_response([
    'success' => true, 'office_id' => $officeId, 'month' => $month,
    'stats' => [
        'processed' => $processed,
        'late_count' => $categories['delayed'], // Flutter compatibility.
        'on_time_count' => $categories['on_time'],
        'unforwarded_count' => $categories['unforwarded'],
        'delayed_count' => $categories['delayed'],
        'on_time_percent' => $percentages['on_time'],
        'unforwarded_percent' => $percentages['unforwarded'],
        'delayed_percent' => $percentages['delayed'],
    ],
    'slow_documents' => $slowDocs,
]);
