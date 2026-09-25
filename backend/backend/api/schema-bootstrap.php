<?php

declare(strict_types=1);

/**
 * Runtime schema fixes for older smartflow DBs (idempotent).
 */

function smartflow_ensure_signup_requests(PDO $pdo): void
{
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS signup_requests (
          id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
          request_code    VARCHAR(20)  NOT NULL,
          full_name       VARCHAR(100) NOT NULL,
          username        VARCHAR(50)  NOT NULL,
          email           VARCHAR(120) NOT NULL,
          password_hash   VARCHAR(255) NOT NULL,
          office_id       INT UNSIGNED NOT NULL,
          requested_role  VARCHAR(20)  NOT NULL DEFAULT 'staff',
          status          ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
          approved_by     INT UNSIGNED NULL,
          approved_at     DATETIME     NULL,
          created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          UNIQUE KEY uk_signup_username (username),
          UNIQUE KEY uk_signup_code (request_code),
          KEY idx_signup_status (status),
          CONSTRAINT fk_signup_office FOREIGN KEY (office_id) REFERENCES offices (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");
}

function smartflow_ensure_documents_created_by(PDO $pdo): void
{
    $stmt = $pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'documents'
          AND COLUMN_NAME = 'created_by'
    ");
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec('ALTER TABLE documents ADD COLUMN created_by INT UNSIGNED NULL AFTER description');
        $fallbackUser = (int)$pdo->query('SELECT id FROM users ORDER BY id ASC LIMIT 1')->fetchColumn();
        if ($fallbackUser > 0) {
            $pdo->exec('UPDATE documents SET created_by = ' . $fallbackUser . ' WHERE created_by IS NULL');
        }
        $pdo->exec('ALTER TABLE documents MODIFY created_by INT UNSIGNED NOT NULL');
        try {
            $pdo->exec('
                ALTER TABLE documents
                ADD CONSTRAINT fk_documents_created_by
                FOREIGN KEY (created_by) REFERENCES users (id)
            ');
        } catch (PDOException $e) {
            // FK may already exist under another name — ignore.
        }
    }
}

function smartflow_ensure_documents_date_registered(PDO $pdo): void
{
    $stmt = $pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'documents'
          AND COLUMN_NAME = 'date_registered'
    ");
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec('
            ALTER TABLE documents
            ADD COLUMN date_registered DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            AFTER created_by
        ');
    }
}

function smartflow_ensure_movements_destination_column(PDO $pdo): void
{
    $stmt = $pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'movements'
          AND COLUMN_NAME = 'destination_office_id'
    ");
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec('
            ALTER TABLE movements
            ADD COLUMN destination_office_id INT UNSIGNED NULL DEFAULT NULL
            AFTER office_id,
            ADD KEY idx_movements_destination (destination_office_id)
        ');
        try {
            $pdo->exec('
                ALTER TABLE movements
                ADD CONSTRAINT fk_movements_destination
                FOREIGN KEY (destination_office_id) REFERENCES offices (id)
            ');
        } catch (PDOException $e) {
            // Ignore if FK already exists under another name.
        }
    }
}

function smartflow_ensure_audit_logs(PDO $pdo): void
{
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS audit_logs (
          id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          event_type    VARCHAR(64)     NOT NULL,
          document_id   VARCHAR(50)     NULL,
          user_id       INT UNSIGNED    NULL,
          office_id     INT UNSIGNED    NULL,
          status        VARCHAR(10)     NULL,
          outcome       VARCHAR(20)     NOT NULL,
          message       VARCHAR(255)    NOT NULL,
          meta_json     JSON            NULL,
          ip_address    VARCHAR(45)     NULL,
          user_agent    VARCHAR(255)    NULL,
          created_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          KEY idx_audit_event_created (event_type, created_at),
          KEY idx_audit_document (document_id, created_at),
          KEY idx_audit_user (user_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");
}

function smartflow_ensure_password_resets(PDO $pdo): void
{
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS password_resets (
          id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
          user_id       INT UNSIGNED NOT NULL,
          token_hash    VARCHAR(255) NOT NULL,
          expires_at    DATETIME     NOT NULL,
          used_at       DATETIME     NULL,
          created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          KEY idx_token_hash (token_hash),
          KEY idx_user_id (user_id),
          KEY idx_expires_at (expires_at),
          CONSTRAINT fk_password_resets_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");
}

function smartflow_ensure_auth_tokens(PDO $pdo): void
{
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS auth_tokens (
          id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
          user_id INT UNSIGNED NOT NULL,
          token_hash CHAR(64) NOT NULL UNIQUE,
          expires_at DATETIME NOT NULL,
          is_revoked TINYINT(1) NOT NULL DEFAULT 0,
          ip_address VARCHAR(45) NULL,
          user_agent VARCHAR(255) NULL,
          created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_user_id (user_id),
          INDEX idx_token_hash (token_hash),
          INDEX idx_expires_at (expires_at),
          CONSTRAINT fk_auth_tokens_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    $hasRevoked = (int)$pdo->query("
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'auth_tokens'
          AND COLUMN_NAME = 'is_revoked'
    ")->fetchColumn();
    if ($hasRevoked === 0) {
        $pdo->exec('ALTER TABLE auth_tokens ADD COLUMN is_revoked TINYINT(1) NOT NULL DEFAULT 0 AFTER expires_at');
    }
}

function smartflow_ensure_pilot_offices(PDO $pdo): void
{
    $insert = $pdo->prepare('INSERT IGNORE INTO offices (name, code) VALUES (:name, :code)');
    foreach ([
        ['Engineering Office', 'ENG'],
        ['Human Resources Office', 'HR'],
        ['Budget Office', 'BUD'],
        ['Accounting Office', 'ACC'],
        ['Municipal Treasury', 'TRE'],
        ['Office of the Mayor', 'MAY'],
    ] as $row) {
        $insert->execute([
            ':name' => $row[0],
            ':code' => $row[1],
        ]);
    }
}

/**
 * Concurrent API requests can race on ALTER/CREATE during bootstrap.
 * Duplicate column / already-exists errors are safe to ignore.
 */
function smartflow_is_benign_schema_race(PDOException $e): bool
{
    $msg = $e->getMessage();
    foreach ([
        'Duplicate column',
        'Duplicate key name',
        'already exists',
        'check that it exists', // DROP INDEX / FK when missing mid-race
    ] as $needle) {
        if (stripos($msg, $needle) !== false) {
            return true;
        }
    }
    return false;
}

function smartflow_run_schema_step(callable $step): void
{
    try {
        $step();
    } catch (PDOException $e) {
        if (smartflow_is_benign_schema_race($e)) {
            return;
        }
        throw $e;
    }
}

function smartflow_bootstrap_schema(PDO $pdo): void
{
    require_once __DIR__ . '/thresholds-helper.php';
    require_once __DIR__ . '/users-helper.php';
    require_once __DIR__ . '/document-requests-helper.php';

    $steps = [
        static fn () => smartflow_ensure_pilot_offices($pdo),
        static fn () => smartflow_ensure_signup_requests($pdo),
        static fn () => smartflow_ensure_users_active_column($pdo),
        static fn () => smartflow_ensure_users_avatar_column($pdo),
        static fn () => smartflow_ensure_users_email_column($pdo),
        static fn () => smartflow_ensure_documents_due_column($pdo),
        static fn () => smartflow_ensure_documents_created_by($pdo),
        static fn () => smartflow_ensure_documents_date_registered($pdo),
        static fn () => smartflow_ensure_movements_destination_column($pdo),
        static fn () => smartflow_ensure_audit_logs($pdo),
        static fn () => smartflow_ensure_password_resets($pdo),
        static fn () => smartflow_ensure_auth_tokens($pdo),
        static fn () => smartflow_ensure_processing_thresholds($pdo),
        static fn () => smartflow_ensure_document_requests($pdo),
    ];

    foreach ($steps as $step) {
        smartflow_run_schema_step($step);
    }
}

function smartflow_json_exception_handler(Throwable $e): void
{
    if (headers_sent()) {
        return;
    }
    if (function_exists('smartflow_log')) {
        smartflow_log('error', $e->getMessage(), [
            'type' => $e::class,
            'file' => $e->getFile(),
            'line' => $e->getLine(),
        ]);
    }
    $message = 'Server error';
    if ($e instanceof PDOException) {
        $message = 'Database error — check MySQL and schema';
    }
    json_response([
        'success' => false,
        'message' => $message,
    ], 500);
}

function smartflow_register_error_handlers(): void
{
    set_exception_handler('smartflow_json_exception_handler');

    set_error_handler(static function (int $severity, string $message, string $file, int $line): bool {
        if (!(error_reporting() & $severity)) {
            return false;
        }
        throw new ErrorException($message, 0, $severity, $file, $line);
    });
}
