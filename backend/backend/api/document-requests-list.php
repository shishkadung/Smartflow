<?php
// GET /document-requests-list.php?view=inbox|outbox|all&status=pending
// inbox  = requests for my office to handle
// outbox = requests I created
// all    = admin municipal view only

require __DIR__ . '/config.php';
require_once __DIR__ . '/document-requests-helper.php';

smartflow_ensure_document_requests($pdo);

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
$stmt = $pdo->prepare('
    SELECT u.id, u.role, u.office_id, o.code AS office_code
    FROM users u
    JOIN offices o ON o.id = u.office_id
    WHERE u.id = :id AND u.is_active = 1
    LIMIT 1
');
$stmt->execute([':id' => $userId]);
$user = $stmt->fetch();
if (!$user) {
    json_response(['success' => false, 'message' => 'User not found'], 401);
}

$view = strtolower(trim((string)($_GET['view'] ?? 'inbox')));
$statusFilter = trim((string)($_GET['status'] ?? ''));

if (!in_array($view, ['inbox', 'outbox', 'all'], true)) {
    json_response(['success' => false, 'message' => 'view must be inbox, outbox, or all'], 400);
}

if ($view === 'all' && $user['role'] !== 'admin') {
    json_response(['success' => false, 'message' => 'Admin access required for municipal view'], 403);
}

$sql = SMARTFLOW_DR_SELECT . ' WHERE 1=1';
$params = [];

if ($view === 'inbox') {
    $officeCode = strtoupper((string)$user['office_code']);
    if ($officeCode === 'TRE') {
        // Handler desk + payment queue (ACC-approved DV tickets awaiting Treasury release).
        $sql .= ' AND (
            r.handler_office_id = :oid
            OR (r.document_category = \'disbursement\' AND r.status = \'approved\')
        )';
    } else {
        $sql .= ' AND r.handler_office_id = :oid';
    }
    $params[':oid'] = $user['office_id'];
} elseif ($view === 'outbox') {
    $sql .= ' AND r.requested_by = :uid';
    $params[':uid'] = $userId;
}

if ($statusFilter !== '' && in_array($statusFilter, ['pending', 'approved', 'rejected', 'fulfilled', 'cancelled'], true)) {
    $sql .= ' AND r.status = :st';
    $params[':st'] = $statusFilter;
}

$sql .= ' ORDER BY r.created_at DESC LIMIT 100';

$stmtList = $pdo->prepare($sql);
$stmtList->execute($params);
$requests = array_map(
    'smartflow_format_document_request_row',
    $stmtList->fetchAll()
);

$pendingInbox = 0;
if ($view === 'inbox') {
    $c = $pdo->prepare('SELECT COUNT(*) FROM document_requests WHERE handler_office_id = :oid AND status = \'pending\'');
    $c->execute([':oid' => $user['office_id']]);
    $pendingInbox = (int)$c->fetchColumn();
}

json_response([
    'success' => true,
    'view'    => $view,
    'pending_inbox_count' => $pendingInbox,
    'requests' => $requests,
]);
