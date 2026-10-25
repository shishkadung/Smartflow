<?php
declare(strict_types=1);

function smartflow_ensure_signup_status_key(PDO $pdo): void
{
    $column = $pdo->query("SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'signup_requests' AND COLUMN_NAME = 'status_key_hash'");
    if (!(int)$column->fetchColumn()) {
        $pdo->exec('ALTER TABLE signup_requests ADD COLUMN status_key_hash CHAR(64) NULL');
    }
    $approved = $pdo->query("SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'signup_requests' AND COLUMN_NAME = 'approved_user_id'");
    if (!(int)$approved->fetchColumn()) {
        // No username-based backfill: usernames can be changed and reassigned.
        $pdo->exec('ALTER TABLE signup_requests ADD COLUMN approved_user_id INT NULL');
    }
}
