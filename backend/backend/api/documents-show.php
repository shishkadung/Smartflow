<?php
// GET /documents/{id}
// Query: ?id=DOC-2026-000123
// Auth: Bearer token required

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/document-requests-helper.php';
require_once __DIR__ . '/routing-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

require_user_id();

$id = trim((string)($_GET['id'] ?? ''));
if ($id === '') {
    json_response([
        'success' => false,
        'message' => 'Missing id',
    ], 400);
}

// Fetch document
$stmt = $pdo->prepare('
    SELECT d.id, d.title, d.type, d.origin_office_id, d.due_at, o.name AS origin_office_name
    FROM documents d
    JOIN offices o ON o.id = d.origin_office_id
    WHERE d.id = :id
    LIMIT 1
');
$stmt->execute([':id' => $id]);
$doc = $stmt->fetch();

if (!$doc) {
    json_response([
        'success' => false,
        'message' => 'Document not found',
    ], 404);
}

// Determine current location/status from last movement
$stmtLast = $pdo->prepare('
    SELECT m.status, m.scanned_at, m.office_id, ofc.name AS office_name, ofc.code AS office_code
    FROM movements m
    JOIN offices ofc ON ofc.id = m.office_id
    WHERE m.document_id = :id
    ORDER BY m.scanned_at DESC, m.id DESC
    LIMIT 1
');
$stmtLast->execute([':id' => $id]);
$last = $stmtLast->fetch();

$due = smartflow_document_due(
    $pdo,
    (string)$doc['type'],
    $last ? $last['status'] : null,
    $last ? (int)$last['office_id'] : null,
    $last ? $last['scanned_at'] : null,
    $doc['due_at'] !== null ? (string)$doc['due_at'] : null
);

$stmtVisited = $pdo->prepare('
    SELECT DISTINCT ofc.code
    FROM movements m
    JOIN offices ofc ON ofc.id = m.office_id
    WHERE m.document_id = :id AND m.status = :st
');
$stmtVisited->execute([':id' => $id, ':st' => 'IN']);
$visitedOfficeCodes = array_map(
    static fn ($row) => strtoupper((string)$row['code']),
    $stmtVisited->fetchAll()
);

$suggestedForward = null;
if ($last && strtoupper((string)$last['status']) === 'IN') {
    $hint = smartflow_suggest_forward_destination(
        (string)$doc['type'],
        (string)$last['office_code'],
        $visitedOfficeCodes
    );
    if ($hint !== null) {
        $destId = smartflow_office_id_by_code($pdo, $hint['code']);
        if ($destId !== null && $destId !== (int)$last['office_id']) {
            $stmtDest = $pdo->prepare('SELECT name, code FROM offices WHERE id = :id LIMIT 1');
            $stmtDest->execute([':id' => $destId]);
            $destRow = $stmtDest->fetch();
            if ($destRow) {
                $suggestedForward = [
                    'office_id'   => $destId,
                    'office_code' => $destRow['code'],
                    'office_name' => $destRow['name'],
                    'reason'      => $hint['reason'],
                ];
            }
        }
    }
}

$pilotEndNote = null;
if (
    $last
    && strtoupper((string)$last['status']) === 'IN'
) {
    $typeLower = strtolower((string)$doc['type']);
    $at = strtoupper((string)$last['office_code']);
    $isDv = str_contains($typeLower, 'disbursement') || str_contains($typeLower, 'voucher');
    if ($isDv && $at === 'TRE' && in_array('MAY', $visitedOfficeCodes, true)) {
        $pilotEndNote = 'Check release at Treasury. After payment, OUT → ACC if Accounting needs the folder back.';
    } elseif (
        $isDv
        && $at === 'ACC'
        && in_array('TRE', $visitedOfficeCodes, true)
        && in_array('MAY', $visitedOfficeCodes, true)
    ) {
        $pilotEndNote = 'DV trail complete (ENG → BUD → ACC → TRE → MAY → TRE). Payment is at Treasury — SmartFlow only tracks the folder.';
    }
}

json_response([
    'success' => true,
    'document' => [
        'id' => $doc['id'],
        'title' => $doc['title'],
        'type' => $doc['type'],
        'origin_office_name' => $doc['origin_office_name'],
        'current_status' => $last ? $last['status'] : null,
        'current_office_id' => $last ? (int)$last['office_id'] : null,
        'current_office_name' => $last ? $last['office_name'] : null,
        'current_office_code' => $last ? $last['office_code'] : null,
        'last_scanned_at' => $last ? $last['scanned_at'] : null,
        'suggested_forward' => $suggestedForward,
        'pilot_end_note' => $pilotEndNote,
        'due_at' => $due['due_at'] ?: null,
        'due_at_display' => $due['due_at_display'],
        'hours_until_due' => $due['hours_until_due'],
        'is_overdue' => $due['is_overdue'],
        'threshold_rule' => $due['threshold_rule'],
        'is_manual_due' => $due['is_manual_due'],
    ],
]);

