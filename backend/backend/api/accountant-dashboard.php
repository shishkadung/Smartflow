<?php
// GET /accountant-dashboard.php
// Municipal-wide dashboard for Municipal Accountant / System Administrator.
// Auth: Bearer token required.

require __DIR__ . '/config.php';
require_once __DIR__ . '/routing-helper.php';
smartflow_ensure_documents_filed_columns($pdo);
require_once __DIR__ . '/thresholds-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

smartflow_require_admin($pdo, require_user_id());

$monthStart = date('Y-m-01 00:00:00');
$monthEnd   = date('Y-m-t 23:59:59', strtotime($monthStart));
smartflow_ensure_processing_thresholds($pdo);
smartflow_ensure_documents_due_column($pdo);
$trailCompleteSql = smartflow_sql_trail_complete('d.id');

$stmtOffices = $pdo->prepare('
    SELECT o.id, o.name, o.code,
           COUNT(DISTINCT m.document_id) AS docs_processed
    FROM offices o
    LEFT JOIN movements m
        ON m.office_id = o.id
       AND m.scanned_at BETWEEN :start AND :end
    GROUP BY o.id, o.name, o.code
    ORDER BY o.name ASC
');
$stmtOffices->execute([':start' => $monthStart, ':end' => $monthEnd]);
$offices = $stmtOffices->fetchAll();

$perOffice = [];
$activeDocs = 0;
$overdue = 0;
// Use one latest-custody snapshot for both municipal and office counts.
// Manual due dates win; expired OUT thresholds remain "unconfirmed" alerts,
// rather than processing-overdue counts. Completed trails have no deadline.
$stmtPerOffice = $pdo->prepare("
    SELECT latest.office_id,
           SUM(CASE WHEN latest.status = 'IN' THEN 1 ELSE 0 END) AS in_office,
           SUM(CASE
               WHEN d.due_at IS NOT NULL THEN NOW() > d.due_at
               WHEN latest.status = 'IN' THEN
                   NOW() > DATE_ADD(latest.scanned_at, INTERVAL COALESCE(pt.max_hours, :default_hours) HOUR)
               ELSE 0
           END) AS overdue
    FROM documents d
    JOIN movements latest ON latest.id = (
        SELECT m.id FROM movements m
        WHERE m.document_id = d.id
        ORDER BY m.scanned_at DESC, m.id DESC LIMIT 1
    )
    LEFT JOIN processing_thresholds pt
        ON pt.office_id = latest.office_id
       AND pt.document_type = d.type
       AND pt.is_active = 1
    WHERE latest.status IN ('IN', 'OUT')
      AND NOT {$trailCompleteSql}
    GROUP BY latest.office_id
");
$stmtPerOffice->execute([':default_hours' => smartflow_threshold_defaults()['max_hours']]);
foreach ($stmtPerOffice->fetchAll() as $row) {
    $oid = (int)$row['office_id'];
    $perOffice[$oid] = [
        'in_office' => (int)$row['in_office'],
        'overdue'   => (int)$row['overdue'],
    ];
    $activeDocs += $perOffice[$oid]['in_office'];
    $overdue += $perOffice[$oid]['overdue'];
}

$officeTotals = array_map(function ($r) use ($perOffice) {
    $oid = (int)$r['id'];
    $live = $perOffice[$oid] ?? ['in_office' => 0, 'overdue' => 0];
    return [
        'office_id'      => $oid,
        'office_name'    => $r['name'],
        'office_code'    => $r['code'],
        'docs_processed' => (int)$r['docs_processed'],
        'in_office'      => $live['in_office'],
        'overdue'        => $live['overdue'],
    ];
}, $offices);

$pendingSignups = (int)($pdo->query("
    SELECT COUNT(*) FROM signup_requests WHERE status = 'pending'
")->fetchColumn() ?: 0);

json_response([
    'success' => true,
    'stats' => [
        'active_documents' => $activeDocs,
        'overdue'          => $overdue,
        'pilot_offices'    => count($officeTotals),
        'pending_signups'  => $pendingSignups,
    ],
    'office_totals' => $officeTotals,
    'month' => date('Y-m'),
]);
