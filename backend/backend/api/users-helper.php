<?php
// User table helpers (active flag for soft deactivate).

declare(strict_types=1);

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
    return $row ?: null;
}

/**
 * @param array<string, mixed> $row
 * @return array<string, mixed>
 */
function smartflow_user_payload(array $row): array
{
    $id = (int)$row['id'];
    $avatarPath = trim((string)($row['avatar_path'] ?? ''));
    $avatarUrl = null;
    if ($avatarPath !== '') {
        // Cache-bust when path changes (filename includes timestamp or hash).
        $avatarUrl = 'users-avatar.php?id=' . $id . '&v=' . rawurlencode(substr(sha1($avatarPath), 0, 8));
    }

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
        'avatar_url'  => $avatarUrl,
        'has_avatar'  => $avatarUrl !== null,
    ];
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
