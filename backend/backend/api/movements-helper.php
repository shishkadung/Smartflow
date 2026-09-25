<?php
// Movement validation for scan-in (IN) / scan-out (OUT) at office handoffs.

declare(strict_types=1);

/**
 * @return array{id: int, office_id: int, role: string, office_name: string, office_code: string}
 */
function smartflow_require_authenticated_user(PDO $pdo, int $userId): array
{
    $stmt = $pdo->prepare('
        SELECT u.id, u.office_id, u.role, o.name AS office_name, o.code AS office_code
        FROM users u
        JOIN offices o ON o.id = u.office_id
        WHERE u.id = :id AND u.is_active = 1
        LIMIT 1
    ');
    $stmt->execute([':id' => $userId]);
    $user = $stmt->fetch();
    if (!$user) {
        json_response(['success' => false, 'message' => 'User not found or inactive'], 401);
    }

    return [
        'id'          => (int)$user['id'],
        'office_id'   => (int)$user['office_id'],
        'role'        => (string)$user['role'],
        'office_name' => (string)$user['office_name'],
        'office_code' => (string)$user['office_code'],
    ];
}

/**
 * @return array{status: string, office_id: int, office_name: string}|null
 */
function smartflow_last_movement(PDO $pdo, string $documentId): ?array
{
    $stmt = $pdo->prepare('
        SELECT m.status, m.office_id, o.name AS office_name, o.code AS office_code,
               m.destination_office_id,
               d.name AS destination_office_name,
               d.code AS destination_office_code
        FROM movements m
        JOIN offices o ON o.id = m.office_id
        LEFT JOIN offices d ON d.id = m.destination_office_id
        WHERE m.document_id = :id
        ORDER BY m.scanned_at DESC, m.id DESC
        LIMIT 1
    ');
    $stmt->execute([':id' => $documentId]);
    $row = $stmt->fetch();
    if (!$row) {
        return null;
    }

    return [
        'status'                   => strtoupper((string)$row['status']),
        'office_id'                => (int)$row['office_id'],
        'office_name'              => (string)$row['office_name'],
        'office_code'              => (string)$row['office_code'],
        'destination_office_id'    => $row['destination_office_id'] !== null
            ? (int)$row['destination_office_id'] : null,
        'destination_office_name'  => $row['destination_office_name'] !== null
            ? (string)$row['destination_office_name'] : null,
        'destination_office_code'  => $row['destination_office_code'] !== null
            ? (string)$row['destination_office_code'] : null,
    ];
}

/**
 * State matrix for IN/OUT — returns null when allowed, else rejection details.
 *
 * @return array{message: string, scan_error: string, http: int}|null
 */
function smartflow_check_movement(
    PDO $pdo,
    array $user,
    string $documentId,
    int $officeId,
    string $status
): ?array {
    $allowedRoles = ['staff', 'head', 'admin'];
    if (!in_array($user['role'], $allowedRoles, true)) {
        return [
            'message' => 'Your role cannot scan documents',
            'scan_error' => 'role_forbidden',
            'http' => 403,
        ];
    }

    if ($officeId !== $user['office_id']) {
        return [
            'message' => 'You can only record movements for your assigned office ('
                . $user['office_code'] . ')',
            'scan_error' => 'wrong_office',
            'http' => 403,
        ];
    }

    $last = smartflow_last_movement($pdo, $documentId);

    if ($status === 'IN') {
        if ($last === null) {
            return null;
        }
        if ($last['status'] === 'IN' && $last['office_id'] === $officeId) {
            return [
                'message' => 'Already marked IN at your office. Mark OUT when you forward this document.',
                'scan_error' => 'already_in_here',
                'http' => 409,
            ];
        }
        if ($last['status'] === 'OUT' && $last['office_id'] === $officeId) {
            return [
                'message' => 'Already marked OUT from your office. The receiving office must scan IN next.',
                'scan_error' => 'already_out_here',
                'http' => 409,
            ];
        }
        if ($last['status'] === 'IN' && $last['office_id'] !== $officeId) {
            return [
                'message' => 'Document is still IN at ' . $last['office_name']
                    . '. That office must mark OUT before you can receive it here.',
                'scan_error' => 'still_at_other_office',
                'http' => 409,
            ];
        }
        if ($last['status'] === 'OUT' && $last['office_id'] !== $officeId) {
            $destId = $last['destination_office_id'] ?? null;
            if ($destId !== null && $destId > 0 && $officeId !== $destId) {
                $destLabel = trim(
                    ($last['destination_office_name'] ?? '')
                    . ' (' . ($last['destination_office_code'] ?? '?') . ')'
                );
                return [
                    'message' => 'This folder was sent to ' . $destLabel
                        . '. Only that office can mark IN. Ask them to forward if it was misrouted.',
                    'scan_error' => 'wrong_receiver',
                    'http' => 409,
                ];
            }
            return null;
        }
        return null;
    }

    if ($status === 'OUT') {
        if ($last === null) {
            return [
                'message' => 'Mark IN first when the physical document arrives at your office.',
                'scan_error' => 'out_without_in',
                'http' => 409,
            ];
        }
        if ($last['status'] !== 'IN' || $last['office_id'] !== $officeId) {
            $where = $last['status'] === 'IN'
                ? 'IN at ' . $last['office_name']
                : 'OUT (last scan)';
            return [
                'message' => 'Cannot mark OUT — document is not currently IN at your office (last: '
                    . $where . ').',
                'scan_error' => 'not_in_at_office',
                'http' => 409,
            ];
        }
    }

    return null;
}

/**
 * Validates movement; writes audit + JSON error on failure when $auditContext provided.
 *
 * @param array{user_id: int, office_id: int, status: string}|null $auditContext
 */
function smartflow_validate_movement(
    PDO $pdo,
    array $user,
    string $documentId,
    int $officeId,
    string $status,
    ?array $auditContext = null
): void {
    $reject = smartflow_check_movement($pdo, $user, $documentId, $officeId, $status);
    if ($reject === null) {
        return;
    }

    if ($auditContext !== null) {
        smartflow_write_audit_log(
            $pdo,
            'movement.scan',
            $documentId,
            (int)$auditContext['user_id'],
            (int)$auditContext['office_id'],
            (string)$auditContext['status'],
            'rejected',
            $reject['message'],
            ['scan_error' => $reject['scan_error']]
        );
    }

    json_response([
        'success' => false,
        'message' => $reject['message'],
        'scan_error' => $reject['scan_error'],
    ], $reject['http']);
}

/**
 * Reject a scan with audit trail + JSON (movements-create and similar).
 */
function smartflow_reject_scan(
    PDO $pdo,
    string $eventType,
    ?string $documentId,
    int $userId,
    ?int $officeId,
    ?string $status,
    string $scanError,
    string $message,
    int $httpCode = 409,
    array $meta = []
): void {
    $meta['scan_error'] = $scanError;
    smartflow_write_audit_log(
        $pdo,
        $eventType,
        $documentId,
        $userId,
        $officeId,
        $status,
        'rejected',
        $message,
        $meta
    );

    $body = [
        'success' => false,
        'message' => $message,
        'scan_error' => $scanError,
    ];
    if (str_starts_with($scanError, 'qr_') || in_array($scanError, ['expired', 'tampered', 'invalid', 'mismatch'], true)) {
        $body['qr_error'] = $scanError;
    }

    json_response($body, $httpCode);
}

/**
 * Prevent accidental double-submit / rapid duplicate scans.
 */
function smartflow_has_recent_duplicate_movement(
    PDO $pdo,
    string $documentId,
    int $officeId,
    string $status,
    int $userId,
    int $withinSeconds = 8
): bool {
    $stmt = $pdo->prepare('
        SELECT id
        FROM movements
        WHERE document_id = :document_id
          AND office_id = :office_id
          AND status = :status
          AND user_id = :user_id
          AND scanned_at >= (NOW() - INTERVAL :secs SECOND)
        ORDER BY id DESC
        LIMIT 1
    ');
    $stmt->execute([
        ':document_id' => $documentId,
        ':office_id' => $officeId,
        ':status' => $status,
        ':user_id' => $userId,
        ':secs' => $withinSeconds,
    ]);

    return (bool)$stmt->fetch();
}

/**
 * Lightweight audit trail for scan actions and rejections.
 */
function smartflow_write_audit_log(
    PDO $pdo,
    string $eventType,
    ?string $documentId,
    ?int $userId,
    ?int $officeId,
    ?string $status,
    string $outcome,
    string $message,
    array $meta = []
): void {
    try {
        $stmt = $pdo->prepare('
            INSERT INTO audit_logs (
                event_type, document_id, user_id, office_id, status,
                outcome, message, meta_json, ip_address, user_agent
            ) VALUES (
                :event_type, :document_id, :user_id, :office_id, :status,
                :outcome, :message, :meta_json, :ip_address, :user_agent
            )
        ');
        $stmt->execute([
            ':event_type' => $eventType,
            ':document_id' => $documentId,
            ':user_id' => $userId,
            ':office_id' => $officeId,
            ':status' => $status,
            ':outcome' => $outcome,
            ':message' => $message,
            ':meta_json' => $meta ? json_encode($meta) : null,
            ':ip_address' => trim((string)($_SERVER['REMOTE_ADDR'] ?? '')) ?: null,
            ':user_agent' => trim((string)($_SERVER['HTTP_USER_AGENT'] ?? '')) ?: null,
        ]);
    } catch (Throwable $e) {
        // Never block scan flow when audit insert fails.
    }
}
