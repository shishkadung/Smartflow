<?php
// GET /dashboard-stats.php?office_id=4
// Returns counts the dashboard cards need (in-flow today, out-flow today, active QR tags).
// Auth: Bearer token required.

require __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

require_user_id();

$officeId = (int)($_GET['office_id'] ?? 0);
if ($officeId <= 0) {
    json_response([
        'success' => false,
        'message' => 'office_id is required',
    ], 400);
}

// Today is local server day — the LGU server is on-prem so this matches what users see.
$today = date('Y-m-d');

$stmtIn = $pdo->prepare("
    SELECT COUNT(*) AS c
    FROM movements
    WHERE office_id = :oid AND status = 'IN' AND DATE(scanned_at) = :today
");
$stmtIn->execute([':oid' => $officeId, ':today' => $today]);
$inFlow = (int)($stmtIn->fetch()['c'] ?? 0);

$stmtOut = $pdo->prepare("
    SELECT COUNT(*) AS c
    FROM movements
    WHERE office_id = :oid AND status = 'OUT' AND DATE(scanned_at) = :today
");
$stmtOut->execute([':oid' => $officeId, ':today' => $today]);
$outFlow = (int)($stmtOut->fetch()['c'] ?? 0);

// Active = documents whose latest movement is IN at this office (still here).
$stmtActive = $pdo->prepare("
    SELECT COUNT(*) AS c
    FROM (
        SELECT m.document_id,
               (SELECT m2.status
                FROM movements m2
                WHERE m2.document_id = m.document_id
                ORDER BY m2.scanned_at DESC, m2.id DESC
                LIMIT 1) AS last_status,
               (SELECT m2.office_id
                FROM movements m2
                WHERE m2.document_id = m.document_id
                ORDER BY m2.scanned_at DESC, m2.id DESC
                LIMIT 1) AS last_office
        FROM movements m
        GROUP BY m.document_id
    ) t
    WHERE t.last_status = 'IN' AND t.last_office = :oid
");
$stmtActive->execute([':oid' => $officeId]);
$activeTags = (int)($stmtActive->fetch()['c'] ?? 0);

// Documents currently IN at this office (clerk tray).
$stmtTray = $pdo->prepare("
    SELECT d.id AS document_id, d.title, d.type,
           latest.scanned_at AS last_scanned_at,
           latest.status AS current_status
    FROM documents d
    JOIN (
        SELECT m.document_id, m.status, m.office_id, m.scanned_at
        FROM movements m
        WHERE m.id = (
            SELECT m2.id FROM movements m2
            WHERE m2.document_id = m.document_id
            ORDER BY m2.scanned_at DESC, m2.id DESC
            LIMIT 1
        )
    ) latest ON latest.document_id = d.id
    WHERE latest.status = 'IN' AND latest.office_id = :oid
    ORDER BY latest.scanned_at DESC
    LIMIT 12
");
$stmtTray->execute([':oid' => $officeId]);
$activeDocuments = array_map(static function ($r) {
    return [
        'document_id'    => $r['document_id'],
        'title'          => $r['title'],
        'type'           => $r['type'],
        'last_scanned_at'=> $r['last_scanned_at'],
        'current_status' => $r['current_status'],
    ];
}, $stmtTray->fetchAll());

// Recent movements logged at this office today (audit preview).
$stmtRecent = $pdo->prepare("
    SELECT m.document_id, m.status, m.scanned_at, m.remarks,
           d.title, u.name AS user_name,
           dest.code AS destination_office_code,
           dest.name AS destination_office_name
    FROM movements m
    JOIN documents d ON d.id = m.document_id
    JOIN users u ON u.id = m.user_id
    LEFT JOIN offices dest ON dest.id = m.destination_office_id
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
        'destination_office_code' => $r['destination_office_code'],
        'destination_office_name' => $r['destination_office_name'],
    ];
}, $stmtRecent->fetchAll());

// Incoming (in transit) — last movement is OUT from another office within 48h.
// These folders may physically arrive at this office; clerk can Mark IN here.
$stmtTransit = $pdo->prepare("
    SELECT d.id AS document_id, d.title, d.type,
           latest.scanned_at AS last_scanned_at,
           latest.office_id  AS last_office_id,
           o.name            AS last_office_name,
           o.code            AS last_office_code,
           dest.name         AS destination_office_name,
           dest.code         AS destination_office_code
    FROM documents d
    JOIN (
        SELECT m.document_id, m.status, m.office_id, m.scanned_at, m.destination_office_id
        FROM movements m
        WHERE m.id = (
            SELECT m2.id FROM movements m2
            WHERE m2.document_id = m.document_id
            ORDER BY m2.scanned_at DESC, m2.id DESC
            LIMIT 1
        )
    ) latest ON latest.document_id = d.id
    JOIN offices o ON o.id = latest.office_id
    LEFT JOIN offices dest ON dest.id = latest.destination_office_id
    WHERE latest.status = 'OUT'
      AND latest.office_id != :oid
      AND latest.scanned_at >= (NOW() - INTERVAL 48 HOUR)
      AND (latest.destination_office_id IS NULL OR latest.destination_office_id = :oid)
    ORDER BY latest.scanned_at DESC
    LIMIT 6
");
$stmtTransit->execute([':oid' => $officeId]);
$inTransit = array_map(static function ($r) {
    return [
        'document_id'       => $r['document_id'],
        'title'             => $r['title'],
        'type'              => $r['type'],
        'last_scanned_at'   => $r['last_scanned_at'],
        'last_office_id'    => (int)$r['last_office_id'],
        'last_office_name'  => $r['last_office_name'],
        'last_office_code'  => $r['last_office_code'],
        'destination_office_name' => $r['destination_office_name'],
        'destination_office_code' => $r['destination_office_code'],
    ];
}, $stmtTransit->fetchAll());

json_response([
    'success' => true,
    'office_id' => $officeId,
    'date'      => $today,
    'stats' => [
        'in_flow'     => $inFlow,
        'out_flow'    => $outFlow,
        'active_tags' => $activeTags,
    ],
    'active_documents' => $activeDocuments,
    'recent_movements' => $recentMovements,
    'in_transit'       => $inTransit,
]);
