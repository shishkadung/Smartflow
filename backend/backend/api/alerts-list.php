<?php
// GET /alerts-list.php?office_id=4
// Office-scoped alerts (staff/head): only folders relevant to THAT department.
// - IN overdue at this office
// - OUT from this office with no receive scan yet
// - Manual due dates only when the folder's latest custody is this office
// Municipal-wide view: use accountant-alerts.php (admin).

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';

smartflow_ensure_documents_due_column($pdo);

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();

$officeId = (int)($_GET['office_id'] ?? 0);
if ($officeId <= 0) {
    json_response(['success' => false, 'message' => 'office_id is required'], 400);
}

$stmtUser = $pdo->prepare('
    SELECT u.role, u.office_id
    FROM users u
    WHERE u.id = :id AND u.is_active = 1
    LIMIT 1
');
$stmtUser->execute([':id' => $userId]);
$user = $stmtUser->fetch();
if (!$user) {
    json_response(['success' => false, 'message' => 'User not found'], 401);
}

// Clerks/heads may only query their own office. Admin may query any office.
if ($user['role'] !== 'admin' && (int)$user['office_id'] !== $officeId) {
    json_response([
        'success' => false,
        'message' => 'Alerts are limited to your own office',
    ], 403);
}

$stmtOffice = $pdo->prepare('SELECT id, code, name FROM offices WHERE id = :id LIMIT 1');
$stmtOffice->execute([':id' => $officeId]);
$office = $stmtOffice->fetch();
if (!$office) {
    json_response(['success' => false, 'message' => 'Office not found'], 404);
}

$sql = "
    SELECT
        d.id AS document_id,
        d.title,
        d.type AS document_type,
        d.due_at AS document_due_at,
        latest.status        AS last_status,
        latest.office_id     AS last_office_id,
        latest.scanned_at    AS last_scanned_at,
        latest.office_name   AS last_office_name,
        TIMESTAMPDIFF(HOUR, latest.scanned_at, NOW()) AS hours_pending
    FROM documents d
    JOIN (
        SELECT m.document_id, m.status, m.office_id, m.scanned_at, o.name AS office_name
        FROM movements m
        JOIN offices o ON o.id = m.office_id
        WHERE m.id = (
            SELECT m2.id
            FROM movements m2
            WHERE m2.document_id = m.document_id
            ORDER BY m2.scanned_at DESC, m2.id DESC
            LIMIT 1
        )
    ) latest ON latest.document_id = d.id
    WHERE latest.office_id = :oid
    ORDER BY latest.scanned_at ASC
";

$stmt = $pdo->prepare($sql);
$stmt->execute([':oid' => $officeId]);
$rows = $stmt->fetchAll();

$alerts = [];
foreach ($rows as $r) {
    // Only custody events at this office (IN here, or OUT from here).
    $alert = smartflow_build_alert_from_row($pdo, $r, $officeId);
    if ($alert === null) {
        continue;
    }
    $alerts[] = $alert;
}

json_response([
    'success'     => true,
    'office_id'   => $officeId,
    'office_code' => $office['code'],
    'office_name' => $office['name'],
    'alerts'      => $alerts,
]);
