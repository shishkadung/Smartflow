<?php
// GET /qr-token-issue.php?id=DOC-2026-000001
// Issues a fresh signed QR payload for printing (auth required).

require __DIR__ . '/config.php';
require_once __DIR__ . '/qr-token-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

require_user_id();

$id = strtoupper(trim((string)($_GET['id'] ?? '')));
if ($id === '') {
    json_response(['success' => false, 'message' => 'Missing id'], 400);
}

$stmtDoc = $pdo->prepare('SELECT id FROM documents WHERE id = :id LIMIT 1');
$stmtDoc->execute([':id' => $id]);
if (!$stmtDoc->fetch()) {
    json_response(['success' => false, 'message' => 'Document not found'], 404);
}

try {
    $issued = smartflow_qr_issue($id);
} catch (InvalidArgumentException $e) {
    json_response(['success' => false, 'message' => 'Invalid document id'], 400);
}

json_response([
    'success' => true,
    'document_id' => $issued['document_id'],
    'qr_payload' => $issued['payload'],
    'issued_at' => $issued['issued_at'],
    'expires_at' => $issued['expires_at'],
    'expires_at_unix' => $issued['expires_at_unix'],
    'ttl_days' => (int)round(SMARTFLOW_QR_TTL_SECONDS / 86400),
]);
