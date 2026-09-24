<?php
// GET /audit-exceptions.php?hours=24
// Custody gaps for COA prep: unforwarded OUT, wrong-office IN, missing receive scan.
// Auth: admin at Accounting office, or any admin.

require __DIR__ . '/config.php';
require_once __DIR__ . '/movements-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
$stmt = $pdo->prepare('
    SELECT u.role, u.office_id, o.code AS office_code
    FROM users u
    JOIN offices o ON o.id = u.office_id
    WHERE u.id = :id AND u.is_active = 1
    LIMIT 1
');
$stmt->execute([':id' => $userId]);
$user = $stmt->fetch();
if (!$user || $user['role'] !== 'admin') {
    json_response(['success' => false, 'message' => 'Accounting administrator access required'], 403);
}
if (strtoupper((string)$user['office_code']) !== 'ACC') {
    json_response(['success' => false, 'message' => 'Audit exceptions are restricted to the Accounting office'], 403);
}

$hours = max(1, min(168, (int)($_GET['hours'] ?? 24)));
$cutoff = date('Y-m-d H:i:s', time() - ($hours * 3600));

$stmtDocs = $pdo->query('
    SELECT d.id, d.title, d.type
    FROM documents d
    ORDER BY d.date_registered DESC
    LIMIT 500
');
$exceptions = [];

foreach ($stmtDocs->fetchAll() as $doc) {
    $docId = (string)$doc['id'];
    $stmtMv = $pdo->prepare('
        SELECT m.id, m.status, m.scanned_at, m.office_id, m.destination_office_id,
               o.code AS office_code,
               d.code AS destination_code
        FROM movements m
        JOIN offices o ON o.id = m.office_id
        LEFT JOIN offices d ON d.id = m.destination_office_id
        WHERE m.document_id = :id
        ORDER BY m.scanned_at ASC, m.id ASC
    ');
    $stmtMv->execute([':id' => $docId]);
    $mvs = $stmtMv->fetchAll();
    if (!$mvs) {
        continue;
    }

    $last = $mvs[count($mvs) - 1];
    $lastStatus = (string)$last['status'];
    $lastScanned = (string)$last['scanned_at'];

    if ($lastStatus === 'OUT' && $lastScanned <= $cutoff) {
        $dest = $last['destination_code'] ?? '?';
        $exceptions[] = [
            'document_id'   => $docId,
            'title'         => $doc['title'],
            'type'          => $doc['type'],
            'exception_type' => 'unforwarded',
            'detail'        => "Marked OUT to {$dest} — no IN scan after {$hours}h",
            'last_scanned_at' => $lastScanned,
            'office_code'   => $last['office_code'],
        ];
        continue;
    }

    for ($i = 1; $i < count($mvs); $i++) {
        $prev = $mvs[$i - 1];
        $cur = $mvs[$i];
        if ($prev['status'] !== 'OUT' || $cur['status'] !== 'IN') {
            continue;
        }
        $expectedDest = $prev['destination_office_id'] !== null
            ? (int)$prev['destination_office_id'] : null;
        if ($expectedDest === null) {
            continue;
        }
        if ((int)$cur['office_id'] !== $expectedDest) {
            $exceptions[] = [
                'document_id'   => $docId,
                'title'         => $doc['title'],
                'type'          => $doc['type'],
                'exception_type' => 'wrong_receiver',
                'detail'        => 'OUT to ' . ($prev['destination_code'] ?? '?')
                    . ' but IN at ' . ($cur['office_code'] ?? '?'),
                'last_scanned_at' => (string)$cur['scanned_at'],
                'office_code'   => (string)$cur['office_code'],
            ];
            break;
        }
    }
}

json_response([
    'success'    => true,
    'hours'      => $hours,
    'count'      => count($exceptions),
    'exceptions' => $exceptions,
    'note'       => 'DV and budget custody gaps before COA reporting. Payment is recorded at Treasury; SmartFlow still tracks the physical folder through TRE and MAY.',
]);
