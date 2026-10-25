<?php
declare(strict_types=1);

require_once __DIR__ . '/routing-helper.php';

/**
 * Whether a folder's custody trail was finished at the report cutoff. Same rule as
 * smartflow_sql_trail_complete_known_latest(), evaluated only on the movements known at the cutoff:
 * the latest movement is an IN and the folder was explicitly filed, or it is a DV that reached Treasury
 * (or Accounting after Treasury) following the Mayor, or an Approved Budget received at Accounting after Budget.
 *
 * @param list<array{status:string, office_code:string, scanned_at:string}> $movements oldest first, already bounded by the cutoff
 */
function smartflow_report_trail_complete(array $movements, string $type, ?string $filedAt, string $asOf): bool
{
    if (!$movements) {
        return false;
    }
    $latest = $movements[array_key_last($movements)];
    if ($latest['status'] !== 'IN') {
        return false;
    }
    if ($filedAt !== null && $filedAt <= $asOf) {
        return true;
    }
    $visited = [];
    foreach ($movements as $movement) {
        if ($movement['status'] === 'IN') {
            $visited[strtoupper((string)$movement['office_code'])] = true;
        }
    }
    $office = strtoupper((string)$latest['office_code']);
    $dvComplete = smartflow_type_is_dv($type) && isset($visited['MAY'])
        && ($office === 'TRE' || ($office === 'ACC' && isset($visited['TRE'])));
    $budgetComplete = $office === 'ACC' && smartflow_type_is_approved_budget($type) && isset($visited['BUD']);

    return $dvComplete || $budgetComplete;
}

/**
 * How many of the folders with activity in the period had a finished trail at the cutoff.
 *
 * @param list<string> $documentIds
 */
function smartflow_report_completed_count(PDO $pdo, array $documentIds, string $asOf, int $movementWatermark): int
{
    $completed = 0;
    foreach (array_chunk($documentIds, 400) as $chunk) {
        $slots = implode(',', array_fill(0, count($chunk), '?'));
        $stmtDocs = $pdo->prepare("SELECT id, type, filed_at FROM documents WHERE id IN ($slots)");
        $stmtDocs->execute($chunk);
        $documents = [];
        foreach ($stmtDocs->fetchAll() as $row) {
            $documents[$row['id']] = $row;
        }
        $stmtMovements = $pdo->prepare("
            SELECT m.document_id, m.status, m.scanned_at, o.code AS office_code
            FROM movements m
            JOIN offices o ON o.id = m.office_id
            WHERE m.document_id IN ($slots) AND m.scanned_at <= ? AND m.id <= ?
            ORDER BY m.document_id, m.scanned_at ASC, m.id ASC
        ");
        $stmtMovements->execute([...$chunk, $asOf, $movementWatermark]);
        $byDocument = [];
        foreach ($stmtMovements->fetchAll() as $row) {
            $byDocument[$row['document_id']][] = $row;
        }
        foreach ($chunk as $id) {
            if (isset($documents[$id])
                && smartflow_report_trail_complete($byDocument[$id] ?? [], (string)$documents[$id]['type'], $documents[$id]['filed_at'], $asOf)) {
                $completed++;
            }
        }
    }

    return $completed;
}

/**
 * Time folders spent at each office: every IN recorded in the period, paired with the next OUT from the same
 * office for the same folder (recorded by the cutoff). Stays with no OUT yet are counted but never averaged.
 *
 * @return array<int, array{closed:int, open:int, seconds:float}> keyed by office id
 */
function smartflow_report_office_stays(PDO $pdo, string $periodStart, string $asOf, int $movementWatermark): array
{
    $stmt = $pdo->prepare("
        SELECT stay.office_id,
               SUM(stay.out_at IS NOT NULL) AS closed,
               SUM(stay.out_at IS NULL) AS open,
               COALESCE(SUM(CASE WHEN stay.out_at IS NOT NULL THEN TIMESTAMPDIFF(SECOND, stay.in_at, stay.out_at) END), 0) AS seconds
        FROM (
            SELECT i.office_id, i.scanned_at AS in_at,
                   (SELECT x.scanned_at FROM movements x
                    WHERE x.document_id = i.document_id AND x.office_id = i.office_id AND x.status = 'OUT'
                      AND x.id <= :out_watermark AND x.scanned_at <= :out_end
                      AND (x.scanned_at > i.scanned_at OR (x.scanned_at = i.scanned_at AND x.id > i.id))
                    ORDER BY x.scanned_at ASC, x.id ASC LIMIT 1) AS out_at
            FROM movements i
            WHERE i.status = 'IN' AND i.scanned_at BETWEEN :start AND :end AND i.id <= :watermark
        ) stay
        GROUP BY stay.office_id
    ");
    $stmt->execute([
        ':out_watermark' => $movementWatermark, ':out_end' => $asOf,
        ':start' => $periodStart, ':end' => $asOf, ':watermark' => $movementWatermark,
    ]);
    $stays = [];
    foreach ($stmt->fetchAll() as $row) {
        $stays[(int)$row['office_id']] = ['closed' => (int)$row['closed'], 'open' => (int)$row['open'], 'seconds' => (float)$row['seconds']];
    }

    return $stays;
}

function smartflow_report_average_hours(int $closedStays, float $seconds): ?float
{
    return $closedStays > 0 ? round($seconds / $closedStays / 3600, 1) : null;
}

function smartflow_report_completion_note(): string
{
    return 'Completion counts the folders with activity in the period whose custody trail was finished at the cutoff: explicitly filed, a Disbursement Voucher received at Treasury after the Mayor (or at Accounting after Treasury), or an Approved Budget received at Accounting after Budget. Other folders count as complete only when filed. It measures the physical trail, not financial approval or payment.';
}

function smartflow_report_processing_note(): string
{
    return 'Average time at an office is the mean number of calendar hours between a folder being received (IN) at that office in the period and the next time that office sent it (OUT) by the cutoff. Folders still at the office with no OUT are counted separately and are not averaged, so the figure covers forwarded folders only.';
}
