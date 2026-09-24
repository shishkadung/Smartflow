<?php
// GET /accountant-dashboard.php
// Municipal-wide dashboard for Municipal Accountant / System Administrator.
// Auth: Bearer token required.

require __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

require_user_id();

$monthStart = date('Y-m-01 00:00:00');
$monthEnd   = date('Y-m-t 23:59:59', strtotime($monthStart));
$maxHours   = 48;

$stmtActive = $pdo->query("
    SELECT COUNT(*) AS c
    FROM (
        SELECT m.document_id,
               (SELECT m2.status FROM movements m2
                WHERE m2.document_id = m.document_id
                ORDER BY m2.scanned_at DESC, m2.id DESC LIMIT 1) AS last_status
        FROM movements m
        GROUP BY m.document_id
    ) t
    WHERE t.last_status = 'IN'
");
$activeDocs = (int)($stmtActive->fetch()['c'] ?? 0);

$stmtOverdue = $pdo->prepare("
    SELECT COUNT(DISTINCT t.document_id) AS c
    FROM (
        SELECT m.document_id,
               (SELECT m2.status FROM movements m2
                WHERE m2.document_id = m.document_id
                ORDER BY m2.scanned_at DESC, m2.id DESC LIMIT 1) AS last_status,
               (SELECT m2.scanned_at FROM movements m2
                WHERE m2.document_id = m.document_id
                ORDER BY m2.scanned_at DESC, m2.id DESC LIMIT 1) AS last_scanned
        FROM movements m
        GROUP BY m.document_id
    ) t
    WHERE t.last_status = 'IN'
      AND TIMESTAMPDIFF(HOUR, t.last_scanned, NOW()) >= :maxh
");
$stmtOverdue->execute([':maxh' => $maxHours]);
$overdue = (int)($stmtOverdue->fetch()['c'] ?? 0);

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
$stmtPerOffice = $pdo->prepare("
    SELECT t.last_office AS office_id,
           COUNT(*) AS in_office,
           SUM(CASE WHEN TIMESTAMPDIFF(HOUR, t.last_scanned, NOW()) >= :maxh THEN 1 ELSE 0 END) AS overdue
    FROM (
        SELECT m.document_id,
               (SELECT m2.status FROM movements m2
                WHERE m2.document_id = m.document_id
                ORDER BY m2.scanned_at DESC, m2.id DESC LIMIT 1) AS last_status,
               (SELECT m2.office_id FROM movements m2
                WHERE m2.document_id = m.document_id
                ORDER BY m2.scanned_at DESC, m2.id DESC LIMIT 1) AS last_office,
               (SELECT m2.scanned_at FROM movements m2
                WHERE m2.document_id = m.document_id
                ORDER BY m2.scanned_at DESC, m2.id DESC LIMIT 1) AS last_scanned
        FROM movements m
        GROUP BY m.document_id
    ) t
    WHERE t.last_status = 'IN'
    GROUP BY t.last_office
");
$stmtPerOffice->execute([':maxh' => $maxHours]);
foreach ($stmtPerOffice->fetchAll() as $row) {
    $oid = (int)$row['office_id'];
    $perOffice[$oid] = [
        'in_office' => (int)$row['in_office'],
        'overdue'   => (int)$row['overdue'],
    ];
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
