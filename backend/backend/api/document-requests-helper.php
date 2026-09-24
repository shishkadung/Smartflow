<?php

/**
 * Document request routing — validated with Municipal Accountant (Urbiztondo):
 *   budget → BUD, disbursement → ACC, payroll → ACC (not used in pilot UI)
 *   pull → target office handles the request
 *   ACC must not submit disbursement requests to itself
 */

function smartflow_ensure_document_requests(PDO $pdo): void
{
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS document_requests (
          id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
          request_code        VARCHAR(24)  NOT NULL,
          request_kind        ENUM('access','pull') NOT NULL DEFAULT 'access',
          document_category   VARCHAR(30)  NOT NULL,
          requested_by        INT UNSIGNED NOT NULL,
          requester_office_id INT UNSIGNED NOT NULL,
          requester_role      VARCHAR(20)  NOT NULL,
          handler_office_id   INT UNSIGNED NOT NULL,
          target_office_id    INT UNSIGNED NULL,
          purpose             TEXT         NOT NULL,
          required_by         DATE         NULL,
          related_document_id VARCHAR(50)  NULL,
          status              ENUM('pending','approved','rejected','fulfilled','cancelled')
                              NOT NULL DEFAULT 'pending',
          reviewed_by         INT UNSIGNED NULL,
          reviewed_at         DATETIME     NULL,
          review_notes        TEXT         NULL,
          fulfilled_at        DATETIME     NULL,
          created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          UNIQUE KEY uk_dr_code (request_code),
          KEY idx_dr_handler_status (handler_office_id, status),
          KEY idx_dr_requester (requested_by),
          KEY idx_dr_required_by (required_by),
          CONSTRAINT fk_dr_requester FOREIGN KEY (requested_by) REFERENCES users (id),
          CONSTRAINT fk_dr_requester_office FOREIGN KEY (requester_office_id) REFERENCES offices (id),
          CONSTRAINT fk_dr_handler_office FOREIGN KEY (handler_office_id) REFERENCES offices (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    smartflow_ensure_document_requests_required_by($pdo);
}

function smartflow_ensure_document_requests_required_by(PDO $pdo): void
{
    $stmt = $pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'document_requests'
          AND COLUMN_NAME = 'required_by'
    ");
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec('ALTER TABLE document_requests ADD COLUMN required_by DATE NULL AFTER purpose');
        $pdo->exec('ALTER TABLE document_requests ADD KEY idx_dr_required_by (required_by)');
    }
}

function smartflow_office_id_by_code(PDO $pdo, string $code): ?int
{
    $stmt = $pdo->prepare('SELECT id FROM offices WHERE code = :c LIMIT 1');
    $stmt->execute([':c' => strtoupper($code)]);
    $row = $stmt->fetch();
    return $row ? (int)$row['id'] : null;
}

/** Owner office code per financial document category. */
function smartflow_category_owner_code(string $category): ?string
{
    return match (strtolower($category)) {
        'budget'        => 'BUD',
        'payroll'       => 'ACC',
        'disbursement'  => 'ACC',
        default         => null,
    };
}

function smartflow_allowed_categories_for_role(string $role): array
{
    return match ($role) {
        'admin' => ['budget', 'payroll', 'disbursement', 'general'],
        'head'  => ['budget', 'payroll', 'disbursement', 'general'],
        'staff' => ['budget', 'payroll', 'disbursement', 'general'],
        default => [],
    };
}

function smartflow_can_use_request_kind(string $role, string $kind): bool
{
    if (!in_array($kind, ['access', 'pull'], true)) {
        return false;
    }
    return in_array($role, ['staff', 'head', 'admin'], true);
}

/**
 * @return array{handler_office_id:int, document_category:string, target_office_id:?int}
 */
function smartflow_resolve_document_request(PDO $pdo, array $user, string $kind, string $category, ?int $targetOfficeId): array
{
    $category = strtolower(trim($category));
    if ($category === '') {
        $category = 'general';
    }

    if ($kind === 'pull') {
        if ($targetOfficeId === null || $targetOfficeId <= 0) {
            json_response(['success' => false, 'message' => 'target_office_id is required for pull requests'], 400);
        }
        if ($targetOfficeId === (int)$user['office_id']) {
            json_response(['success' => false, 'message' => 'Cannot pull from your own office — process locally'], 400);
        }
        return [
            'handler_office_id' => $targetOfficeId,
            'document_category' => $category,
            'target_office_id'  => $targetOfficeId,
        ];
    }

    $ownerCode = smartflow_category_owner_code($category);
    if ($ownerCode === null && $category !== 'general') {
        json_response([
            'success' => false,
            'message' => 'document_category must be budget, payroll, or disbursement',
        ], 400);
    }

    if ($category === 'general') {
        json_response([
            'success' => false,
            'message' => 'For general requests use request_kind pull with target_office_id',
        ], 400);
    }

    $handlerId = smartflow_office_id_by_code($pdo, $ownerCode);
    if ($handlerId === null) {
        json_response(['success' => false, 'message' => 'Owner office not configured'], 500);
    }

    if ($handlerId === (int)$user['office_id']) {
        json_response([
            'success' => false,
            'message' => 'Your office owns this document type — coordinate internally instead of a system request',
        ], 400);
    }

    $accId = smartflow_office_id_by_code($pdo, 'ACC');
    if (
        $category === 'disbursement'
        && $accId !== null
        && (int)$user['office_id'] === $accId
    ) {
        json_response([
            'success' => false,
            'message' => 'Accounting processes incoming DVs — register or scan when the folder is at your desk, or use a pull request to another office',
        ], 400);
    }

    return [
        'handler_office_id' => $handlerId,
        'document_category' => $category,
        'target_office_id'  => null,
    ];
}

function smartflow_generate_request_code(PDO $pdo): string
{
    $year = date('Y');
    $prefix = "REQ-$year-%";
    $stmt = $pdo->prepare('
        SELECT MAX(CAST(SUBSTRING_INDEX(request_code, "-", -1) AS UNSIGNED)) AS max_seq
        FROM document_requests
        WHERE request_code LIKE :p
    ');
    $stmt->execute([':p' => $prefix]);
    $maxSeq = (int)($stmt->fetch()['max_seq'] ?? 0);
    return sprintf('REQ-%s-%04d', $year, $maxSeq + 1);
}

function smartflow_format_document_request_row(array $row): array
{
    return [
        'id'                   => (int)$row['id'],
        'request_code'         => $row['request_code'],
        'request_kind'         => $row['request_kind'],
        'document_category'    => $row['document_category'],
        'purpose'              => $row['purpose'],
        'required_by'          => $row['required_by'] ?? null,
        'required_by_display'  => !empty($row['required_by'])
            ? date('M j, Y', strtotime((string)$row['required_by']))
            : null,
        'is_overdue'           => !empty($row['required_by'])
            && $row['status'] === 'pending'
            && strtotime((string)$row['required_by']) < strtotime('today'),
        'status'               => $row['status'],
        'related_document_id'  => $row['related_document_id'],
        'review_notes'         => $row['review_notes'],
        'created_at'           => $row['created_at'],
        'reviewed_at'          => $row['reviewed_at'],
        'fulfilled_at'         => $row['fulfilled_at'],
        'requester' => [
            'user_id'      => (int)$row['requested_by'],
            'username'     => $row['requester_username'],
            'name'         => $row['requester_name'],
            'role'         => $row['requester_role'],
            'office_id'    => (int)$row['requester_office_id'],
            'office_name'  => $row['requester_office_name'],
            'office_code'  => $row['requester_office_code'],
        ],
        'handler_office' => [
            'office_id'   => (int)$row['handler_office_id'],
            'office_name' => $row['handler_office_name'],
            'office_code' => $row['handler_office_code'],
        ],
        'target_office' => $row['target_office_id'] ? [
            'office_id'   => (int)$row['target_office_id'],
            'office_name' => $row['target_office_name'] ?? '',
            'office_code' => $row['target_office_code'] ?? '',
        ] : null,
    ];
}

const SMARTFLOW_DR_SELECT = "
    SELECT r.*,
           u.username AS requester_username,
           u.name AS requester_name,
           ro.name AS requester_office_name,
           ro.code AS requester_office_code,
           ho.name AS handler_office_name,
           ho.code AS handler_office_code,
           toff.name AS target_office_name,
           toff.code AS target_office_code
    FROM document_requests r
    JOIN users u ON u.id = r.requested_by
    JOIN offices ro ON ro.id = r.requester_office_id
    JOIN offices ho ON ho.id = r.handler_office_id
    LEFT JOIN offices toff ON toff.id = r.target_office_id
";
