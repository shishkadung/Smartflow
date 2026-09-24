<?php
// GET /qr?id=DOC-2026-000001&size=250
// Returns a QR PNG (via redirect to a QR image generator).
// Auth: Bearer token required.
//
// Note: This approach requires internet access. If you want offline QR generation,
// we can replace this with a bundled PHP QR library later.

require __DIR__ . '/config.php';
require_once __DIR__ . '/qr-token-helper.php';

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

// Optional: ensure document exists before generating QR
$stmtDoc = $pdo->prepare('SELECT id FROM documents WHERE id = :id LIMIT 1');
$stmtDoc->execute([':id' => $id]);
if (!$stmtDoc->fetch()) {
    json_response([
        'success' => false,
        'message' => 'Document not found',
    ], 404);
}

$size = (int)($_GET['size'] ?? 250);
if ($size < 100) $size = 100;
if ($size > 800) $size = 800;

try {
    $qrIssued = smartflow_qr_issue($id);
} catch (InvalidArgumentException $e) {
    json_response(['success' => false, 'message' => 'Invalid document id'], 400);
}

// Redirect to QR image generator (PNG) — encodes signed payload, not raw id.
$data = rawurlencode($qrIssued['payload']);
$dimension = $size . 'x' . $size;
$url = "https://api.qrserver.com/v1/create-qr-code/?size={$dimension}&data={$data}";

header('Location: ' . $url, true, 302);
exit;

