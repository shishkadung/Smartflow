<?php
// GET /audit-activity.php
// Admin/account audit trail (sign-up review, user status/profile/password,
// threshold changes, document request decisions). Scan events stay in audit-scans.php.
//
// Query:
//   hours=168         (1–720, default 168)
//   type=all          all|signup|user|threshold|request
//   limit=100         max rows (cap 500)
//   format=json|csv   default json
//
// Auth: admin only (Bearer).

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$adminId = require_user_id();
smartflow_require_admin($pdo, $adminId);

$hours = max(1, min(720, (int)($_GET['hours'] ?? 168)));
$type = strtolower(trim((string)($_GET['type'] ?? 'all')));
$limit = max(1, min(500, (int)($_GET['limit'] ?? 100)));
$format = strtolower(trim((string)($_GET['format'] ?? 'json')));

$types = ['signup', 'user', 'threshold', 'request'];
if ($type !== 'all' && !in_array($type, $types, true)) {
    json_response(['success' => false, 'message' => 'Invalid type filter'], 400);
}

$cutoff = date('Y-m-d H:i:s', time() - ($hours * 3600));
$prefixes = $type === 'all' ? $types : [$type];
$likeClauses = [];
$params = [':cutoff' => $cutoff];
foreach ($prefixes as $i => $prefix) {
    $likeClauses[] = "a.event_type LIKE :p{$i}";
    $params[":p{$i}"] = $prefix . '.%';
}

$stmt = $pdo->prepare('
    SELECT a.id, a.event_type, a.document_id, a.user_id, a.office_id,
           a.outcome, a.message, a.meta_json, a.created_at,
           u.name AS user_name, u.username,
           o.code AS office_code
    FROM audit_logs a
    LEFT JOIN users u ON u.id = a.user_id
    LEFT JOIN offices o ON o.id = a.office_id
    WHERE a.created_at >= :cutoff
      AND (' . implode(' OR ', $likeClauses) . ')
    ORDER BY a.created_at DESC, a.id DESC
    LIMIT ' . $limit
);
$stmt->execute($params);

$events = [];
foreach ($stmt->fetchAll() as $row) {
    $meta = null;
    if (!empty($row['meta_json'])) {
        $decoded = json_decode((string)$row['meta_json'], true);
        $meta = is_array($decoded) ? $decoded : null;
    }
    $events[] = [
        'id'          => (int)$row['id'],
        'event_type'  => (string)$row['event_type'],
        'document_id' => $row['document_id'],
        'user_id'     => $row['user_id'] !== null ? (int)$row['user_id'] : null,
        'user_name'   => $row['user_name'],
        'username'    => $row['username'],
        'office_code' => $row['office_code'],
        'message'     => (string)$row['message'],
        'meta'        => $meta,
        'created_at'  => (string)$row['created_at'],
    ];
}

if ($format === 'csv') {
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="smartflow-admin-activity.csv"');
    $out = fopen('php://output', 'w');
    fputcsv($out, ['created_at', 'event_type', 'username', 'office_code', 'document_id', 'message']);
    foreach ($events as $ev) {
        fputcsv($out, [
            $ev['created_at'],
            $ev['event_type'],
            $ev['username'] ?? '',
            $ev['office_code'] ?? '',
            $ev['document_id'] ?? '',
            $ev['message'],
        ]);
    }
    fclose($out);
    exit;
}

json_response([
    'success' => true,
    'hours'   => $hours,
    'type'    => $type,
    'count'   => count($events),
    'events'  => $events,
]);
