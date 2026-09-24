<?php
// GET /audit-scans.php
// QR / scan audit monitor for municipal admin (movement.scan + qr.verify).
//
// Query:
//   hours=48          (1–168, default 48)
//   office_id=        optional filter
//   user_id=          optional filter
//   outcome=          all|success|rejected (default all)
//   format=json|csv   default json
//   limit=200         max rows (cap 500)
//
// Auth: admin only (Bearer).

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$adminId = require_user_id();
smartflow_require_admin($pdo, $adminId);

$hours = max(1, min(168, (int)($_GET['hours'] ?? 48)));
$officeId = isset($_GET['office_id']) ? (int)$_GET['office_id'] : 0;
$userIdFilter = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
$outcome = strtolower(trim((string)($_GET['outcome'] ?? 'all')));
$format = strtolower(trim((string)($_GET['format'] ?? 'json')));
$limit = max(1, min(500, (int)($_GET['limit'] ?? 200)));

if (!in_array($outcome, ['all', 'success', 'rejected'], true)) {
    json_response(['success' => false, 'message' => 'Invalid outcome filter'], 400);
}

$cutoff = date('Y-m-d H:i:s', time() - ($hours * 3600));

$sql = '
    SELECT a.id, a.event_type, a.document_id, a.user_id, a.office_id, a.status,
           a.outcome, a.message, a.meta_json, a.created_at,
           u.name AS user_name, u.username,
           o.code AS office_code, o.name AS office_name
    FROM audit_logs a
    LEFT JOIN users u ON u.id = a.user_id
    LEFT JOIN offices o ON o.id = a.office_id
    WHERE a.event_type IN (\'movement.scan\', \'qr.verify\')
      AND a.created_at >= :cutoff
';
$params = [':cutoff' => $cutoff];

if ($officeId > 0) {
    $sql .= ' AND a.office_id = :office_id';
    $params[':office_id'] = $officeId;
}
if ($userIdFilter > 0) {
    $sql .= ' AND a.user_id = :user_id';
    $params[':user_id'] = $userIdFilter;
}
if ($outcome !== 'all') {
    $sql .= ' AND a.outcome = :outcome';
    $params[':outcome'] = $outcome;
}

$sql .= ' ORDER BY a.created_at DESC LIMIT ' . $limit;

$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$rows = $stmt->fetchAll();

$events = [];
foreach ($rows as $row) {
    $meta = null;
    if (!empty($row['meta_json'])) {
        $decoded = json_decode((string)$row['meta_json'], true);
        if (is_array($decoded)) {
            $meta = $decoded;
        }
    }
    $scanError = is_array($meta) ? ($meta['scan_error'] ?? $meta['qr_reason'] ?? null) : null;

    $events[] = [
        'id'           => (int)$row['id'],
        'event_type'   => (string)$row['event_type'],
        'document_id'  => $row['document_id'],
        'user_id'      => $row['user_id'] !== null ? (int)$row['user_id'] : null,
        'user_name'    => $row['user_name'],
        'username'     => $row['username'],
        'office_id'    => $row['office_id'] !== null ? (int)$row['office_id'] : null,
        'office_code'  => $row['office_code'],
        'office_name'  => $row['office_name'],
        'status'       => $row['status'],
        'outcome'      => (string)$row['outcome'],
        'message'      => (string)$row['message'],
        'scan_error'   => $scanError,
        'created_at'   => (string)$row['created_at'],
    ];
}

// Summary counts (same window, ignoring outcome filter for headline stats).
$stmtSum = $pdo->prepare('
    SELECT outcome, COUNT(*) AS cnt
    FROM audit_logs
    WHERE event_type IN (\'movement.scan\', \'qr.verify\')
      AND created_at >= :cutoff
    GROUP BY outcome
');
$stmtSum->execute([':cutoff' => $cutoff]);
$accepted = 0;
$rejected = 0;
foreach ($stmtSum->fetchAll() as $sumRow) {
    if ($sumRow['outcome'] === 'success') {
        $accepted = (int)$sumRow['cnt'];
    } elseif ($sumRow['outcome'] === 'rejected') {
        $rejected = (int)$sumRow['cnt'];
    }
}

// Top reject reasons from meta_json (movement.scan + qr.verify rejects).
$stmtReasons = $pdo->prepare('
    SELECT meta_json
    FROM audit_logs
    WHERE event_type IN (\'movement.scan\', \'qr.verify\')
      AND outcome = \'rejected\'
      AND created_at >= :cutoff
      AND meta_json IS NOT NULL
    ORDER BY created_at DESC
    LIMIT 300
');
$stmtReasons->execute([':cutoff' => $cutoff]);
$reasonCounts = [];
foreach ($stmtReasons->fetchAll() as $r) {
    $meta = json_decode((string)$r['meta_json'], true);
    if (!is_array($meta)) {
        continue;
    }
    $code = (string)($meta['scan_error'] ?? $meta['qr_reason'] ?? 'unknown');
    $reasonCounts[$code] = ($reasonCounts[$code] ?? 0) + 1;
}
arsort($reasonCounts);
$topReasons = [];
foreach (array_slice($reasonCounts, 0, 8, true) as $code => $cnt) {
    $topReasons[] = ['code' => $code, 'count' => $cnt];
}

// Suspicious: users with 3+ rejected scans in window.
$stmtSuspicious = $pdo->prepare('
    SELECT a.user_id, u.name AS user_name, u.username, o.code AS office_code,
           COUNT(*) AS reject_count
    FROM audit_logs a
    LEFT JOIN users u ON u.id = a.user_id
    LEFT JOIN offices o ON o.id = a.office_id
    WHERE a.event_type IN (\'movement.scan\', \'qr.verify\')
      AND a.outcome = \'rejected\'
      AND a.created_at >= :cutoff
      AND a.user_id IS NOT NULL
    GROUP BY a.user_id, u.name, u.username, o.code
    HAVING reject_count >= 3
    ORDER BY reject_count DESC
    LIMIT 10
');
$stmtSuspicious->execute([':cutoff' => $cutoff]);
$suspicious = [];
foreach ($stmtSuspicious->fetchAll() as $s) {
    $suspicious[] = [
        'user_id'       => (int)$s['user_id'],
        'user_name'     => $s['user_name'],
        'username'      => $s['username'],
        'office_code'   => $s['office_code'],
        'reject_count'  => (int)$s['reject_count'],
    ];
}

if ($format === 'csv') {
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="smartflow-scan-audit.csv"');
    $out = fopen('php://output', 'w');
    fputcsv($out, [
        'created_at', 'outcome', 'event_type', 'document_id', 'status',
        'office_code', 'user_name', 'username', 'message', 'scan_error',
    ]);
    foreach ($events as $ev) {
        fputcsv($out, [
            $ev['created_at'],
            $ev['outcome'],
            $ev['event_type'],
            $ev['document_id'] ?? '',
            $ev['status'] ?? '',
            $ev['office_code'] ?? '',
            $ev['user_name'] ?? '',
            $ev['username'] ?? '',
            $ev['message'],
            $ev['scan_error'] ?? '',
        ]);
    }
    fclose($out);
    exit;
}

json_response([
    'success' => true,
    'hours' => $hours,
    'cutoff' => $cutoff,
    'summary' => [
        'accepted' => $accepted,
        'rejected' => $rejected,
        'total' => $accepted + $rejected,
    ],
    'top_reject_reasons' => $topReasons,
    'suspicious' => $suspicious,
    'count' => count($events),
    'events' => $events,
]);
