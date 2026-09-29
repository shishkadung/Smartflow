<?php
// GET /reports-summary.php?month=2026-04&office_id=4
// GET /reports-summary.php?period=quarter&year=2026&quarter=2&office_id=4
// GET /reports-summary.php?period=year&year=2026&office_id=4
// Builds the COA Support Summary numbers (monthly, quarterly, or annual):
//   - compliance: completed-on-time / unforwarded / delayed (% of total docs)
//   - office_totals: documents processed by each office in the month
//   - this_office: spotlight counts for the requesting office
// Auth: Bearer token required.

require __DIR__ . '/config.php';
require_once __DIR__ . '/report-period-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response([
        'success' => false,
        'message' => 'Method not allowed',
    ], 405);
}

$userId = require_user_id();

$stmtUser = $pdo->prepare('
    SELECT u.role, u.office_id, o.code AS office_code
    FROM users u
    JOIN offices o ON o.id = u.office_id
    WHERE u.id = :id AND u.is_active = 1
    LIMIT 1
');
$stmtUser->execute([':id' => $userId]);
$caller = $stmtUser->fetch();
if (!$caller || $caller['role'] !== 'admin') {
    json_response([
        'success' => false,
        'message' => 'COA summaries are available to administrators only',
    ], 403);
}
$exportAllowed = strtoupper((string)$caller['office_code']) === 'ACC';

$officeId = (int)($_GET['office_id'] ?? 0);
if ($officeId <= 0) {
    json_response([
        'success' => false,
        'message' => 'office_id is required',
    ], 400);
}

$range = smartflow_report_period($_GET);
$period = $range['period'];
$month = $range['month'];
$quarter = $range['quarter'];
$year = $range['year'];
$monthStart = $range['start'];
$monthEnd = $range['end'];
$periodLabel = $range['label'];

// Total documents that had any activity this month.
$stmtTotal = $pdo->prepare('
    SELECT COUNT(DISTINCT document_id) AS c
    FROM movements
    WHERE scanned_at BETWEEN :start AND :end
');
$stmtTotal->execute([':start' => $monthStart, ':end' => $monthEnd]);
$totalDocs = (int)($stmtTotal->fetch()['c'] ?? 0);

// Compliance (per document with activity this month):
//   on_time      — receive within 72h after an OUT, OR still IN at an office (not forwarded yet)
//   unforwarded  — latest movement is OUT (sent, awaiting receive scan elsewhere)
//   delayed      — received more than 72h after the preceding OUT
$stmtDocs = $pdo->prepare('
    SELECT DISTINCT document_id
    FROM movements
    WHERE scanned_at BETWEEN :start AND :end
');
$stmtDocs->execute([':start' => $monthStart, ':end' => $monthEnd]);
$docIds = array_map(fn($r) => $r['document_id'], $stmtDocs->fetchAll());

$onTime = 0;
$unforwarded = 0;
$delayed = 0;

foreach ($docIds as $docId) {
    $stmtMv = $pdo->prepare('
        SELECT status, scanned_at
        FROM movements
        WHERE document_id = :id
        ORDER BY scanned_at ASC, id ASC
    ');
    $stmtMv->execute([':id' => $docId]);
    $mvs = $stmtMv->fetchAll();
    if (!$mvs) {
        continue;
    }

    $lastOut = null;
    $matchedOnTime = false;
    $hadIn = false;
    $hadOut = false;

    foreach ($mvs as $m) {
        if ($m['status'] === 'OUT') {
            $hadOut = true;
            $lastOut = $m['scanned_at'];
        } elseif ($m['status'] === 'IN') {
            $hadIn = true;
            if ($lastOut !== null) {
                $hours = (strtotime($m['scanned_at']) - strtotime($lastOut)) / 3600;
                if ($hours <= 72) {
                    $matchedOnTime = true;
                }
                $lastOut = null;
            }
        }
    }

    $lastStatus = $mvs[count($mvs) - 1]['status'];

    if ($lastStatus === 'OUT') {
        // Forwarded; next office has not scanned IN yet.
        $unforwarded++;
    } elseif ($matchedOnTime) {
        $onTime++;
    } elseif ($hadIn && !$hadOut) {
        // Only received at an office (e.g. after register + IN scan) — still in process, not delayed.
        $onTime++;
    } else {
        $delayed++;
    }
}

$pct = function (int $n) use ($totalDocs): int {
    return $totalDocs > 0 ? (int)round(($n / $totalDocs) * 100) : 0;
};

// Office totals: count of distinct documents that touched each office this month.
$stmtOffices = $pdo->prepare('
    SELECT o.id, o.name, o.code,
           COUNT(DISTINCT m.document_id) AS docs_processed
    FROM offices o
    LEFT JOIN movements m
        ON m.office_id = o.id
       AND m.scanned_at BETWEEN :start AND :end
    GROUP BY o.id, o.name, o.code
    ORDER BY o.name ASC
');
$stmtOffices->execute([':start' => $monthStart, ':end' => $monthEnd]);
$offices = array_map(function ($r) {
    return [
        'office_id'      => (int)$r['id'],
        'office_name'    => $r['name'],
        'office_code'    => $r['code'],
        'docs_processed' => (int)$r['docs_processed'],
    ];
}, $stmtOffices->fetchAll());

// Spotlight: the requesting office's headline number.
$stmtThis = $pdo->prepare('
    SELECT COUNT(DISTINCT document_id) AS c
    FROM movements
    WHERE office_id = :oid AND scanned_at BETWEEN :start AND :end
');
$stmtThis->execute([':oid' => $officeId, ':start' => $monthStart, ':end' => $monthEnd]);
$thisOfficeDocs = (int)($stmtThis->fetch()['c'] ?? 0);

json_response([
    'success' => true,
    'period'  => $period,
    'month'   => $month,
    'quarter' => $quarter,
    'year'    => $year,
    'period_label' => $periodLabel,
    'office_id' => $officeId,
    'export_allowed' => $exportAllowed,
    'submission_note' => match ($period) {
        'year'    => 'Annual custody summary for COA preparation — pair with the monthly DV and collection reports already submitted.',
        'quarter' => 'Quarterly custody summary for COA preparation — covers the three monthly DV and collection report periods.',
        default   => 'DV and collection reports are typically submitted by the 10th day of the following month (client practice).',
    },
    'totals' => [
        'documents_in_period' => $totalDocs,
        'this_office_documents' => $thisOfficeDocs,
    ],
    'compliance' => [
        'on_time' => [
            'count'   => $onTime,
            'percent' => $pct($onTime),
        ],
        'unforwarded' => [
            'count'   => $unforwarded,
            'percent' => $pct($unforwarded),
        ],
        'delayed' => [
            'count'   => $delayed,
            'percent' => $pct($delayed),
        ],
    ],
    'office_totals' => $offices,
]);
