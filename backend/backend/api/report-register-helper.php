<?php
declare(strict_types=1);

/** Keep the existing report's receipt classification, including late-receipt precedence. */
function smartflow_report_classification(array $movements, string $periodStart): string
{
    $lastOut = null;
    $hadIn = false;
    $matchedLate = false;
    foreach ($movements as $movement) {
        if ($movement['status'] === 'OUT') {
            $lastOut = $movement['scanned_at'];
        } elseif ($movement['status'] === 'IN') {
            $hadIn = true;
            if ($lastOut !== null) {
                if ($movement['scanned_at'] >= $periodStart
                    && strtotime($movement['scanned_at']) - strtotime($lastOut) > 72 * 3600) {
                    $matchedLate = true;
                }
                $lastOut = null;
            }
        }
    }
    if ($matchedLate) return 'delayed';
    if ($movements && $movements[array_key_last($movements)]['status'] === 'OUT') return 'unforwarded';
    return $hadIn ? 'on_time' : 'delayed';
}

function smartflow_report_classification_note(): string
{
    return 'Activity counts distinct folders with a recorded movement in the period. A receipt more than 72 calendar hours after its preceding OUT takes precedence as Delayed; otherwise the latest OUT is Awaiting receipt (Unforwarded). Other folders with an IN are On time / in custody. These are receipt classifications, not desk-deadline compliance, financial approval or proof of completed processing.';
}

/** An explicit cutoff lets preview, supporting rows and export share one clock. */
function smartflow_report_as_of(array $query, array $range): string
{
    $latest = min($range['end'], date('Y-m-d H:i:s'));
    if (!isset($query['as_of'])) return $latest;
    $value = $query['as_of'];
    $parsed = is_string($value) && preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/D', $value)
        ? DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $value) : false;
    if (!$parsed || $parsed->format('Y-m-d H:i:s') !== $value || $value < $range['start'] || $value > $latest) {
        json_response(['success' => false, 'message' => 'as_of must be a valid local timestamp within the reporting period and no later than now'], 400);
    }
    return $value;
}

function smartflow_report_has_corrections(PDO $pdo): bool
{
    static $exists = null;
    if ($exists === null) {
        $read = $pdo->query("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='movement_destination_corrections'");
        $exists = (int)$read->fetchColumn() > 0;
    }
    return $exists;
}

/** Bound the event set as well as its timestamps, including backdated appends. */
function smartflow_report_watermarks(PDO $pdo, array $query): array
{
    $maximums = [
        'movement_watermark' => (int)$pdo->query('SELECT COALESCE(MAX(id), 0) FROM movements')->fetchColumn(),
        'correction_watermark' => smartflow_report_has_corrections($pdo)
            ? (int)$pdo->query('SELECT COALESCE(MAX(id), 0) FROM movement_destination_corrections')->fetchColumn() : 0,
    ];
    $watermarks = [];
    foreach ($maximums as $key => $maximum) {
        $value = array_key_exists($key, $query) ? filter_var($query[$key], FILTER_VALIDATE_INT, ['options' => ['min_range' => 0, 'max_range' => $maximum]]) : $maximum;
        if ($value === false) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            json_response(['success' => false, 'message' => 'Invalid report event watermark'], 400);
        }
        $watermarks[$key] = $value;
    }
    return $watermarks;
}

/**
 * The latest movement, receipt and sender are all bounded by the same cutoff.
 * office_id filters that latest custody/sending office, not every office touched.
 * Existing endpoint bootstrap owns schema setup; this helper performs reads only.
 *
 * @return array{sql:string, bindings:array}
 */
function smartflow_report_register_query(PDO $pdo, string $periodStart, string $asOf, array $filters = []): array
{
    // An OUT destination is editable. Undo only corrections recorded after the
    // cutoff so a historical report does not acquire today's corrected receiver.
    $destination = smartflow_report_has_corrections($pdo)
        ? 'COALESCE((SELECT c.previous_destination_office_id FROM movement_destination_corrections c WHERE c.movement_id=latest.id AND (c.corrected_at > :as_of OR c.id > :correction_watermark) ORDER BY c.id ASC LIMIT 1), latest.destination_office_id)'
        : 'latest.destination_office_id';
    $activity = ($filters['scope'] ?? 'activity') === 'outstanding'
        ? "latest.status='OUT'"
        : 'EXISTS (SELECT 1 FROM movements activity WHERE activity.document_id=d.id AND activity.id <= :movement_watermark AND activity.scanned_at BETWEEN :period_start AND :as_of)';
    // With IN/OUT trails, an IN pairs only with an immediately preceding OUT:
    // each IN consumes the pending OUT, and a subsequent OUT replaces it.
    $classification = "CASE WHEN EXISTS (
        SELECT 1 FROM movements receipt
        JOIN movements sent ON sent.id=(
            SELECT previous.id FROM movements previous
            WHERE previous.document_id=receipt.document_id
              AND previous.id <= :movement_watermark
              AND previous.status IN ('IN', 'OUT')
              AND (previous.scanned_at < receipt.scanned_at OR (previous.scanned_at=receipt.scanned_at AND previous.id < receipt.id))
            ORDER BY previous.scanned_at DESC, previous.id DESC LIMIT 1
        )
        WHERE receipt.document_id=d.id AND receipt.status='IN' AND receipt.id <= :movement_watermark
          AND receipt.scanned_at BETWEEN :period_start AND :as_of
          AND sent.status='OUT' AND TIMESTAMPDIFF(SECOND, sent.scanned_at, receipt.scanned_at) > 259200
    ) THEN 'delayed' WHEN latest.status='OUT' THEN 'unforwarded'
    WHEN received.id IS NOT NULL THEN 'on_time' ELSE 'delayed' END";
    $sql = "SELECT d.id AS document_id, d.title, d.type, {$classification} AS classification,
        latest.status AS current_status, latest.office_id AS current_office_id,
        office.name AS current_office_name, office.code AS current_office_code,
        destination.id AS destination_office_id, destination.name AS destination_office_name,
        destination.code AS destination_office_code, latest.scanned_at AS last_scanned_at,
        recorder.name AS recorded_by, received.scanned_at AS last_received_at,
        receiver.name AS received_by, sent_last.scanned_at AS last_sent_at, sender.name AS sent_by,
        CASE WHEN latest.status='OUT' THEN ROUND(TIMESTAMPDIFF(SECOND, latest.scanned_at, :as_of)/3600, 1) ELSE NULL END AS receipt_wait_hours,
        (SELECT COUNT(*) FROM movements counted WHERE counted.document_id=d.id AND counted.id <= :movement_watermark AND counted.scanned_at <= :as_of) AS movement_count,
        (latest.status='OUT' AND latest.scanned_at < :period_start) AS carried_forward
        FROM documents d
        JOIN movements latest ON latest.id=(SELECT last_m.id FROM movements last_m WHERE last_m.document_id=d.id AND last_m.id <= :movement_watermark AND last_m.scanned_at <= :as_of ORDER BY last_m.scanned_at DESC, last_m.id DESC LIMIT 1)
        JOIN offices office ON office.id=latest.office_id
        LEFT JOIN offices destination ON destination.id={$destination}
        LEFT JOIN users recorder ON recorder.id=latest.user_id
        LEFT JOIN movements received ON received.id=(SELECT last_in.id FROM movements last_in WHERE last_in.document_id=d.id AND last_in.id <= :movement_watermark AND last_in.status='IN' AND last_in.scanned_at <= :as_of ORDER BY last_in.scanned_at DESC, last_in.id DESC LIMIT 1)
        LEFT JOIN users receiver ON receiver.id=received.user_id
        LEFT JOIN movements sent_last ON sent_last.id=(SELECT last_out.id FROM movements last_out WHERE last_out.document_id=d.id AND last_out.id <= :movement_watermark AND last_out.status='OUT' AND last_out.scanned_at <= :as_of ORDER BY last_out.scanned_at DESC, last_out.id DESC LIMIT 1)
        LEFT JOIN users sender ON sender.id=sent_last.user_id
        WHERE {$activity}";
    $bindings = [':period_start' => $periodStart, ':as_of' => $asOf];
    $bindings[':movement_watermark'] = $filters['movement_watermark'] ?? PHP_INT_MAX;
    if (smartflow_report_has_corrections($pdo)) $bindings[':correction_watermark'] = $filters['correction_watermark'] ?? PHP_INT_MAX;
    if (!empty($filters['office_id'])) {
        $sql .= ' AND latest.office_id=:office_id';
        $bindings[':office_id'] = (int)$filters['office_id'];
    }
    if (($filters['q'] ?? '') !== '') {
        $sql .= " AND (d.id LIKE :search ESCAPE '!' OR d.title LIKE :search ESCAPE '!' OR d.type LIKE :search ESCAPE '!')";
        $bindings[':search'] = '%' . strtr($filters['q'], ['!' => '!!', '%' => '!%', '_' => '!_']) . '%';
    }
    if (($filters['classification'] ?? 'all') !== 'all') {
        $sql = 'SELECT classified.* FROM (' . $sql . ') classified WHERE classified.classification=:classification';
        $bindings[':classification'] = $filters['classification'];
    }
    return ['sql' => $sql, 'bindings' => $bindings];
}

/** All callers hold one repeatable-read transaction across these reads. */
function smartflow_report_register(PDO $pdo, string $periodStart, string $asOf, array $filters = [], ?int $page = 1, int $pageSize = 25): array
{
    $query = smartflow_report_register_query($pdo, $periodStart, $asOf, $filters);
    $count = $pdo->prepare('SELECT COUNT(*) FROM (' . $query['sql'] . ') register_count');
    $count->execute($query['bindings']);
    $total = (int)$count->fetchColumn();
    $sql = $query['sql'] . ' ORDER BY last_scanned_at DESC, document_id ASC';
    if ($page !== null) {
        $offset = ($page - 1) * $pageSize;
        $sql .= " LIMIT {$pageSize} OFFSET {$offset}";
    }
    $list = $pdo->prepare($sql);
    $list->execute($query['bindings']);
    $documents = array_map(static function (array $row): array {
        $row['current_office_id'] = (int)$row['current_office_id'];
        $row['destination_office_id'] = $row['destination_office_id'] === null ? null : (int)$row['destination_office_id'];
        $row['movement_count'] = (int)$row['movement_count'];
        $row['receipt_wait_hours'] = $row['receipt_wait_hours'] === null ? null : (float)$row['receipt_wait_hours'];
        $row['carried_forward'] = (bool)$row['carried_forward'];
        return $row;
    }, $list->fetchAll());
    return ['total' => $total, 'total_pages' => $page === null ? ($total ? 1 : 0) : (int)ceil($total / $pageSize), 'documents' => $documents];
}
