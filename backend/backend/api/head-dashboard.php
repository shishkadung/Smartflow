<?php
// GET /head-dashboard.php?office_id=1
// Department head: office-scoped stats + document queue (monitor only, no scan).
// Auth: Bearer token required.

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
if ($officeId <= 0) {
    json_response(['success' => false, 'message' => 'office_id is required'], 400);
}

smartflow_require_office_scope($pdo, $userId, $officeId);

$monthStart = date('Y-m-01 00:00:00');
$stmtAvg = $pdo->prepare("
    SELECT AVG(hours_at) AS avg_h
    FROM (
        SELECT TIMESTAMPDIFF(HOUR, m.scanned_at,
            COALESCE(
                (SELECT MIN(m2.scanned_at)
                 FROM movements m2
                 WHERE m2.document_id = m.document_id
                   AND m2.scanned_at > m.scanned_at
                   AND m2.status = 'OUT'
                   AND m2.office_id = m.office_id),
                NOW()
            )
        ) AS hours_at
        FROM movements m
        WHERE m.office_id = :oid
          AND m.status = 'IN'
          AND m.scanned_at >= :start
    ) sub
");
$stmtAvg->execute([':oid' => $officeId, ':start' => $monthStart]);
$avgRow = $stmtAvg->fetch();
$avgHours = $avgRow && $avgRow['avg_h'] !== null
    ? round((float)$avgRow['avg_h'], 1)
    : 0.0;

$queueTrailCompleteSql = smartflow_sql_trail_complete('d.id');
$sqlQueue = "
    SELECT
        d.id AS document_id,
        {$queueTrailCompleteSql} AS trail_complete,
        d.title,
        d.type,
        d.due_at AS document_due_at,
        latest.status        AS last_status,
        latest.office_id     AS last_office_id,
        latest.office_name   AS last_office_name,
        latest.office_code   AS last_office_code,
        latest.scanned_at    AS last_scanned_at,
        TIMESTAMPDIFF(HOUR, latest.scanned_at, NOW()) AS hours_pending
    FROM documents d
    JOIN (
        SELECT m.document_id, m.status, m.office_id, m.scanned_at,
               o.name AS office_name, o.code AS office_code
        FROM movements m
        JOIN offices o ON o.id = m.office_id
        WHERE m.id = (
            SELECT m2.id FROM movements m2
            WHERE m2.document_id = m.document_id
            ORDER BY m2.scanned_at DESC, m2.id DESC LIMIT 1
        )
    ) latest ON latest.document_id = d.id
    WHERE
        (latest.status = 'IN' AND latest.office_id = :oid_in)
     OR (latest.status = 'OUT' AND latest.office_id = :oid_out)
    ORDER BY latest.scanned_at DESC, d.id DESC
";
$stmtQueue = $pdo->prepare($sqlQueue);
$stmtQueue->execute([':oid_in' => $officeId, ':oid_out' => $officeId]);
$rows = $stmtQueue->fetchAll();

$queue = array_map(function ($r) use ($pdo, $officeId) {
    $hours = (int)$r['hours_pending'];
    $inOffice = ($r['last_status'] === 'IN' && (int)$r['last_office_id'] === $officeId);
    $manualDue = $r['document_due_at'] !== null ? (string)$r['document_due_at'] : null;
    $dueInfo = smartflow_document_due(
        $pdo,
        (string)$r['type'],
        (string)$r['last_status'],
        (int)$r['last_office_id'],
        (string)$r['last_scanned_at'],
        $manualDue
    );
    $maxHours = (int)$dueInfo['max_hours'];
    $dueAt = $dueInfo['due_at'] !== '' ? $dueInfo['due_at'] : null;
    $trailComplete = (int)$r['trail_complete'] === 1;
    $isOverdue = !$trailComplete && $dueInfo['is_overdue'] && ($inOffice || $dueInfo['is_manual_due']);

    if ($trailComplete) {
        $statusLabel = 'completed';
        $pill = 'Completed';
        $meta = "Trail complete · filed at {$r['last_office_code']}";
        $dueAt = null;
        $maxHours = 0;
    } elseif ($isOverdue) {
        $statusLabel = 'overdue';
        $pill = 'Overdue';
        $meta = $dueInfo['is_manual_due']
            ? 'Document due ' . $dueInfo['due_at_display']
            : "{$hours}h at {$r['last_office_code']} · due " . smartflow_due_at_display((string)$dueAt);
    } elseif ($inOffice) {
        $statusLabel = 'in_office';
        $pill = 'In office';
        $meta = $dueAt !== null && $dueInfo['due_at_display'] !== '—'
            ? "{$hours}h at {$r['last_office_code']} · due {$dueInfo['due_at_display']}"
            : "{$hours}h at {$r['last_office_code']} · within threshold";
    } elseif ($r['last_status'] === 'OUT' && (int)$r['last_office_id'] === $officeId) {
        $statusLabel = 'on_time';
        $pill = 'On time';
        $dest = $r['last_office_code'];
        $meta = "Forwarded from {$dest} · awaiting receive scan";
    } else {
        $statusLabel = 'on_time';
        $pill = 'On time';
        $meta = "At {$r['last_office_name']}";
    }

    return [
        'document_id'   => $r['document_id'],
        'title'         => $r['title'],
        'type'          => $r['type'],
        'status_label'  => $statusLabel,
        'status_pill'   => $pill,
        'meta'          => $meta,
        'hours_pending' => $hours,
        'last_status'   => $r['last_status'],
        'due_at'        => $dueAt,
        'max_hours'     => $maxHours,
    ];
}, $rows);

$inOfficeCount = 0;
$overdueCount = 0;
foreach ($queue as $item) {
    if ($item['status_label'] === 'in_office') {
        $inOfficeCount++;
    }
    if ($item['status_label'] === 'overdue') {
        $overdueCount++;
    }
}

$today = date('Y-m-d');
$stmtRecent = $pdo->prepare("
    SELECT m.document_id, m.status, m.scanned_at, m.remarks,
           d.title, u.name AS user_name
    FROM movements m
    JOIN documents d ON d.id = m.document_id
    JOIN users u ON u.id = m.user_id
    WHERE m.office_id = :oid AND DATE(m.scanned_at) = :today
    ORDER BY m.scanned_at DESC, m.id DESC
    LIMIT 8
");
$stmtRecent->execute([':oid' => $officeId, ':today' => $today]);
$recentMovements = array_map(static function ($r) {
    return [
        'document_id' => $r['document_id'],
        'title'       => $r['title'],
        'status'      => $r['status'],
        'scanned_at'  => $r['scanned_at'],
        'remarks'     => $r['remarks'],
        'user_name'   => $r['user_name'],
    ];
}, $stmtRecent->fetchAll());

json_response([
    'success'   => true,
    'office_id' => $officeId,
    'stats' => [
        'in_office' => $inOfficeCount,
        'overdue'   => $overdueCount,
        'avg_hours' => $avgHours,
    ],
    'queue' => $queue,
    'recent_movements' => $recentMovements,
]);
