<?php
// GET /documents-duplicate-check.php?title=...&type=...&origin_office_id=1
// Returns whether a document with the same title+type was registered today at that office.

require __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

require_user_id();

$title = trim((string)($_GET['title'] ?? ''));
$type = trim((string)($_GET['type'] ?? ''));
$originOfficeId = (int)($_GET['origin_office_id'] ?? 0);

if ($title === '' || $type === '' || $originOfficeId <= 0) {
    json_response([
        'success' => true,
        'duplicate' => false,
    ]);
}

$stmt = $pdo->prepare('
    SELECT id
    FROM documents
    WHERE title = :title
      AND type = :type
      AND origin_office_id = :origin_office_id
      AND DATE(date_registered) = CURDATE()
    LIMIT 1
');
$stmt->execute([
    ':title' => $title,
    ':type' => $type,
    ':origin_office_id' => $originOfficeId,
]);
$row = $stmt->fetch();

json_response([
    'success' => true,
    'duplicate' => (bool)$row,
    'document_id' => $row ? (string)$row['id'] : null,
]);
