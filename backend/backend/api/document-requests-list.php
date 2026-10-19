<?php
// Complete, office-scoped request listing. Counts use the whole view, not its current page.
require __DIR__ . '/config.php';
require_once __DIR__ . '/document-requests-helper.php';
smartflow_ensure_document_requests($pdo);

if ($_SERVER['REQUEST_METHOD'] !== 'GET') json_response(['success' => false, 'message' => 'Method not allowed'], 405);
$userId = require_user_id();
$stmt = $pdo->prepare('SELECT u.id, u.role, u.office_id, o.code AS office_code FROM users u JOIN offices o ON o.id = u.office_id WHERE u.id = :id AND u.is_active = 1 LIMIT 1');
$stmt->execute([':id' => $userId]);
$user = $stmt->fetch();
if (!$user) json_response(['success' => false, 'message' => 'User not found'], 401);

$view = strtolower(trim((string)($_GET['view'] ?? 'inbox')));
$status = trim((string)($_GET['status'] ?? ''));
$overdue = (string)($_GET['overdue'] ?? '') === '1';
$search = trim((string)($_GET['q'] ?? ''));
$id = (int)($_GET['id'] ?? 0);
$page = max(1, (int)($_GET['page'] ?? 1));
$pageSize = max(1, min(100, (int)($_GET['page_size'] ?? 25)));
if (!in_array($view, ['inbox', 'outbox', 'all'], true)) json_response(['success' => false, 'message' => 'view must be inbox, outbox, or all'], 400);
if ($view === 'all' && $user['role'] !== 'admin') json_response(['success' => false, 'message' => 'Admin access required for municipal view'], 403);
if ($status !== '' && !in_array($status, ['active', 'past', 'pending', 'approved', 'rejected', 'fulfilled', 'cancelled'], true)) json_response(['success' => false, 'message' => 'Invalid request status'], 400);
if (strlen($search) > 200) json_response(['success' => false, 'message' => 'Search is limited to 200 characters'], 400);

[$scope, $params] = smartflow_document_request_read_scope($user, $view);
$count = $pdo->prepare("SELECT COUNT(*) AS total, COALESCE(SUM(r.status = 'pending'), 0) AS pending, COALESCE(SUM(r.required_by < CURDATE() AND r.status IN ('pending', 'approved')), 0) AS overdue, COALESCE(SUM(r.status IN ('pending', 'approved')), 0) AS active, COALESCE(SUM(r.status IN ('fulfilled', 'rejected', 'cancelled')), 0) AS past FROM document_requests r WHERE {$scope}");
$count->execute($params);
$counts = array_map('intval', $count->fetch());

$where = $scope;
if ($id > 0) {
    // Exact links do not disappear because the record is old or outside the selected filter.
    $where .= ' AND r.id = :id';
    $params[':id'] = $id;
    $page = 1;
} else {
    if ($status === 'active') $where .= " AND r.status IN ('pending', 'approved')";
    elseif ($status === 'past') $where .= " AND r.status IN ('fulfilled', 'rejected', 'cancelled')";
    elseif ($status !== '') { $where .= ' AND r.status = :status'; $params[':status'] = $status; }
    if ($overdue) $where .= " AND r.required_by < CURDATE() AND r.status IN ('pending', 'approved')";
    if ($search !== '') {
        $where .= " AND (r.request_code LIKE :search OR r.purpose LIKE :search OR COALESCE(r.related_document_id, '') LIKE :search)";
        $params[':search'] = '%' . $search . '%';
    }
}
$totalStmt = $pdo->prepare("SELECT COUNT(*) FROM document_requests r WHERE {$where}");
$totalStmt->execute($params);
$total = (int)$totalStmt->fetchColumn();
$page = min($page, max(1, (int)ceil($total / $pageSize)));
$offset = ($page - 1) * $pageSize;
$list = $pdo->prepare(SMARTFLOW_DR_SELECT . " WHERE {$where} ORDER BY r.created_at DESC, r.id DESC LIMIT {$pageSize} OFFSET {$offset}");
$list->execute($params);
json_response([
    'success' => true, 'view' => $view,
    'requests' => array_map('smartflow_format_document_request_row', $list->fetchAll()),
    'pending_inbox_count' => $view === 'inbox' ? $counts['pending'] : 0,
    'counts' => $counts, 'total' => $total, 'page' => $page, 'page_size' => $pageSize,
    'has_more' => $offset + $pageSize < $total,
]);
