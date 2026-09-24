<?php
// Processing thresholds + alert due-date helpers (runtime schema).

declare(strict_types=1);

function smartflow_ensure_processing_thresholds(PDO $pdo): void
{
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS processing_thresholds (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            office_id INT UNSIGNED NOT NULL,
            document_type VARCHAR(50) NOT NULL,
            max_hours INT UNSIGNED NOT NULL DEFAULT 48,
            out_unconfirmed_hours INT UNSIGNED NOT NULL DEFAULT 24,
            is_active TINYINT(1) NOT NULL DEFAULT 1,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uk_processing_thresholds (office_id, document_type),
            CONSTRAINT fk_pt_office FOREIGN KEY (office_id) REFERENCES offices (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    $defaults = [
        'ENG' => [['Disbursement Voucher', 48, 24]],
        'HR'  => [['Payroll Record', 24, 12]],
        'BUD' => [['Approved Budget', 72, 24]],
        'ACC' => [
            ['Disbursement Voucher', 48, 24],
            ['Approved Budget', 72, 24],
        ],
        'TRE' => [['Disbursement Voucher', 48, 24]],
        'MAY' => [['Disbursement Voucher', 48, 24]],
    ];

    $stmtOffice = $pdo->query('SELECT id, code FROM offices');
    $insert = $pdo->prepare('
        INSERT IGNORE INTO processing_thresholds (office_id, document_type, max_hours, out_unconfirmed_hours)
        VALUES (:oid, :type, :maxh, :outh)
    ');
    foreach ($stmtOffice->fetchAll() as $office) {
        $code = $office['code'];
        foreach ($defaults[$code] ?? [['Disbursement Voucher', 48, 24]] as $row) {
            $insert->execute([
                ':oid'  => (int)$office['id'],
                ':type' => $row[0],
                ':maxh' => $row[1],
                ':outh' => $row[2],
            ]);
        }
    }
}

function smartflow_threshold_defaults(): array
{
    return ['max_hours' => 48, 'out_unconfirmed_hours' => 24];
}

function smartflow_get_threshold(PDO $pdo, int $officeId, string $documentType): array
{
    smartflow_ensure_processing_thresholds($pdo);

    $stmt = $pdo->prepare('
        SELECT max_hours, out_unconfirmed_hours
        FROM processing_thresholds
        WHERE office_id = :oid AND document_type = :type AND is_active = 1
        LIMIT 1
    ');
    $stmt->execute([':oid' => $officeId, ':type' => $documentType]);
    $row = $stmt->fetch();
    if (!$row) {
        return smartflow_threshold_defaults();
    }

    return [
        'max_hours'             => (int)$row['max_hours'],
        'out_unconfirmed_hours' => (int)$row['out_unconfirmed_hours'],
    ];
}

function smartflow_due_at(string $scannedAt, int $hours): string
{
    $ts = strtotime($scannedAt);
    if ($ts === false) {
        return $scannedAt;
    }
    return date('Y-m-d H:i:s', $ts + ($hours * 3600));
}

function smartflow_due_at_display(string $dueAt): string
{
    $ts = strtotime($dueAt);
    if ($ts === false) {
        return $dueAt;
    }
    return date('M j, Y g:i A', $ts);
}

function smartflow_hours_until_due(string $dueAt): int
{
    $ts = strtotime($dueAt);
    if ($ts === false) {
        return 0;
    }
    return (int)floor(($ts - time()) / 3600);
}

function smartflow_ensure_documents_due_column(PDO $pdo): void
{
    $stmt = $pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'documents'
          AND COLUMN_NAME = 'due_at'
    ");
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec('ALTER TABLE documents ADD COLUMN due_at DATETIME NULL DEFAULT NULL AFTER description');
    }
}

/**
 * @return string|null MySQL datetime
 */
function smartflow_parse_due_at_input(?string $raw): ?string
{
    if ($raw === null) {
        return null;
    }
    $raw = trim($raw);
    if ($raw === '' || strtolower($raw) === 'null') {
        return null;
    }
    $ts = strtotime($raw);
    if ($ts === false) {
        return null;
    }
    return date('Y-m-d H:i:s', $ts);
}

/**
 * @return array{due_at: string, due_at_display: string, hours_until_due: int, max_hours: int, threshold_rule: string, is_overdue: bool, is_manual_due: bool}
 */
function smartflow_manual_due_result(string $manualDueAt): array
{
    $hoursUntil = smartflow_hours_until_due($manualDueAt);

    return [
        'due_at'           => $manualDueAt,
        'due_at_display'   => smartflow_due_at_display($manualDueAt),
        'hours_until_due'  => $hoursUntil,
        'max_hours'        => 0,
        'threshold_rule'   => 'Due date set on this document',
        'is_overdue'       => $hoursUntil < 0,
        'is_manual_due'    => true,
    ];
}

/**
 * Per-document due: manual due_at on the document wins; else computed from scan + office/type rules.
 *
 * @return array{due_at: string, due_at_display: string, hours_until_due: int, max_hours: int, threshold_rule: string, is_overdue: bool, is_manual_due: bool}
 */
function smartflow_document_due(
    PDO $pdo,
    string $documentType,
    ?string $lastStatus,
    ?int $lastOfficeId,
    ?string $lastScannedAt,
    ?string $manualDueAt = null
): array {
    smartflow_ensure_documents_due_column($pdo);

    $manualDueAt = $manualDueAt !== null ? trim($manualDueAt) : '';
    if ($manualDueAt !== '') {
        return smartflow_manual_due_result($manualDueAt);
    }

    if ($lastStatus === null || $lastOfficeId === null || $lastScannedAt === null || $lastScannedAt === '') {
        return [
            'due_at'           => '',
            'due_at_display'   => '—',
            'hours_until_due'  => 0,
            'max_hours'        => 0,
            'threshold_rule'   => 'No movement yet — set a due date on the document or scan to start',
            'is_overdue'       => false,
            'is_manual_due'    => false,
        ];
    }

    $th = smartflow_get_threshold($pdo, $lastOfficeId, $documentType);
    if ($lastStatus === 'OUT') {
        $limit = $th['out_unconfirmed_hours'];
        $rule = "Due after OUT · {$limit}h to receive scan";
    } else {
        $limit = $th['max_hours'];
        $rule = "Due while IN · {$limit}h max at office";
    }

    $dueAt = smartflow_due_at($lastScannedAt, $limit);
    $hoursUntil = smartflow_hours_until_due($dueAt);

    return [
        'due_at'           => $dueAt,
        'due_at_display'   => smartflow_due_at_display($dueAt),
        'hours_until_due'  => $hoursUntil,
        'max_hours'        => $limit,
        'threshold_rule'   => $rule,
        'is_overdue'       => $hoursUntil < 0,
        'is_manual_due'    => false,
    ];
}

/**
 * @return array<int, array<string, mixed>>
 */
function smartflow_list_thresholds_by_office(PDO $pdo): array
{
    smartflow_ensure_processing_thresholds($pdo);

    $stmt = $pdo->query('
        SELECT o.id AS office_id, o.name AS office_name, o.code AS office_code,
               t.id AS threshold_id, t.document_type, t.max_hours, t.out_unconfirmed_hours
        FROM offices o
        LEFT JOIN processing_thresholds t ON t.office_id = o.id AND t.is_active = 1
        ORDER BY o.name ASC, t.document_type ASC
    ');

    $grouped = [];
    foreach ($stmt->fetchAll() as $row) {
        $oid = (int)$row['office_id'];
        if (!isset($grouped[$oid])) {
            $grouped[$oid] = [
                'office_id'   => $oid,
                'office_name' => $row['office_name'],
                'office_code' => $row['office_code'],
                'thresholds'  => [],
            ];
        }
        if ($row['threshold_id'] !== null) {
            $grouped[$oid]['thresholds'][] = [
                'threshold_id'          => (int)$row['threshold_id'],
                'document_type'         => $row['document_type'],
                'max_hours'             => (int)$row['max_hours'],
                'out_unconfirmed_hours' => (int)$row['out_unconfirmed_hours'],
            ];
        }
    }

    return array_values($grouped);
}

function smartflow_require_admin(PDO $pdo, int $userId): void
{
    $stmt = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $userId]);
    $role = $stmt->fetchColumn();
    if ($role !== 'admin') {
        json_response(['success' => false, 'message' => 'Admin access required'], 403);
    }
}

/**
 * Build alert rows from movement snapshot + configured thresholds.
 *
 * @param array<string, mixed> $r
 * @return array<string, mixed>|null
 */
function smartflow_build_alert_from_row(PDO $pdo, array $r, ?int $viewingOfficeId = null): ?array
{
    $hours = (int)$r['hours_pending'];
    $docType = (string)$r['document_type'];
    $lastStatus = (string)$r['last_status'];
    $lastOfficeId = (int)$r['last_office_id'];
    $lastScanned = (string)$r['last_scanned_at'];
    $viewingOfficeId = $viewingOfficeId ?? $lastOfficeId;

    $manualDue = isset($r['document_due_at']) ? trim((string)$r['document_due_at']) : '';
    if ($manualDue !== '') {
        $hoursUntil = smartflow_hours_until_due($manualDue);
        if ($hoursUntil > 24) {
            return null;
        }
        $overdue = $hoursUntil < 0;
        $where = $r['last_office_name'] ?? 'office';
        return [
            'document_id'      => $r['document_id'],
            'title'            => $r['document_id'] . ($overdue ? ' – Past due date' : ' – Due soon'),
            'document_title'   => $r['title'],
            'detail'           => $overdue
                ? 'Document due date passed (' . smartflow_due_at_display($manualDue) . ')'
                : 'Due ' . smartflow_due_at_display($manualDue) . " · {$hoursUntil}h left",
            'kind'             => $overdue ? 'delayed' : 'due_soon',
            'last_status'      => $lastStatus,
            'last_office_name' => $where,
            'last_scanned_at'  => $lastScanned,
            'hours_pending'    => $hours,
            'days_pending'     => intdiv(max(0, -$hoursUntil), 24),
            'max_hours'        => 0,
            'due_at'           => $manualDue,
            'hours_until_due'  => $hoursUntil,
            'threshold_rule'   => 'Due date set on document',
            'is_manual_due'    => true,
        ];
    }

    $isOutgoing = ($lastStatus === 'OUT' && $lastOfficeId === $viewingOfficeId);
    // Office views: only flag folders currently IN at the viewing office.
    // "Stuck elsewhere" is municipal-admin scope (accountant-alerts.php).
    $isStuckElsewhere = false;
    $isStuckAtViewer = ($lastStatus === 'IN' && $lastOfficeId === $viewingOfficeId);
    $isMunicipalIn = ($lastStatus === 'IN' && $viewingOfficeId === 0);
    $isMunicipalOut = ($lastStatus === 'OUT' && $viewingOfficeId === 0);

    if ($isOutgoing) {
        $th = smartflow_get_threshold($pdo, $viewingOfficeId, $docType);
        $limit = $th['out_unconfirmed_hours'];
        if ($hours < $limit) {
            return null;
        }
        $dueAt = smartflow_due_at($lastScanned, $limit);
        return [
            'document_id'      => $r['document_id'],
            'title'            => $r['document_id'] . ' – Awaiting confirmation',
            'document_title'   => $r['title'],
            'detail'           => "Marked OUT · no receive scan after {$limit}h (due " . smartflow_due_at_display($dueAt) . ')',
            'kind'             => 'unconfirmed',
            'last_status'      => $lastStatus,
            'last_office_name' => $r['last_office_name'],
            'last_scanned_at'  => $lastScanned,
            'hours_pending'    => $hours,
            'days_pending'     => intdiv($hours, 24),
            'max_hours'        => $limit,
            'due_at'           => $dueAt,
            'hours_until_due'  => smartflow_hours_until_due($dueAt),
            'threshold_rule'   => "OUT unconfirmed · {$limit}h",
        ];
    }

    $checkOfficeId = $lastOfficeId;
    if ($isStuckElsewhere || $isStuckAtViewer || $isMunicipalIn) {
        $th = smartflow_get_threshold($pdo, $checkOfficeId, $docType);
        $limit = $th['max_hours'];
        if ($hours < $limit) {
            return null;
        }
        $dueAt = smartflow_due_at($lastScanned, $limit);
        $where = $r['last_office_name'];
        return [
            'document_id'      => $r['document_id'],
            'title'            => $r['document_id'] . ' – Overdue at ' . $where,
            'document_title'   => $r['title'],
            'detail'           => "IN at {$where} · exceeded {$limit}h (due " . smartflow_due_at_display($dueAt) . ')',
            'kind'             => 'delayed',
            'last_status'      => $lastStatus,
            'last_office_name' => $r['last_office_name'],
            'last_scanned_at'  => $lastScanned,
            'hours_pending'    => $hours,
            'days_pending'     => intdiv($hours, 24),
            'max_hours'        => $limit,
            'due_at'           => $dueAt,
            'hours_until_due'  => smartflow_hours_until_due($dueAt),
            'threshold_rule'   => "Max IN dwell · {$limit}h",
        ];
    }

    if ($isMunicipalOut) {
        $th = smartflow_get_threshold($pdo, $lastOfficeId, $docType);
        $limit = $th['out_unconfirmed_hours'];
        if ($hours < $limit) {
            return null;
        }
        $dueAt = smartflow_due_at($lastScanned, $limit);
        return [
            'document_id'      => $r['document_id'],
            'title'            => $r['document_id'] . ' · Unconfirmed OUT',
            'document_title'   => $r['title'],
            'detail'           => 'OUT from ' . $r['last_office_name'] . " · {$hours}h · due " . smartflow_due_at_display($dueAt),
            'kind'             => 'unconfirmed',
            'last_status'      => $lastStatus,
            'last_office_name' => $r['last_office_name'],
            'last_scanned_at'  => $lastScanned,
            'hours_pending'    => $hours,
            'days_pending'     => intdiv($hours, 24),
            'max_hours'        => $limit,
            'due_at'           => $dueAt,
            'hours_until_due'  => smartflow_hours_until_due($dueAt),
            'threshold_rule'   => "OUT unconfirmed · {$limit}h",
        ];
    }

    return null;
}
