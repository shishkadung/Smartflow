<?php
// GET /documents/{id}
// Query: ?id=DOC-2026-000123
// Auth: Bearer token required

require __DIR__ . '/config.php';
require_once __DIR__ . '/movements-helper.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/document-requests-helper.php';
require_once __DIR__ . '/routing-helper.php';
require_once __DIR__ . '/documents-logbook-helper.php';
require_once __DIR__ . '/folder-contents-helper.php';
require_once __DIR__ . '/users-helper.php';
require_once __DIR__ . '/movement-corrections-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

$user = smartflow_require_authenticated_user($pdo, require_user_id());

$id = trim((string)($_GET['id'] ?? ''));
if ($id === '') {
    json_response([
        'success' => false,
        'message' => 'Missing id',
    ], 400);
}

smartflow_ensure_documents_logbook_columns($pdo);
smartflow_ensure_documents_filed_columns($pdo);
smartflow_ensure_folder_contents($pdo);
smartflow_ensure_documents_created_by($pdo);
smartflow_ensure_documents_date_registered($pdo);
smartflow_ensure_users_avatar_column($pdo);
smartflow_ensure_document_requests($pdo);
smartflow_ensure_movement_corrections($pdo);

// Fetch document
$stmt = $pdo->prepare('
    SELECT d.id, d.title, d.type, d.origin_office_id, d.due_at,
           d.reference_no, d.payee, d.fund_source, d.folder_inventory,
           d.created_by, d.date_registered, d.filed_at, d.filed_by,
           fu.name AS filer_name,
           fu.username AS filer_username,
           fu.avatar_path AS filer_avatar_path,
           fo.name AS filer_office_name,
           fo.code AS filer_office_code,
           o.name AS origin_office_name,
           rf.code AS received_from_office_code,
           cu.name AS registrar_name,
           cu.username AS registrar_username,
           cu.avatar_path AS registrar_avatar_path,
           co.name AS registrar_office_name,
           co.code AS registrar_office_code
    FROM documents d
    JOIN offices o ON o.id = d.origin_office_id
    LEFT JOIN offices rf ON rf.id = d.received_from_office_id
    LEFT JOIN users cu ON cu.id = d.created_by
    LEFT JOIN offices co ON co.id = cu.office_id
    LEFT JOIN users fu ON fu.id = d.filed_by
    LEFT JOIN offices fo ON fo.id = fu.office_id
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
    SELECT m.id, m.status, m.scanned_at, m.office_id, m.destination_office_id, ofc.name AS office_name, ofc.code AS office_code,
           dest.name AS destination_office_name, dest.code AS destination_office_code
    FROM movements m
    JOIN offices ofc ON ofc.id = m.office_id
    LEFT JOIN offices dest ON dest.id = m.destination_office_id
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

$trailComplete = smartflow_document_trail_complete($pdo, (string)$doc['id']);
if ($trailComplete) {
    $due = [
        'due_at'          => '',
        'due_at_display'  => '—',
        'hours_until_due' => 0,
        'is_overdue'      => false,
        'threshold_rule'  => 'Trail complete — no further processing due',
        'is_manual_due'   => false,
    ];
}

$isDv = smartflow_type_is_dv((string)$doc['type']);
$pilotEndNote = null;
if (
    $last
    && strtoupper((string)$last['status']) === 'IN'
) {
    $at = strtoupper((string)$last['office_code']);
    if ($isDv && $at === 'TRE' && in_array('MAY', $visitedOfficeCodes, true)) {
        $pilotEndNote = 'DV trail complete at Treasury (check release). If the folder returns to Accounting, Mark OUT → ACC. SmartFlow only tracks the folder.';
    } elseif ($trailComplete && $isDv) {
        $pilotEndNote = 'DV trail complete (ENG → BUD → ACC → TRE → MAY → TRE → ACC). Folder returned to Accounting.';
    } elseif ($trailComplete && smartflow_type_is_approved_budget((string)$doc['type'])) {
        $pilotEndNote = 'Approved Budget trail complete (BUD → ACC). Folder is filed at Accounting.';
    } elseif ($trailComplete) {
        $pilotEndNote = 'Folder filed by the holding office. No further processing due.';
    }
}

$registeredBy = null;
if (!empty($doc['created_by']) && !empty($doc['registrar_name'])) {
    $registeredBy = [
        'user_id' => (int)$doc['created_by'],
        'name' => $doc['registrar_name'],
        'username' => $doc['registrar_username'],
        'avatar_url' => smartflow_avatar_url_for((int)$doc['created_by'], $doc['registrar_avatar_path'] ?? null),
        'office_name' => $doc['registrar_office_name'],
        'office_code' => $doc['registrar_office_code'],
        'registered_at' => $doc['date_registered'],
    ];
}

// Filing is stored on the document, not as a movement; expose it so History can show who completed the folder and when.
$filedBy = null;
if (!empty($doc['filed_at'])) {
    $hasFiler = !empty($doc['filed_by']) && !empty($doc['filer_name']);
    $filedBy = [
        'filed_at' => $doc['filed_at'],
        'user_id' => $hasFiler ? (int)$doc['filed_by'] : null,
        'name' => $hasFiler ? $doc['filer_name'] : null,
        'username' => $hasFiler ? $doc['filer_username'] : null,
        'avatar_url' => $hasFiler ? smartflow_avatar_url_for((int)$doc['filed_by'], $doc['filer_avatar_path'] ?? null) : null,
        'office_name' => $hasFiler ? $doc['filer_office_name'] : null,
        'office_code' => $hasFiler ? $doc['filer_office_code'] : null,
    ];
}

[$requestScope, $requestParams] = smartflow_document_request_read_scope($user, 'related');
$stmtRequests = $pdo->prepare("
    SELECT r.id, r.request_code, r.purpose, r.status, r.created_at, r.document_category,
           u.id AS user_id, u.name AS user_name, u.avatar_path,
           o.name AS office_name, o.code AS office_code
    FROM document_requests r
    JOIN users u ON u.id = r.requested_by
    JOIN offices o ON o.id = r.requester_office_id
    WHERE r.related_document_id = :id
      AND r.status <> 'cancelled'
      AND {$requestScope}
    ORDER BY r.created_at ASC, r.id ASC
");
$stmtRequests->execute([':id' => $id] + $requestParams);
$linkedRequests = array_map(static function ($row) {
    return [
        'id' => (int)$row['id'],
        'request_code' => $row['request_code'],
        'purpose' => $row['purpose'],
        'status' => $row['status'],
        'created_at' => $row['created_at'],
        'document_category' => $row['document_category'],
        'user_id' => (int)$row['user_id'],
        'user_name' => $row['user_name'],
        'avatar_url' => smartflow_avatar_url_for((int)$row['user_id'], $row['avatar_path'] ?? null),
        'office_name' => $row['office_name'],
        'office_code' => $row['office_code'],
    ];
}, $stmtRequests->fetchAll());

json_response([
    'success' => true,
    'document' => [
        'id' => $doc['id'],
        ...smartflow_folder_state($pdo, (string)$doc['id'], $doc['folder_inventory']),
        'title' => $doc['title'],
        'type' => $doc['type'],
        'origin_office_name' => $doc['origin_office_name'],
        'registered_by' => $registeredBy,
        'filed_by' => $filedBy,
        'linked_requests' => $linkedRequests,
        'reference_no' => $doc['reference_no'],
        'payee' => $doc['payee'],
        'fund_source' => $doc['fund_source'],
        'received_from_office_code' => $doc['received_from_office_code'],
        'current_status' => $last ? $last['status'] : null,
        'current_office_id' => $last ? (int)$last['office_id'] : null,
        'current_office_name' => $last ? $last['office_name'] : null,
        'current_office_code' => $last ? $last['office_code'] : null,
        'last_movement_id' => $last ? (int)$last['id'] : null,
        'destination_office_id' => $last && $last['destination_office_id'] !== null ? (int)$last['destination_office_id'] : null,
        ...smartflow_movement_correction_state($pdo, $last ?: null, $user, !empty($doc['filed_at'])),
        'destination_office_name' => $last ? ($last['destination_office_name'] ?: null) : null,
        'destination_office_code' => $last ? ($last['destination_office_code'] ?: null) : null,
        'last_scanned_at' => $last ? $last['scanned_at'] : null,
        'suggested_forward' => $suggestedForward,
        'visited_office_codes' => $visitedOfficeCodes,
        'pilot_end_note' => $pilotEndNote,
        'trail_complete' => $trailComplete,
        'can_return_to_accounting' => $isDv && $trailComplete && empty($doc['filed_at']) && $last
            && strtoupper((string)$last['status']) === 'IN' && strtoupper((string)$last['office_code']) === 'TRE',
        'can_file' => (string)$user['role'] === 'staff'
            && !$trailComplete
            && !smartflow_type_has_fixed_route((string)$doc['type'])
            && $last
            && strtoupper((string)$last['status']) === 'IN'
            && (int)$last['office_id'] === (int)$user['office_id'],
        'due_at' => $due['due_at'] ?: null,
        'manual_due_at' => $doc['due_at'],
        'due_at_display' => $due['due_at_display'],
        'hours_until_due' => $due['hours_until_due'],
        'is_overdue' => $due['is_overdue'],
        'threshold_rule' => $due['threshold_rule'],
        'is_manual_due' => $due['is_manual_due'],
    ],
]);

