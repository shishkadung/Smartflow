<?php
// GET /system-status.php
// Municipal system health + operations snapshot (admin).
// Auth: Bearer token required.

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';
require_once __DIR__ . '/thresholds-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$adminId = require_user_id();
smartflow_require_admin($pdo, $adminId);
smartflow_ensure_users_active_column($pdo);

$checkedAt = date('Y-m-d H:i:s');
$monthStart = date('Y-m-01 00:00:00');
$monthEnd   = date('Y-m-t 23:59:59', strtotime($monthStart));
$todayStart = date('Y-m-d 00:00:00');
$maxInHours = 48;
$maxOutHours = 24;

$apiOnline = true;
$dbConnected = isset($pdo);

$mysqlVersion = null;
try {
    $mysqlVersion = (string)$pdo->query('SELECT VERSION()')->fetchColumn();
} catch (Throwable $e) {
    $mysqlVersion = null;
}

$roleCounts = [];
$stmtUsers = $pdo->query('
    SELECT role, is_active, COUNT(*) AS c
    FROM users
    GROUP BY role, is_active
');
$activeUsers = 0;
$inactiveUsers = 0;
foreach ($stmtUsers->fetchAll() as $row) {
    $role = (string)$row['role'];
    $count = (int)$row['c'];
    if (!isset($roleCounts[$role])) {
        $roleCounts[$role] = 0;
    }
    $roleCounts[$role] += $count;
    if ((int)$row['is_active']) {
        $activeUsers += $count;
    } else {
        $inactiveUsers += $count;
    }
}

$pendingSignups = (int)($pdo->query("
    SELECT COUNT(*) FROM signup_requests WHERE status = 'pending'
")->fetchColumn() ?: 0);

$documentCount = (int)($pdo->query('SELECT COUNT(*) FROM documents')->fetchColumn() ?: 0);

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
$activeDocuments = (int)($stmtActive->fetch()['c'] ?? 0);

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
$stmtOverdue->execute([':maxh' => $maxInHours]);
$overdueIn = (int)($stmtOverdue->fetch()['c'] ?? 0);

$stmtOut = $pdo->prepare("
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
    WHERE t.last_status = 'OUT'
      AND TIMESTAMPDIFF(HOUR, t.last_scanned, NOW()) >= :maxh
");
$stmtOut->execute([':maxh' => $maxOutHours]);
$unconfirmedOut = (int)($stmtOut->fetch()['c'] ?? 0);

$stmtMovToday = $pdo->prepare('SELECT COUNT(*) FROM movements WHERE scanned_at >= :start');
$stmtMovToday->execute([':start' => $todayStart]);
$movementsToday = (int)$stmtMovToday->fetchColumn();

$stmtMovMonth = $pdo->prepare('
    SELECT COUNT(*) FROM movements WHERE scanned_at BETWEEN :start AND :end
');
$stmtMovMonth->execute([':start' => $monthStart, ':end' => $monthEnd]);
$movementsThisMonth = (int)$stmtMovMonth->fetchColumn();

$officeSnapshot = [];
$stmtOffices = $pdo->query("
    SELECT o.id, o.code, o.name, COALESCE(t.in_office, 0) AS in_office
    FROM offices o
    LEFT JOIN (
        SELECT latest.office_id, COUNT(*) AS in_office
        FROM (
            SELECT m.document_id, m.status, m.office_id
            FROM movements m
            WHERE m.id = (
                SELECT m2.id FROM movements m2
                WHERE m2.document_id = m.document_id
                ORDER BY m2.scanned_at DESC, m2.id DESC
                LIMIT 1
            )
        ) latest
        WHERE latest.status = 'IN'
        GROUP BY latest.office_id
    ) t ON t.office_id = o.id
    ORDER BY o.name ASC
");
foreach ($stmtOffices->fetchAll() as $row) {
    $officeSnapshot[] = [
        'office_id'   => (int)$row['id'],
        'office_code' => $row['code'],
        'office_name' => $row['name'],
        'in_office'   => (int)$row['in_office'],
    ];
}

$issues = 0;
if (!$dbConnected) {
    $issues++;
}
if ($overdueIn > 0) {
    $issues += $overdueIn;
}
if ($unconfirmedOut > 0) {
    $issues += $unconfirmedOut;
}
if ($pendingSignups > 0) {
    $issues += $pendingSignups;
}

json_response([
    'success' => true,
    'checked_at' => $checkedAt,
    'checked_at_display' => date('M j, Y g:i A', strtotime($checkedAt)),
    'status' => [
        'api'                => $apiOnline ? 'Online' : 'Offline',
        'database'           => $dbConnected ? 'Connected' : 'Disconnected',
        'documents'          => $documentCount,
        'php_version'        => PHP_VERSION,
        'mysql_version'      => $mysqlVersion,
        'health'             => $issues === 0 ? 'healthy' : ($overdueIn + $unconfirmedOut > 0 ? 'attention' : 'ok'),
    ],
    'role_counts' => $roleCounts,
    'users' => [
        'active'   => $activeUsers,
        'inactive' => $inactiveUsers,
        'total'    => $activeUsers + $inactiveUsers,
    ],
    'operations' => [
        'active_documents'    => $activeDocuments,
        'overdue_in_office'   => $overdueIn,
        'unconfirmed_out'     => $unconfirmedOut,
        'flagged_total'       => $overdueIn + $unconfirmedOut,
        'movements_today'     => $movementsToday,
        'movements_this_month'=> $movementsThisMonth,
        'pending_signups'     => $pendingSignups,
        'month'               => date('Y-m'),
    ],
    'office_snapshot' => $officeSnapshot,
]);
