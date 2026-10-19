<?php
// GET /audit-exceptions.php?hours=24
// GET /audit-exceptions.php?hours=24&period=month&month=2026-09   (also period=quarter|year)
// Custody gaps for COA prep:
//   unforwarded     — marked OUT, no IN scan after `hours`
//   wrong_receiver  — OUT to one office but IN at another
//   skipped_office  — reached a control office without the earlier control office in the trail
//                     (DV: BUD before ACC; BUD + ACC before TRE/MAY · Approved Budget: BUD before ACC)
// With a period, only documents active in that period and exceptions dated inside it are returned.
// Auth: admin at Accounting office.

require __DIR__ . '/config.php';
require_once __DIR__ . '/movements-helper.php';
require_once __DIR__ . '/report-period-helper.php';
require_once __DIR__ . '/routing-helper.php';

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

$range = (isset($_GET['period']) || isset($_GET['month'])) ? smartflow_report_period($_GET) : null;
$asOf = $range === null ? date('Y-m-d H:i:s') : min($range['end'], date('Y-m-d H:i:s'));
$cutoff = date('Y-m-d H:i:s', strtotime($asOf) - ($hours * 3600));
$inRange = static fn (string $at): bool => $range === null
    || ($at >= $range['start'] && $at <= $range['end']);

$docSelect = '
    SELECT d.id, d.title, d.type, rf.code AS received_from_code
    FROM documents d
    LEFT JOIN offices rf ON rf.id = d.received_from_office_id
';
if ($range !== null) {
    $stmtDocs = $pdo->prepare($docSelect . '
        WHERE EXISTS (
            SELECT 1 FROM movements pm
            WHERE pm.document_id = d.id AND pm.scanned_at BETWEEN :start AND :end
        )
        ORDER BY d.date_registered DESC
    ');
    $stmtDocs->execute([':start' => $range['start'], ':end' => $range['end']]);
} else {
    // Inspect every trail: older pending folders remain relevant even after
    // hundreds of newer folders have been registered.
    $stmtDocs = $pdo->query($docSelect . ' ORDER BY d.date_registered DESC');
}

$officeNames = [
    'BUD' => 'Budget', 'ACC' => 'Accounting', 'TRE' => 'Treasury', 'MAY' => "Mayor's Office",
];
$label = static fn (string $code): string => ($officeNames[$code] ?? $code) . " ({$code})";

$stmtMv = $pdo->prepare('
    SELECT m.id, m.status, m.scanned_at, m.office_id, m.destination_office_id,
           o.code AS office_code,
           d.code AS destination_code
    FROM movements m
    JOIN offices o ON o.id = m.office_id
    LEFT JOIN offices d ON d.id = m.destination_office_id
    WHERE m.document_id = :id AND m.scanned_at <= :as_of
    ORDER BY m.scanned_at ASC, m.id ASC
');

$exceptions = [];

foreach ($stmtDocs->fetchAll() as $doc) {
    $docId = (string)$doc['id'];
    $stmtMv->execute([':id' => $docId, ':as_of' => $asOf]);
    $mvs = $stmtMv->fetchAll();
    if (!$mvs) {
        continue;
    }
    $base = [
        'document_id' => $docId,
        'title'       => $doc['title'],
        'type'        => $doc['type'],
    ];

    $last = $mvs[count($mvs) - 1];
    $lastScanned = (string)$last['scanned_at'];
    if ((string)$last['status'] === 'OUT' && $lastScanned <= $cutoff && $inRange($lastScanned)) {
        $dest = $last['destination_code'] ?? '?';
        $exceptions[] = $base + [
            'exception_type'  => 'unforwarded',
            'detail'          => "Marked OUT to {$dest} — no IN scan after {$hours}h",
            'last_scanned_at' => $lastScanned,
            'office_code'     => $last['office_code'],
        ];
    }

    for ($i = 1; $i < count($mvs); $i++) {
        $prev = $mvs[$i - 1];
        $cur = $mvs[$i];
        if ($prev['status'] !== 'OUT' || $cur['status'] !== 'IN' || $prev['destination_office_id'] === null) {
            continue;
        }
        if ((int)$cur['office_id'] !== (int)$prev['destination_office_id'] && $inRange((string)$cur['scanned_at'])) {
            $exceptions[] = $base + [
                'exception_type'  => 'wrong_receiver',
                'detail'          => 'OUT to ' . ($prev['destination_code'] ?? '?')
                    . ' but IN at ' . ($cur['office_code'] ?? '?'),
                'last_scanned_at' => (string)$cur['scanned_at'],
                'office_code'     => (string)$cur['office_code'],
            ];
            break;
        }
    }

    $isDv = smartflow_type_is_dv((string)$doc['type']);
    $isBudget = smartflow_type_is_approved_budget((string)$doc['type']);
    if (!$isDv && !$isBudget) {
        continue;
    }
    $seen = [];
    if (!empty($doc['received_from_code'])) {
        $seen[strtoupper((string)$doc['received_from_code'])] = true;
    }
    foreach ($mvs as $idx => $m) {
        if ($m['status'] !== 'IN') {
            continue;
        }
        $code = strtoupper((string)$m['office_code']);
        // The registration scan starts the trail; only later handoffs are checked.
        if ($idx > 0) {
            $required = match (true) {
                $isDv && $code === 'ACC' => ['BUD'],
                $isDv && in_array($code, ['TRE', 'MAY'], true) => ['BUD', 'ACC'],
                $isBudget && $code === 'ACC' => ['BUD'],
                default => [],
            };
            $missing = array_values(array_filter($required, static fn ($c) => empty($seen[$c])));
            if ($missing) {
                if ($inRange((string)$m['scanned_at'])) {
                    $exceptions[] = $base + [
                        'exception_type'  => 'skipped_office',
                        'detail'          => 'Reached ' . $label($code) . ' without '
                            . implode(' and ', array_map($label, $missing)) . ' in the trail',
                        'last_scanned_at' => (string)$m['scanned_at'],
                        'office_code'     => $code,
                    ];
                    break;
                }
            }
        }
        $seen[$code] = true;
    }
}

usort($exceptions, static fn ($a, $b) => strcmp($b['last_scanned_at'], $a['last_scanned_at']));

json_response([
    'success'      => true,
    'hours'        => $hours,
    'period'       => $range['period'] ?? null,
    'period_label' => $range['label'] ?? null,
    'count'        => count($exceptions),
    'exceptions'   => $exceptions,
    'note'         => 'DV and budget custody gaps before COA reporting. Payment is recorded at Treasury; SmartFlow still tracks the physical folder through TRE and MAY.',
]);
