<?php
// GET /documents-find-by-reference.php?reference=DV-2026-1234
// Returns documents whose description contains "Reference: <value>".
// Used by mobile Register form to warn the clerk about duplicates before submit.

require __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

require_user_id();

$reference = trim((string)($_GET['reference'] ?? ''));
if ($reference === '') {
    json_response([
        'success' => true,
        'reference' => '',
        'matches' => [],
    ]);
}

$needle = '%Reference: ' . $reference . '%';

$stmt = $pdo->prepare('
    SELECT
        d.id,
        d.title,
        d.type,
        d.date_registered,
        d.origin_office_id,
        o.name AS origin_office_name,
        o.code AS origin_office_code
    FROM documents d
    JOIN offices o ON o.id = d.origin_office_id
    WHERE d.description LIKE :needle
    ORDER BY d.date_registered DESC
    LIMIT 5
');
$stmt->execute([':needle' => $needle]);
$rows = $stmt->fetchAll();

$matches = array_map(static function ($r) {
    return [
        'id' => $r['id'],
        'title' => $r['title'],
        'type' => $r['type'],
        'origin_office_name' => $r['origin_office_name'],
        'origin_office_code' => $r['origin_office_code'],
        'date_registered' => $r['date_registered'],
    ];
}, $rows);

json_response([
    'success' => true,
    'reference' => $reference,
    'matches' => $matches,
]);
