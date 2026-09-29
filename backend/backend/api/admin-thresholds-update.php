<?php
// POST /admin-thresholds-update.php
// Body: { office_id, document_type, max_hours, out_unconfirmed_hours }
// Admin only — updates processing time thresholds.

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/audit-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
smartflow_require_admin($pdo, $userId);
smartflow_ensure_processing_thresholds($pdo);

$body = get_json_body();
$officeId = (int)($body['office_id'] ?? 0);
$documentType = trim((string)($body['document_type'] ?? ''));
$maxHours = (int)($body['max_hours'] ?? 0);
$outHours = (int)($body['out_unconfirmed_hours'] ?? 0);

if ($officeId <= 0 || $documentType === '') {
    json_response(['success' => false, 'message' => 'office_id and document_type are required'], 400);
}
if ($maxHours < 1 || $maxHours > 720) {
    json_response(['success' => false, 'message' => 'max_hours must be between 1 and 720'], 400);
}
if ($outHours < 1 || $outHours > 168) {
    json_response(['success' => false, 'message' => 'out_unconfirmed_hours must be between 1 and 168'], 400);
}

$stmtPrev = $pdo->prepare('
    SELECT t.max_hours, t.out_unconfirmed_hours, o.code AS office_code
    FROM offices o
    LEFT JOIN processing_thresholds t ON t.office_id = o.id AND t.document_type = :type
    WHERE o.id = :oid
    LIMIT 1
');
$stmtPrev->execute([':oid' => $officeId, ':type' => $documentType]);
$prev = $stmtPrev->fetch();
if (!$prev) {
    json_response(['success' => false, 'message' => 'Office not found'], 404);
}

$stmt = $pdo->prepare('
    INSERT INTO processing_thresholds (office_id, document_type, max_hours, out_unconfirmed_hours)
    VALUES (:oid, :type, :maxh, :outh)
    ON DUPLICATE KEY UPDATE
        max_hours = VALUES(max_hours),
        out_unconfirmed_hours = VALUES(out_unconfirmed_hours),
        is_active = 1
');
$stmt->execute([
    ':oid'  => $officeId,
    ':type' => $documentType,
    ':maxh' => $maxHours,
    ':outh' => $outHours,
]);

smartflow_audit_action(
    $pdo,
    'threshold.update',
    $userId,
    sprintf('Threshold %s / %s: %dh processing, %dh unconfirmed OUT', $prev['office_code'], $documentType, $maxHours, $outHours),
    [
        'office_id'                  => $officeId,
        'office_code'                => $prev['office_code'],
        'document_type'              => $documentType,
        'old_max_hours'              => $prev['max_hours'] !== null ? (int)$prev['max_hours'] : null,
        'old_out_unconfirmed_hours'  => $prev['out_unconfirmed_hours'] !== null ? (int)$prev['out_unconfirmed_hours'] : null,
        'max_hours'                  => $maxHours,
        'out_unconfirmed_hours'      => $outHours,
    ]
);

json_response([
    'success' => true,
    'threshold' => [
        'office_id'             => $officeId,
        'document_type'         => $documentType,
        'max_hours'             => $maxHours,
        'out_unconfirmed_hours' => $outHours,
    ],
]);
