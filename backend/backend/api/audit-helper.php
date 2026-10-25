<?php
// Audit trail writes shared by scan endpoints and admin/account actions.

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
            ':message' => mb_substr($message, 0, 255),
            ':meta_json' => $meta ? json_encode($meta) : null,
            ':ip_address' => trim((string)($_SERVER['REMOTE_ADDR'] ?? '')) ?: null,
            ':user_agent' => mb_substr(trim((string)($_SERVER['HTTP_USER_AGENT'] ?? '')), 0, 255) ?: null,
        ]);
    } catch (Throwable $e) {
        // Never block the main action when audit insert fails.
    }
}

/**
 * Admin/account action (sign-up review, user status, thresholds, request decisions).
 * Event types: signup.*, user.*, threshold.*, request.* — kept out of the QR scan monitor.
 */
function smartflow_audit_action(
    PDO $pdo,
    string $eventType,
    int $actorId,
    string $message,
    array $meta = [],
    ?string $documentId = null
): void {
    $officeId = null;
    try {
        $stmt = $pdo->prepare('SELECT office_id FROM users WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $actorId]);
        $found = $stmt->fetchColumn();
        $officeId = $found !== false && $found !== null ? (int)$found : null;
    } catch (Throwable $e) {
        $officeId = null;
    }
    smartflow_write_audit_log($pdo, $eventType, $documentId, $actorId, $officeId, null, 'success', $message, $meta);
}
