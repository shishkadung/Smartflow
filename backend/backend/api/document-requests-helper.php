<?php

require_once __DIR__ . '/users-helper.php';

/** The same ticket read scope serves Requests and folder-linked ticket evidence. */
function smartflow_document_request_read_scope(array $user, string $view): array
{
    if ($view === 'all' || ($view === 'related' && $user['role'] === 'admin')) {
        return [$user['role'] === 'admin' ? '1=1' : '0=1', []];
    }
    if ($view === 'outbox') return ['r.requested_by = :request_scope_user', [':request_scope_user' => (int)$user['id']]];
    $scope = 'r.handler_office_id = :request_scope_office';
    $params = [':request_scope_office' => (int)$user['office_id']];
    if (strtoupper((string)$user['office_code']) === 'TRE') {
        $scope = "({$scope} OR (r.document_category = 'disbursement' AND (r.status = 'approved' OR (r.status = 'fulfilled' AND r.fulfilled_by IS NOT NULL AND EXISTS(SELECT 1 FROM offices fo WHERE fo.id = r.fulfilled_office_id AND fo.code = 'TRE')))))";
    }
    if ($view === 'related') {
        $scope = "({$scope} OR r.requested_by = :request_scope_user)";
        $params[':request_scope_user'] = (int)$user['id'];
    }
    return [$scope, $params];
}

/**
 * Document request routing — validated with Municipal Accountant (Urbiztondo):
 *   budget → BUD, disbursement → ACC
 *   payroll requests are not accepted in Phase 1 (payslip access only; ACC prepares payroll)
 *   pull → general request handled by the selected target office
 *   ACC must not submit disbursement requests to itself
 */

function smartflow_ensure_document_requests(PDO $pdo): void
{
    smartflow_ensure_users_avatar_column($pdo);
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
          reviewed_office_id  INT UNSIGNED NULL,
          reviewed_at         DATETIME     NULL,
          review_notes        TEXT         NULL,
          fulfilled_at        DATETIME     NULL,
          fulfilled_by        INT UNSIGNED NULL,
          fulfilled_office_id INT UNSIGNED NULL,
          fulfilled_notes     TEXT         NULL,
          cancelled_at        DATETIME     NULL,
          cancelled_by        INT UNSIGNED NULL,
          cancelled_office_id INT UNSIGNED NULL,
          cancelled_notes     TEXT         NULL,
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
    smartflow_ensure_document_requests_fulfilled_by($pdo);
    smartflow_ensure_document_request_evidence($pdo);
}

/** Add evidence fields before transactions; historical mixed notes/unknown actors stay untouched. */
function smartflow_ensure_document_request_evidence(PDO $pdo): void
{
    $columns = $pdo->query("SELECT COLUMN_NAME FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='document_requests'")->fetchAll(PDO::FETCH_COLUMN);
    foreach (['reviewed_office_id' => 'INT UNSIGNED', 'fulfilled_notes' => 'TEXT',
        'cancelled_at' => 'DATETIME', 'cancelled_by' => 'INT UNSIGNED',
        'cancelled_office_id' => 'INT UNSIGNED', 'cancelled_notes' => 'TEXT'] as $column => $type) {
        if (in_array($column, $columns, true)) continue;
        try { $pdo->exec("ALTER TABLE document_requests ADD COLUMN $column $type NULL"); }
        catch (PDOException $e) { if ((int)($e->errorInfo[1] ?? 0) !== 1060) throw $e; }
    }
}

/** Run before business transactions: MySQL schema changes can implicitly commit. */
function smartflow_ensure_document_requests_fulfilled_by(PDO $pdo): void
{
    $stmt = $pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'document_requests'
          AND COLUMN_NAME = 'fulfilled_by'
    ");
    if ((int)$stmt->fetchColumn() === 0) {
        // Legacy completed records retain NULL; the Accounting reviewer is not the payment closer.
        try {
            $pdo->exec('ALTER TABLE document_requests ADD COLUMN fulfilled_by INT UNSIGNED NULL AFTER fulfilled_at');
        } catch (PDOException $e) {
            // Another first request may have installed the same additive field concurrently.
            if ((int)($e->errorInfo[1] ?? 0) !== 1060) throw $e;
        }
    }
    $officeStmt = $pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'document_requests'
          AND COLUMN_NAME = 'fulfilled_office_id'
    ");
    if ((int)$officeStmt->fetchColumn() === 0) {
        try {
            $pdo->exec('ALTER TABLE document_requests ADD COLUMN fulfilled_office_id INT UNSIGNED NULL AFTER fulfilled_by');
        } catch (PDOException $e) {
            if ((int)($e->errorInfo[1] ?? 0) !== 1060) throw $e;
        }
    }
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
        'admin' => ['budget', 'disbursement', 'general', 'other'],
        'head'  => ['budget', 'disbursement', 'general', 'other'],
        'staff' => ['budget', 'disbursement', 'general', 'other'],
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
        $target = $pdo->prepare('SELECT id FROM offices WHERE id = :id LIMIT 1');
        $target->execute([':id' => $targetOfficeId]);
        if (!$target->fetchColumn()) {
            json_response(['success' => false, 'message' => 'Target office not found'], 400);
        }
        return [
            'handler_office_id' => $targetOfficeId,
            // Older native clients can send the hidden, previously selected access category.
            'document_category' => 'general',
            'target_office_id'  => $targetOfficeId,
        ];
    }

    if ($category === 'other') {
        if ($targetOfficeId === null || $targetOfficeId <= 0) {
            json_response([
                'success' => false,
                'message' => 'Choose the office that should receive this request',
            ], 400);
        }
        if ($targetOfficeId === (int)$user['office_id']) {
            json_response([
                'success' => false,
                'message' => 'Cannot send Others to your own office — process locally',
            ], 400);
        }
        return [
            'handler_office_id' => $targetOfficeId,
            'document_category' => 'other',
            'target_office_id'  => $targetOfficeId,
        ];
    }

    $ownerCode = smartflow_category_owner_code($category);
    if ($ownerCode === null && $category !== 'general') {
        json_response([
            'success' => false,
            'message' => 'document_category must be budget, disbursement, or other',
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

/** Calendar-date deadlines stay open through the end of the requested day. */
function smartflow_request_is_overdue(?string $requiredBy, string $status): bool
{
    return !empty($requiredBy)
        && in_array($status, ['pending', 'approved'], true)
        && $requiredBy < date('Y-m-d');
}

/** Opaque decision/link version returned to clients for optimistic conflict protection. */
function smartflow_request_revision(array $request): string
{
    // No timestamp-only revision: a link and decision can both change within one second.
    $fields = ['id', 'status', 'related_document_id', 'reviewed_by', 'reviewed_office_id', 'reviewed_at', 'review_notes',
        'fulfilled_at', 'fulfilled_by', 'fulfilled_office_id', 'fulfilled_notes',
        'cancelled_at', 'cancelled_by', 'cancelled_office_id', 'cancelled_notes'];
    $values = [];
    foreach ($fields as $field) $values[$field] = isset($request[$field]) ? (string)$request[$field] : null;
    return hash('sha256', json_encode($values, JSON_THROW_ON_ERROR));
}

function smartflow_assert_request_link_authority(array $user, array $request): void
{
    if (!in_array($user['role'], ['staff', 'head', 'admin'], true)
        || ($user['role'] !== 'admin' && (int)$user['office_id'] !== (int)$request['handler_office_id'])) {
        throw new InvalidArgumentException('Only the handler office or admin can link a folder to this request', 403);
    }
    if ($request['status'] !== 'approved') {
        throw new InvalidArgumentException('Only approved requests can be linked to a physical folder', 409);
    }
}

/** Shared evidence checks for both linking and closing; never records a physical handoff. */
function smartflow_validate_request_document(PDO $pdo, array $request, string $documentId): void
{
    if (!empty($request['related_document_id']) && $request['related_document_id'] !== $documentId) {
        throw new InvalidArgumentException('This request already has a linked folder; open that folder instead', 409);
    }

    $documentQuery = $pdo->prepare('
        SELECT d.id, d.type, d.origin_office_id,
               EXISTS(SELECT 1 FROM movements m WHERE m.document_id = d.id AND m.office_id = :handler) AS handler_history
        FROM documents d WHERE d.id = :id LIMIT 1
    ');
    $documentQuery->execute([':id' => $documentId, ':handler' => $request['handler_office_id']]);
    $document = $documentQuery->fetch();
    if (!$document) throw new InvalidArgumentException('Related folder not found', 404);
    $category = strtolower((string)$request['document_category']);
    $typeMatches = match ($category) {
        'budget' => $document['type'] === 'Approved Budget',
        'disbursement' => $document['type'] === 'Disbursement Voucher',
        'other' => str_starts_with($document['type'], 'Others:'),
        'general' => true,
        default => false,
    };
    if (!$typeMatches) throw new InvalidArgumentException('Choose a physical folder that matches the request category', 400);
    if ((int)$document['origin_office_id'] !== (int)$request['handler_office_id'] && !(bool)$document['handler_history']) {
        throw new InvalidArgumentException('The handler office must have registered or handled this folder before linking it', 403);
    }
}

/** Link evidence without changing approval. Registration and the update endpoint own the transaction. */
function smartflow_link_request_document(PDO $pdo, array $user, int $requestId, string $documentId): array
{
    $requestQuery = $pdo->prepare('SELECT * FROM document_requests WHERE id = :id LIMIT 1 FOR UPDATE');
    $requestQuery->execute([':id' => $requestId]);
    $request = $requestQuery->fetch();
    if (!$request) throw new InvalidArgumentException('Request not found', 404);
    smartflow_assert_request_link_authority($user, $request);
    smartflow_validate_request_document($pdo, $request, $documentId);
    $pdo->prepare('UPDATE document_requests SET related_document_id = :doc WHERE id = :id')
        ->execute([':doc' => $documentId, ':id' => $requestId]);
    return $request;
}

function smartflow_format_document_request_row(array $row): array
{
    $legacyNotes = ($row['status'] === 'fulfilled' && ($row['fulfilled_notes'] ?? null) === null)
        || ($row['status'] === 'cancelled' && ($row['cancelled_notes'] ?? null) === null);
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
        'is_overdue'           => smartflow_request_is_overdue($row['required_by'] ?? null, (string)$row['status']),
        'status'               => $row['status'],
        'revision'             => smartflow_request_revision($row),
        'related_document_id'  => $row['related_document_id'],
        'review_notes'         => $row['review_notes'],
        'review_notes_kind'    => $legacyNotes ? 'legacy' : 'review',
        'created_at'           => $row['created_at'],
        'reviewed_at'          => $row['reviewed_at'],
        'reviewed_by'          => isset($row['reviewed_by']) ? (int)$row['reviewed_by'] : null,
        'reviewed_office_id'   => isset($row['reviewed_office_id']) ? (int)$row['reviewed_office_id'] : null,
        'fulfilled_at'         => $row['fulfilled_at'],
        'fulfilled_by'         => isset($row['fulfilled_by']) ? (int)$row['fulfilled_by'] : null,
        'fulfilled_office_id'  => isset($row['fulfilled_office_id']) ? (int)$row['fulfilled_office_id'] : null,
        'fulfilled_notes'      => $row['fulfilled_notes'] ?? null,
        'cancelled_at'         => $row['cancelled_at'] ?? null,
        'cancelled_by'         => isset($row['cancelled_by']) ? (int)$row['cancelled_by'] : null,
        'cancelled_office_id'  => isset($row['cancelled_office_id']) ? (int)$row['cancelled_office_id'] : null,
        'cancelled_notes'      => $row['cancelled_notes'] ?? null,
        'reviewer'            => smartflow_request_actor($row, 'reviewer', 'reviewed_by', 'reviewed_office_id'),
        'fulfiller'           => smartflow_request_actor($row, 'fulfiller', 'fulfilled_by', 'fulfilled_office_id'),
        'canceller'           => smartflow_request_actor($row, 'canceller', 'cancelled_by', 'cancelled_office_id'),
        'requester' => [
            'user_id'      => (int)$row['requested_by'],
            'username'     => $row['requester_username'],
            'name'         => $row['requester_name'],
            'avatar_url'   => smartflow_avatar_url_for(
                (int)$row['requested_by'],
                $row['requester_avatar_path'] ?? null
            ),
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

/** User identity may be current; office attribution comes only from the saved event snapshot. */
function smartflow_request_actor(array $row, string $prefix, string $userField, string $officeField): ?array
{
    if (!isset($row[$userField])) return null;
    $officeId = isset($row[$officeField]) ? (int)$row[$officeField] : null;
    return ['user_id' => (int)$row[$userField], 'name' => $row[$prefix . '_name'] ?? null,
        'username' => $row[$prefix . '_username'] ?? null, 'office_id' => $officeId,
        'office_name' => $officeId === null ? null : ($row[$prefix . '_office_name'] ?? null),
        'office_code' => $officeId === null ? null : ($row[$prefix . '_office_code'] ?? null)];
}

const SMARTFLOW_DR_SELECT = "
    SELECT r.*,
           u.username AS requester_username,
           u.name AS requester_name,
           u.avatar_path AS requester_avatar_path,
           ro.name AS requester_office_name,
           ro.code AS requester_office_code,
           ho.name AS handler_office_name,
           ho.code AS handler_office_code,
           toff.name AS target_office_name,
           toff.code AS target_office_code,
           reviewer.name AS reviewer_name, reviewer.username AS reviewer_username,
           reviewOffice.name AS reviewer_office_name, reviewOffice.code AS reviewer_office_code,
           fulfiller.name AS fulfiller_name, fulfiller.username AS fulfiller_username,
           fulfillOffice.name AS fulfiller_office_name, fulfillOffice.code AS fulfiller_office_code,
           canceller.name AS canceller_name, canceller.username AS canceller_username,
           cancelOffice.name AS canceller_office_name, cancelOffice.code AS canceller_office_code
    FROM document_requests r
    JOIN users u ON u.id = r.requested_by
    JOIN offices ro ON ro.id = r.requester_office_id
    JOIN offices ho ON ho.id = r.handler_office_id
    LEFT JOIN offices toff ON toff.id = r.target_office_id
    LEFT JOIN users reviewer ON reviewer.id = r.reviewed_by
    LEFT JOIN offices reviewOffice ON reviewOffice.id = r.reviewed_office_id
    LEFT JOIN users fulfiller ON fulfiller.id = r.fulfilled_by
    LEFT JOIN offices fulfillOffice ON fulfillOffice.id = r.fulfilled_office_id
    LEFT JOIN users canceller ON canceller.id = r.cancelled_by
    LEFT JOIN offices cancelOffice ON cancelOffice.id = r.cancelled_office_id
";
