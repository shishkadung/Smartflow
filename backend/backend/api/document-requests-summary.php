<?php
// GET /document-requests-summary.php
// Counts for home badge: inbox pending + outbox status breakdown for requester.

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

$oid = (int)$user['office_id'];

$cInbox = $pdo->prepare('
    SELECT COUNT(*) FROM document_requests
    WHERE handler_office_id = :oid AND status = \'pending\'
');
$cInbox->execute([':oid' => $oid]);
$pendingInbox = (int)$cInbox->fetchColumn();

// Match the inbox's Treasury payment queue as well as requests assigned to this office.
$overdueInbox = $pdo->prepare("
    SELECT COUNT(*) FROM document_requests
    WHERE required_by < CURDATE() AND status IN ('pending', 'approved')
      AND (handler_office_id = :oid OR (:treasury = 1 AND document_category = 'disbursement' AND status = 'approved'))
");
$overdueInbox->execute([':oid' => $oid, ':treasury' => strtoupper((string)$user['office_code']) === 'TRE' ? 1 : 0]);
$overdueOutbox = $pdo->prepare("
    SELECT COUNT(*) FROM document_requests
    WHERE requested_by = :uid AND required_by < CURDATE() AND status IN ('pending', 'approved')
");
$overdueOutbox->execute([':uid' => $userId]);

$outbox = [
    'pending'   => 0,
    'approved'  => 0,
    'rejected'  => 0,
    'fulfilled' => 0,
    'cancelled' => 0,
];
$stmtOut = $pdo->prepare('
    SELECT status, COUNT(*) AS cnt
    FROM document_requests
    WHERE requested_by = :uid
    GROUP BY status
');
$stmtOut->execute([':uid' => $userId]);
foreach ($stmtOut->fetchAll() as $row) {
    $st = (string)$row['status'];
    if (array_key_exists($st, $outbox)) {
        $outbox[$st] = (int)$row['cnt'];
    }
}

$outboxAttention = $outbox['rejected'] + $outbox['approved'] + $outbox['fulfilled'];

json_response([
    'success' => true,
    'pending_inbox_count' => $pendingInbox,
    'overdue_inbox_count' => (int)$overdueInbox->fetchColumn(),
    'overdue_outbox_count' => (int)$overdueOutbox->fetchColumn(),
    'outbox' => $outbox,
    'outbox_attention_count' => $outboxAttention,
    'outbox_needs_action_count' => $outbox['rejected'] + $outbox['approved'],
]);
