<?php
// GET /documents/{id}/movements
// Query: ?id=DOC-2026-000123
// Auth: Bearer token required

require __DIR__ . '/config.php';
require_once __DIR__ . '/folder-contents-helper.php';
require_once __DIR__ . '/users-helper.php';
require_once __DIR__ . '/journey-helper.php';
require_once __DIR__ . '/movement-corrections-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

require_user_id();
smartflow_ensure_folder_contents($pdo);
smartflow_ensure_movement_corrections($pdo);

$id = trim((string)($_GET['id'] ?? ''));
if ($id === '') {
    json_response([
        'success' => false,
        'message' => 'Missing id',
    ], 400);
}

// Ensure document exists
$stmtDoc = $pdo->prepare('SELECT id FROM documents WHERE id = :id LIMIT 1');
$stmtDoc->execute([':id' => $id]);
if (!$stmtDoc->fetch()) {
    json_response([
        'success' => false,
        'message' => 'Document not found',
    ], 404);
}

smartflow_ensure_users_avatar_column($pdo);

$stmt = $pdo->prepare('
    SELECT
        m.id,
        m.status,
        m.scanned_at,
        m.remarks,
        m.contents_receipt,
        m.destination_office_id,
        o.name AS office_name,
        o.code AS office_code,
        d.name AS destination_office_name,
        d.code AS destination_office_code,
        u.id AS user_id,
        u.name AS user_name,
        u.username AS username,
        u.avatar_path AS avatar_path
    FROM movements m
    JOIN offices o ON o.id = m.office_id
    LEFT JOIN offices d ON d.id = m.destination_office_id
    JOIN users u ON u.id = m.user_id
    WHERE m.document_id = :id
    ORDER BY m.scanned_at ASC, m.id ASC
');
$stmt->execute([':id' => $id]);
$rows = $stmt->fetchAll();
$corrections = smartflow_movement_destination_corrections($pdo, array_column($rows, 'id'));

json_response([
    'success' => true,
    'document_id' => $id,
    'movements' => smartflow_journey_steps(array_map(function ($r) use ($corrections) {
        return [
            'id' => (int)$r['id'],
            'office_name' => $r['office_name'],
            'office_code' => $r['office_code'],
            'status' => $r['status'],
            'scanned_at' => $r['scanned_at'],
            'user_id' => (int)$r['user_id'],
            'user_name' => $r['user_name'],
            'username' => $r['username'],
            'avatar_url' => smartflow_avatar_url_for((int)$r['user_id'], $r['avatar_path'] ?? null),
            'remarks' => $r['remarks'],
            'contents_receipt' => smartflow_contents_decode($r['contents_receipt']),
            'destination_office_id' => $r['destination_office_id'] !== null
                ? (int)$r['destination_office_id'] : null,
            'destination_office_name' => $r['destination_office_name'],
            'destination_office_code' => $r['destination_office_code'],
            'destination_corrections' => $corrections[(int)$r['id']] ?? [],
        ];
    }, $rows)),
]);

