<?php
// GET /reports-office-documents.php?office_id=1&month=2026-05
// Documents that had at least one movement at the given office during the month.
// Auth: Bearer token required.

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

require_user_id();

$officeId = (int)($_GET['office_id'] ?? 0);
$month = trim((string)($_GET['month'] ?? date('Y-m')));
if ($officeId <= 0) {
    json_response(['success' => false, 'message' => 'office_id is required'], 400);
}
if (!preg_match('/^\d{4}-\d{2}$/', $month)) {
    json_response(['success' => false, 'message' => 'month must be YYYY-MM'], 400);
}

$stmtOffice = $pdo->prepare('SELECT id, name, code FROM offices WHERE id = :id LIMIT 1');
$stmtOffice->execute([':id' => $officeId]);
$office = $stmtOffice->fetch();
if (!$office) {
    json_response(['success' => false, 'message' => 'Office not found'], 404);
}

$monthStart = $month . '-01 00:00:00';
$monthEnd   = date('Y-m-t 23:59:59', strtotime($monthStart));

$sql = "
    SELECT
        d.id AS document_id,
        d.title,
        d.type,
        d.due_at AS document_due_at,
        COUNT(m.id) AS movement_count,
        MIN(m.scanned_at) AS first_at_office,
        MAX(m.scanned_at) AS last_at_office,
        latest.status AS current_status,
        latest.office_id AS current_office_id,
        latest.scanned_at AS last_scanned_at,
        latest.office_name AS current_office_name,
        latest.office_code AS current_office_code
    FROM documents d
    INNER JOIN movements m
        ON m.document_id = d.id
       AND m.office_id = :oid
       AND m.scanned_at BETWEEN :start AND :end
    JOIN (
        SELECT m.document_id, m.status, m.office_id, m.scanned_at, o.name AS office_name, o.code AS office_code
        FROM movements m
        JOIN offices o ON o.id = m.office_id
        WHERE m.id = (
            SELECT m2.id FROM movements m2
            WHERE m2.document_id = m.document_id
            ORDER BY m2.scanned_at DESC, m2.id DESC
            LIMIT 1
        )
    ) latest ON latest.document_id = d.id
    GROUP BY d.id, d.title, d.type, d.due_at, latest.status, latest.office_id, latest.scanned_at, latest.office_name, latest.office_code
    ORDER BY last_at_office DESC
    LIMIT 100
";
$stmt = $pdo->prepare($sql);
$stmt->execute([
    ':oid'   => $officeId,
    ':start' => $monthStart,
    ':end'   => $monthEnd,
]);
$rows = $stmt->fetchAll();

$documents = array_map(function ($r) use ($pdo, $office) {
    $count = (int)$r['movement_count'];
    $lastAt = $r['last_at_office'];
    $status = $r['current_status'];
    $atOffice = $r['current_office_code'];
    $due = smartflow_document_due(
        $pdo,
        (string)$r['type'],
        $status,
        (int)$r['current_office_id'],
        (string)$r['last_scanned_at'],
        $r['document_due_at'] !== null ? (string)$r['document_due_at'] : null
    );
    $meta = $count === 1
        ? '1 movement at ' . $office['code'] . ' · last ' . $lastAt
        : "{$count} movements at {$office['code']} · last {$lastAt}";

    return [
        'document_id'     => $r['document_id'],
        'title'           => $r['title'],
        'type'            => $r['type'],
        'movement_count'  => $count,
        'last_at_office'  => $lastAt,
        'current_status'  => $status,
        'current_office'  => $r['current_office_name'],
        'current_office_code' => $atOffice,
        'meta'            => $meta,
        'due_at'          => $due['due_at'],
        'due_at_display'  => $due['due_at_display'],
        'hours_until_due' => $due['hours_until_due'],
        'is_overdue'      => $due['is_overdue'],
        'threshold_rule'  => $due['threshold_rule'],
    ];
}, $rows);

json_response([
    'success'    => true,
    'month'      => $month,
    'office_id'  => $officeId,
    'office_name'=> $office['name'],
    'office_code'=> $office['code'],
    'documents'  => $documents,
]);
