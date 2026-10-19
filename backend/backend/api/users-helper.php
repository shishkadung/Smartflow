<?php
// User table helpers (active flag for soft deactivate).

declare(strict_types=1);

/** Recheck privileged writers after resource waits and retain authority until commit. */
function smartflow_require_locked_admin(PDO $pdo, int $userId): array
{
    $user = $pdo->prepare('SELECT id, role, username, is_active FROM users WHERE id = ? FOR UPDATE');
    $user->execute([$userId]);
    $row = $user->fetch();
    $session = $pdo->prepare('SELECT user_id FROM auth_tokens
        WHERE token_hash = ? AND is_revoked = 0 AND expires_at > NOW() FOR UPDATE');
    $session->execute([hash('sha256', get_bearer_token() ?? '')]);
    if (!$row || !(int)$row['is_active'] || (int)$session->fetchColumn() !== $userId) {
        $pdo->rollBack();
        json_response(['success' => false, 'message' => 'Your session has ended. Please sign in again.'], 401);
    }
    if ($row['role'] !== 'admin') {
        $pdo->rollBack();
        json_response(['success' => false, 'message' => 'Admin access required'], 403);
    }
    return $row;
}

function smartflow_ensure_users_active_column(PDO $pdo): void
{
    $stmt = $pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'users'
          AND COLUMN_NAME = 'is_active'
    ");
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec('ALTER TABLE users ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1 AFTER role');
    }
}

function smartflow_ensure_users_avatar_column(PDO $pdo): void
{
    $stmt = $pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'users'
          AND COLUMN_NAME = 'avatar_path'
    ");
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec('ALTER TABLE users ADD COLUMN avatar_path VARCHAR(255) NULL AFTER is_active');
    }
}

function smartflow_ensure_users_email_column(PDO $pdo): void
{
    $stmt = $pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'users'
          AND COLUMN_NAME = 'email'
    ");
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec('ALTER TABLE users ADD COLUMN email VARCHAR(120) NULL AFTER username');
        // Unique when set; multiple NULLs allowed in MySQL.
        try {
            $pdo->exec('ALTER TABLE users ADD UNIQUE KEY idx_users_email (email)');
        } catch (Throwable $e) {
            // Index may already exist from a partial migration.
        }
    }
}

/**
 * Administrator-issued temporary passwords: the flag forces a new password at the next sign-in and the
 * expiry bounds how long the temporary one works. Call outside a transaction (ALTER commits implicitly).
 */
function smartflow_ensure_users_password_reset_columns(PDO $pdo): void
{
    $present = $pdo->query("
        SELECT COLUMN_NAME FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
          AND COLUMN_NAME IN ('must_change_password', 'temp_password_expires_at')
    ")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('must_change_password', $present, true)) {
        $pdo->exec('ALTER TABLE users ADD COLUMN must_change_password TINYINT(1) NOT NULL DEFAULT 0');
    }
    if (!in_array('temp_password_expires_at', $present, true)) {
        $pdo->exec('ALTER TABLE users ADD COLUMN temp_password_expires_at DATETIME NULL');
    }
}

/**
 * @return array<string, mixed>|null
 */
function smartflow_fetch_user_by_id(PDO $pdo, int $userId): ?array
{
    smartflow_ensure_users_avatar_column($pdo);
    smartflow_ensure_users_email_column($pdo);
    $stmt = $pdo->prepare('
        SELECT u.id, u.name, u.username, u.email, u.role, u.is_active, u.avatar_path,
               o.id AS office_id, o.name AS office_name, o.code AS office_code
        FROM users u
        JOIN offices o ON o.id = u.office_id
        WHERE u.id = :id
        LIMIT 1
    ');
    $stmt->execute([':id' => $userId]);
    $row = $stmt->fetch();
    if (!$row) return null;
    // The column appears with the first administrator reset; until then nobody is flagged.
    try {
        $flag = $pdo->prepare('SELECT must_change_password FROM users WHERE id = :id LIMIT 1');
        $flag->execute([':id' => $userId]);
        $row['must_change_password'] = (int)$flag->fetchColumn();
    } catch (PDOException $e) {
        $row['must_change_password'] = 0;
    }
    return $row;
}

/**
 * @param array<string, mixed> $row
 * @return array<string, mixed>
 */
function smartflow_user_payload(array $row): array
{
    $id = (int)$row['id'];
    $avatarUrl = smartflow_avatar_url_for($id, $row['avatar_path'] ?? null);

    $email = trim((string)($row['email'] ?? ''));

    return [
        'id'          => $id,
        'name'        => (string)$row['name'],
        'username'    => (string)$row['username'],
        'email'       => $email !== '' ? $email : null,
        'role'        => (string)$row['role'],
        'office_id'   => (int)$row['office_id'],
        'office_name' => (string)$row['office_name'],
        'office_code' => (string)$row['office_code'],
        'is_active'   => (bool)(int)($row['is_active'] ?? 1),
        'must_change_password' => (bool)(int)($row['must_change_password'] ?? 0),
        'avatar_url'  => $avatarUrl,
        'has_avatar'  => $avatarUrl !== null,
    ];
}

function smartflow_avatar_url_for(int $userId, mixed $avatarPath): ?string
{
    $path = trim((string)($avatarPath ?? ''));
    if ($userId <= 0 || $path === '') {
        return null;
    }
    return 'users-avatar.php?id=' . $userId . '&v=' . rawurlencode(substr(sha1($path), 0, 8));
}

function smartflow_avatars_dir(): string
{
    $dir = __DIR__ . '/uploads/avatars';
    if (!is_dir($dir)) {
        mkdir($dir, 0755, true);
    }
    return $dir;
}

function smartflow_count_active_admins(PDO $pdo, ?int $excludeUserId = null): int
{
    smartflow_ensure_users_active_column($pdo);
    $sql = "SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = 1";
    $params = [];
    if ($excludeUserId !== null && $excludeUserId > 0) {
        $sql .= ' AND id != :id';
        $params[':id'] = $excludeUserId;
    }
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    return (int)$stmt->fetchColumn();
}
