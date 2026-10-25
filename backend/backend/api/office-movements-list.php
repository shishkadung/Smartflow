<?php
// Complete daily office event log; dashboard recent_movements remains a preview only.
require __DIR__ . '/config.php';
require_once __DIR__ . '/office-access-helper.php';
require_once __DIR__ . '/movement-corrections-helper.php';
if ($_SERVER['REQUEST_METHOD'] !== 'GET') json_response(['success' => false, 'message' => 'Method not allowed'], 405);
$userId = require_user_id();
$officeId = (int)($_GET['office_id'] ?? 0);
if ($officeId <= 0) json_response(['success' => false, 'message' => 'office_id is required'], 400);
smartflow_require_office_scope($pdo, $userId, $officeId);
smartflow_ensure_movement_corrections($pdo);
$date = trim((string)($_GET['date'] ?? date('Y-m-d')));
$parsed = DateTimeImmutable::createFromFormat('!Y-m-d', $date);
if (!$parsed || $parsed->format('Y-m-d') !== $date) json_response(['success' => false, 'message' => 'date must be a valid YYYY-MM-DD date'], 400);
$tomorrow = $parsed->modify('+1 day')->format('Y-m-d');
$status = strtoupper(trim((string)($_GET['status'] ?? '')));
if ($status !== '' && !in_array($status, ['IN', 'OUT'], true)) json_response(['success' => false, 'message' => 'status must be IN or OUT'], 400);
$pageSize = max(1, min(100, (int)($_GET['page_size'] ?? 25)));
$page = max(1, (int)($_GET['page'] ?? 1));
$params = [':oid' => $officeId, ':date' => $date, ':tomorrow' => $tomorrow];
$where = 'm.office_id = :oid AND m.scanned_at >= :date AND m.scanned_at < :tomorrow';
$totals = $pdo->prepare("SELECT COUNT(*) AS total, COALESCE(SUM(m.status = 'IN'), 0) AS in_flow, COALESCE(SUM(m.status = 'OUT'), 0) AS out_flow FROM movements m WHERE {$where}");
$totals->execute($params);
$stats = array_map('intval', $totals->fetch());
$total = $stats['total'];
if ($status !== '') { $where .= ' AND m.status = :status'; $params[':status'] = $status; $total = $status === 'IN' ? $stats['in_flow'] : $stats['out_flow']; }
$page = min($page, max(1, (int)ceil($total / $pageSize)));
$offset = ($page - 1) * $pageSize;
$list = $pdo->prepare("SELECT m.id, m.document_id, m.status, m.scanned_at, m.remarks, d.title, o.name AS office_name, o.code AS office_code, u.name AS user_name, dest.code AS destination_office_code, dest.name AS destination_office_name FROM movements m JOIN documents d ON d.id = m.document_id JOIN offices o ON o.id = m.office_id JOIN users u ON u.id = m.user_id LEFT JOIN offices dest ON dest.id = m.destination_office_id WHERE {$where} ORDER BY m.scanned_at DESC, m.id DESC LIMIT {$pageSize} OFFSET {$offset}");
$list->execute($params);
$rows = $list->fetchAll();
$corrections = smartflow_movement_destination_corrections($pdo, array_column($rows, 'id'));
foreach ($rows as &$row) {
    $row['id'] = (int)$row['id'];
    $row['destination_corrections'] = $corrections[$row['id']] ?? [];
}
unset($row);
json_response(['success' => true, 'office_id' => $officeId, 'scope' => 'office', 'date' => $date, 'movements' => $rows, 'stats' => $stats, 'total' => $total, 'page' => $page, 'page_size' => $pageSize, 'has_more' => $offset + $pageSize < $total]);
