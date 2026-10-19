<?php
// Movement validation for scan-in (IN) / scan-out (OUT) at office handoffs.

declare(strict_types=1);

require_once __DIR__ . '/audit-helper.php';

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
    if ($user['role'] !== 'staff') {
        return [
            'message' => 'Only office staff can record physical handoffs. Heads and administrators can look up and monitor folders.',
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
                'message' => 'Already marked OUT from your office. The receiving office confirms actual receipt. If the recorded destination is wrong, use Correct recorded destination before receipt.',
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
                        . '. Only that office can mark IN. If this destination was recorded incorrectly, ask the sending office to correct it before actual receipt.',
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
    if ($pdo->inTransaction()) $pdo->rollBack();

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
    if ($pdo->inTransaction()) $pdo->rollBack();
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
    // Only the latest movement counts: TRE → MAY → TRE can legitimately repeat an IN at the same office.
    $stmt = $pdo->prepare('
        SELECT office_id, status, user_id,
               scanned_at >= (NOW() - INTERVAL :secs SECOND) AS is_recent
        FROM movements
        WHERE document_id = :document_id
        ORDER BY scanned_at DESC, id DESC
        LIMIT 1
    ');
    $stmt->execute([
        ':document_id' => $documentId,
        ':secs' => $withinSeconds,
    ]);
    $last = $stmt->fetch();

    return $last !== false
        && (int)$last['office_id'] === $officeId
        && strtoupper((string)$last['status']) === $status
        && (int)$last['user_id'] === $userId
        && (int)$last['is_recent'] === 1;
}
