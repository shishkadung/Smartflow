<?php
// GET /dev-purge-demo-documents.php
// GET /dev-purge-demo-documents.php?all=1  — remove ALL documents (movements + requests) for a clean demo DB
// Default: only documents seeded with the demo description marker.

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';
require_once __DIR__ . '/document-requests-helper.php';

smartflow_dev_localhost_or_admin($pdo);

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$purgeAll = isset($_GET['all']) && ($_GET['all'] === '1' || $_GET['all'] === 'true');

if ($purgeAll) {
    smartflow_ensure_document_requests($pdo);
    $stmt = $pdo->query('SELECT id FROM documents');
    $ids = array_column($stmt->fetchAll(), 'id');
} else {
    $marker = 'Demo document for clerk scan testing';
    $stmt = $pdo->prepare('SELECT id FROM documents WHERE description = :desc');
    $stmt->execute([':desc' => $marker]);
    $ids = array_column($stmt->fetchAll(), 'id');
}

if ($ids === []) {
    json_response([
        'success' => true,
        'message' => $purgeAll
            ? 'No documents in database.'
            : 'No demo documents found to remove.',
        'deleted' => [],
        'requests_cleared' => 0,
    ]);
}

$pdo->beginTransaction();
try {
    if ($purgeAll) {
        $requestsCleared = (int)$pdo->exec('DELETE FROM document_requests');
        $pdo->exec('DELETE FROM movements');
        $pdo->exec('DELETE FROM documents');
    } else {
        $requestsCleared = 0;
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $pdo->prepare("DELETE FROM movements WHERE document_id IN ($placeholders)")
            ->execute($ids);
        $pdo->prepare("DELETE FROM documents WHERE id IN ($placeholders)")
            ->execute($ids);
    }
    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    json_response([
        'success' => false,
        'message' => 'Purge failed: ' . $e->getMessage(),
    ], 500);
}

json_response([
    'success' => true,
    'message' => count($ids) . ' document(s) removed.',
    'deleted' => $ids,
    'requests_cleared' => $requestsCleared ?? 0,
    'purge_all' => $purgeAll,
]);
