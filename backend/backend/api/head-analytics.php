<?php
// GET /head-analytics.php?office_id=1&month=2026-05
// Department head: office-scoped performance analytics (not municipal COA report).
// Auth: Bearer token required.

require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

require_user_id();

$officeId = (int)($_GET['office_id'] ?? 0);
$month = trim((string)($_GET['month'] ?? date('Y-m')));
if ($officeId <= 0) {
    json_response(['success' => false, 'message' => 'office_id is required'], 400);
}
if (!preg_match('/^\d{4}-\d{2}$/', $month)) {
    json_response(['success' => false, 'message' => 'month must be YYYY-MM'], 400);
}

$monthStart = $month . '-01 00:00:00';
$monthEnd   = date('Y-m-t 23:59:59', strtotime($monthStart));
smartflow_ensure_processing_thresholds($pdo);

$stmtProcessed = $pdo->prepare('
    SELECT COUNT(DISTINCT document_id) AS c
    FROM movements
    WHERE office_id = :oid
      AND status = \'IN\'
      AND scanned_at BETWEEN :start AND :end
');
$stmtProcessed->execute([':oid' => $officeId, ':start' => $monthStart, ':end' => $monthEnd]);
$processed = (int)($stmtProcessed->fetch()['c'] ?? 0);

$stmtCounts = $pdo->prepare("
    SELECT
        COUNT(DISTINCT CASE
            WHEN (
                (t.out_min_scanned_at IS NULL AND
                 TIMESTAMPDIFF(HOUR, t.in_scanned_at, NOW()) >= t.maxh)
                OR
                (t.out_min_scanned_at IS NOT NULL AND
                 TIMESTAMPDIFF(HOUR, t.in_scanned_at, t.out_min_scanned_at) >= t.maxh)
            )
            THEN t.document_id
        END) AS delayed_count,

        COUNT(DISTINCT CASE
            WHEN t.out_min_scanned_at IS NOT NULL
             AND TIMESTAMPDIFF(HOUR, t.in_scanned_at, t.out_min_scanned_at) < t.maxh
            THEN t.document_id
        END) AS on_time_count,

        COUNT(DISTINCT CASE
            WHEN t.out_min_scanned_at IS NULL
             AND TIMESTAMPDIFF(HOUR, t.in_scanned_at, NOW()) < t.maxh
            THEN t.document_id
        END) AS unforwarded_count
    FROM (
        SELECT
            m.document_id,
            m.scanned_at AS in_scanned_at,
            (
                SELECT MIN(m2.scanned_at)
                FROM movements m2
                WHERE m2.document_id = m.document_id
                  AND m2.scanned_at > m.scanned_at
                  AND m2.status = 'OUT'
                  AND m2.office_id = m.office_id
            ) AS out_min_scanned_at,
            COALESCE(pt.max_hours, 48) AS maxh
        FROM movements m
        JOIN documents d ON d.id = m.document_id
        LEFT JOIN processing_thresholds pt
               ON pt.office_id = m.office_id
              AND pt.document_type = d.type
              AND pt.is_active = 1
        WHERE m.office_id = :oid
          AND m.status = 'IN'
          AND m.scanned_at BETWEEN :start AND :end
    ) t
");
$stmtCounts->execute([
    ':oid' => $officeId,
    ':start' => $monthStart,
    ':end' => $monthEnd,
]);
$counts = $stmtCounts->fetch();

$delayedCount = (int)($counts['delayed_count'] ?? 0);
$onTimeCount = (int)($counts['on_time_count'] ?? 0);
$unforwardedCount = (int)($counts['unforwarded_count'] ?? 0);

$onTimePercent = $processed > 0 ? (int)round(($onTimeCount / $processed) * 100) : 0;
$unforwardedPercent = $processed > 0
    ? (int)round(($unforwardedCount / $processed) * 100)
    : 0;
$delayedPercent = $processed > 0 ? (int)round(($delayedCount / $processed) * 100) : 0;

// Back-compat for the Flutter client.
$lateCount = $delayedCount;

$stmtSlow = $pdo->prepare("
    SELECT t.document_id, t.hours_at
    FROM (
        SELECT
            t0.document_id,
            TIMESTAMPDIFF(HOUR, t0.in_scanned_at,
                COALESCE(t0.out_min_scanned_at, NOW())
            ) AS hours_at,
            t0.maxh
        FROM (
            SELECT
                m.document_id,
                m.scanned_at AS in_scanned_at,
                (
                    SELECT MIN(m2.scanned_at)
                    FROM movements m2
                    WHERE m2.document_id = m.document_id
                      AND m2.scanned_at > m.scanned_at
                      AND m2.status = 'OUT'
                      AND m2.office_id = m.office_id
                ) AS out_min_scanned_at,
                COALESCE(pt.max_hours, 48) AS maxh
            FROM movements m
            JOIN documents d ON d.id = m.document_id
            LEFT JOIN processing_thresholds pt
                   ON pt.office_id = m.office_id
                  AND pt.document_type = d.type
                  AND pt.is_active = 1
            WHERE m.office_id = :oid
              AND m.status = 'IN'
              AND m.scanned_at BETWEEN :start AND :end
        ) t0
    ) t
    WHERE t.hours_at >= t.maxh
    ORDER BY t.hours_at DESC
    LIMIT 10
");
$stmtSlow->execute([
    ':oid' => $officeId,
    ':start' => $monthStart,
    ':end' => $monthEnd,
]);
$slowDocs = array_map(function ($r) {
    return [
        'document_id' => $r['document_id'],
        'hours'         => (int)$r['hours_at'],
    ];
}, $stmtSlow->fetchAll());

json_response([
    'success'   => true,
    'office_id' => $officeId,
    'month'     => $month,
    'stats' => [
        'processed'       => $processed,
        // Back-compat: older client uses `late_count` as “delayed”.
        'late_count' => $lateCount,
        'on_time_percent' => $onTimePercent,
        // 3-way breakdown for the compliance tiles.
        'on_time_count' => $onTimeCount,
        'unforwarded_count' => $unforwardedCount,
        'delayed_count' => $delayedCount,
        'unforwarded_percent' => $unforwardedPercent,
        'delayed_percent' => $delayedPercent,
    ],
    'slow_documents' => $slowDocs,
]);
