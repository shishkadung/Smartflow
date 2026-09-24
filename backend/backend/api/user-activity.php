<?php
// GET /user-activity.php?office_id=4&limit=50
// Returns scan/register activity for the logged-in user only (not full document audit trails).

require __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
$officeId = (int)($_GET['office_id'] ?? 0);
$limit = (int)($_GET['limit'] ?? 50);
if ($limit <= 0 || $limit > 100) {
    $limit = 50;
}

$movementSql = '
    SELECT
        m.document_id,
        d.title AS document_title,
        d.type AS document_type,
        m.status AS action,
        m.scanned_at AS activity_at,
        o.name AS office_name,
        o.code AS office_code,
        m.remarks
    FROM movements m
    JOIN documents d ON d.id = m.document_id
    JOIN offices o ON o.id = m.office_id
    WHERE m.user_id = :user_id
';
$params = [':user_id' => $userId];

if ($officeId > 0) {
    $movementSql .= ' AND m.office_id = :office_id';
    $params[':office_id'] = $officeId;
}

$stmtM = $pdo->prepare($movementSql);
$stmtM->execute($params);
$movements = $stmtM->fetchAll();

$registerSql = '
    SELECT
        d.id AS document_id,
        d.title AS document_title,
        d.type AS document_type,
        d.date_registered AS activity_at,
        o.name AS office_name,
        o.code AS office_code
    FROM documents d
    JOIN offices o ON o.id = d.origin_office_id
    WHERE d.created_by = :user_id
';
$registerParams = [':user_id' => $userId];
if ($officeId > 0) {
    $registerSql .= ' AND d.origin_office_id = :office_id';
    $registerParams[':office_id'] = $officeId;
}

$stmtR = $pdo->prepare($registerSql);
$stmtR->execute($registerParams);
$registered = $stmtR->fetchAll();

$activities = [];

foreach ($movements as $r) {
    $activities[] = [
        'document_id' => $r['document_id'],
        'document_title' => $r['document_title'],
        'document_type' => $r['document_type'],
        'action' => $r['action'],
        'activity_at' => $r['activity_at'],
        'office_name' => $r['office_name'],
        'office_code' => $r['office_code'],
        'remarks' => $r['remarks'],
    ];
}

foreach ($registered as $r) {
    $activities[] = [
        'document_id' => $r['document_id'],
        'document_title' => $r['document_title'],
        'document_type' => $r['document_type'],
        'action' => 'REGISTERED',
        'activity_at' => $r['activity_at'],
        'office_name' => $r['office_name'],
        'office_code' => $r['office_code'],
        'remarks' => 'Document registered',
    ];
}

usort($activities, function ($a, $b) {
    return strcmp($b['activity_at'], $a['activity_at']);
});

$activities = array_slice($activities, 0, $limit);

json_response([
    'success' => true,
    'user_id' => $userId,
    'count' => count($activities),
    'activities' => $activities,
]);
