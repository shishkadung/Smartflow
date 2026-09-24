<?php
// POST /qr-verify.php  Body: { "qr": "SF1...." }
// GET  /qr-verify.php?qr=SF1....
// Auth: Bearer token required

require __DIR__ . '/config.php';
require_once __DIR__ . '/qr-token-helper.php';
require_once __DIR__ . '/movements-helper.php';

if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'POST'], true)) {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();

$qr = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body = get_json_body();
    $qr = trim((string)($body['qr'] ?? $body['qr_payload'] ?? ''));
} else {
    $qr = trim((string)($_GET['qr'] ?? $_GET['qr_payload'] ?? ''));
}

if ($qr === '') {
    json_response([
        'success' => false,
        'message' => 'Missing qr payload',
        'qr_error' => 'invalid',
    ], 400);
}

$result = smartflow_qr_verify($qr);

if (!$result['valid']) {
    smartflow_write_audit_log(
        $pdo,
        'qr.verify',
        $result['document_id'],
        $userId,
        null,
        null,
        'rejected',
        (string)$result['message'],
        ['qr_reason' => $result['reason']]
    );
    json_response([
        'success' => false,
        'message' => $result['message'],
        'qr_error' => $result['reason'],
        'document_id' => $result['document_id'],
    ], 403);
}

$documentId = (string)$result['document_id'];
$stmtDoc = $pdo->prepare('SELECT id, title FROM documents WHERE id = :id LIMIT 1');
$stmtDoc->execute([':id' => $documentId]);
$doc = $stmtDoc->fetch();
if (!$doc) {
    smartflow_write_audit_log(
        $pdo,
        'qr.verify',
        $documentId,
        $userId,
        null,
        null,
        'rejected',
        'Document not found for verified QR'
    );
    json_response([
        'success' => false,
        'message' => 'Document not found for this QR label',
        'qr_error' => 'not_found',
    ], 404);
}

smartflow_write_audit_log(
    $pdo,
    'qr.verify',
    $documentId,
    $userId,
    null,
    null,
    'success',
    'Secured QR verified'
);

json_response([
    'success' => true,
    'message' => 'QR verified',
    'document_id' => $documentId,
    'issued_at' => $result['issued_at'],
    'expires_at' => $result['expires_at'],
    'qr_payload' => $qr,
]);
