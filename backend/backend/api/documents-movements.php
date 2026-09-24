<?php
// GET /documents/{id}/movements
// Query: ?id=DOC-2026-000123
// Auth: Bearer token required

require __DIR__ . '/config.php';

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

// Ensure document exists
$stmtDoc = $pdo->prepare('SELECT id FROM documents WHERE id = :id LIMIT 1');
$stmtDoc->execute([':id' => $id]);
if (!$stmtDoc->fetch()) {
    json_response([
        'success' => false,
        'message' => 'Document not found',
    ], 404);
}

$stmt = $pdo->prepare('
    SELECT
        m.id,
        m.status,
        m.scanned_at,
        m.remarks,
        m.destination_office_id,
        o.name AS office_name,
        o.code AS office_code,
        d.name AS destination_office_name,
        d.code AS destination_office_code,
        u.name AS user_name,
        u.username AS username
    FROM movements m
    JOIN offices o ON o.id = m.office_id
    LEFT JOIN offices d ON d.id = m.destination_office_id
    JOIN users u ON u.id = m.user_id
    WHERE m.document_id = :id
    ORDER BY m.scanned_at ASC, m.id ASC
');
$stmt->execute([':id' => $id]);
$rows = $stmt->fetchAll();

json_response([
    'success' => true,
    'document_id' => $id,
    'movements' => array_map(function ($r) {
        return [
            'id' => (int)$r['id'],
            'office_name' => $r['office_name'],
            'office_code' => $r['office_code'],
            'status' => $r['status'],
            'scanned_at' => $r['scanned_at'],
            'user_name' => $r['user_name'],
            'username' => $r['username'],
            'remarks' => $r['remarks'],
            'destination_office_id' => $r['destination_office_id'] !== null
                ? (int)$r['destination_office_id'] : null,
            'destination_office_name' => $r['destination_office_name'],
            'destination_office_code' => $r['destination_office_code'],
        ];
    }, $rows),
]);

