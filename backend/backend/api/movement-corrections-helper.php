<?php
declare(strict_types=1);

/** Corrections preserve the OUT event and append the reason/old destination atomically. */
function smartflow_ensure_movement_corrections(PDO $pdo): void
{
    static $ready = false;
    if ($ready) return;
    $exists = $pdo->query("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='movements' AND COLUMN_NAME='is_return'");
    if ((int)$exists->fetchColumn() === 0) {
        smartflow_run_schema_step(static fn() => $pdo->exec('ALTER TABLE movements ADD COLUMN is_return TINYINT(1) NULL DEFAULT NULL'));
    }
    $pdo->exec("CREATE TABLE IF NOT EXISTS movement_destination_corrections (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        movement_id INT UNSIGNED NOT NULL, document_id VARCHAR(50) NOT NULL,
        previous_destination_office_id INT UNSIGNED NOT NULL, destination_office_id INT UNSIGNED NOT NULL,
        reason VARCHAR(1000) NOT NULL, corrected_by INT UNSIGNED NOT NULL,
        corrected_by_office_id INT UNSIGNED NOT NULL, corrected_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX correction_movement (movement_id, id), INDEX correction_document (document_id, id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $ready = true;
}

function smartflow_movement_destination_corrections(PDO $pdo, array $movementIds): array
{
    $ids = array_values(array_unique(array_filter(array_map('intval', $movementIds), static fn(int $id): bool => $id > 0)));
    if (!$ids) return [];
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $pdo->prepare("SELECT c.*, old.name AS previous_destination_office_name, old.code AS previous_destination_office_code,
        dest.name AS destination_office_name, dest.code AS destination_office_code,
        u.name AS corrected_by_name, sender.name AS corrected_by_office_name, sender.code AS corrected_by_office_code
        FROM movement_destination_corrections c
        JOIN offices old ON old.id=c.previous_destination_office_id JOIN offices dest ON dest.id=c.destination_office_id
        JOIN users u ON u.id=c.corrected_by JOIN offices sender ON sender.id=c.corrected_by_office_id
        WHERE c.movement_id IN ($placeholders) ORDER BY c.id ASC");
    $stmt->execute($ids);
    $byMovement = [];
    foreach ($stmt->fetchAll() as $row) {
        foreach (['id', 'movement_id', 'previous_destination_office_id', 'destination_office_id', 'corrected_by', 'corrected_by_office_id'] as $field) $row[$field] = (int)$row[$field];
        $byMovement[$row['movement_id']][] = $row;
    }
    return $byMovement;
}

function smartflow_movement_correction_state(PDO $pdo, ?array $last, array $user, bool $filed = false): array
{
    $corrections = $last ? (smartflow_movement_destination_corrections($pdo, [(int)$last['id']])[(int)$last['id']] ?? []) : [];
    return [
        'destination_corrections' => $corrections,
        'last_destination_correction_id' => $corrections ? (int)$corrections[array_key_last($corrections)]['id'] : 0,
        'can_correct_destination' => !$filed && $last && $last['status'] === 'OUT'
            && $user['role'] === 'staff' && (int)$last['office_id'] === (int)$user['office_id']
            && (int)($last['destination_office_id'] ?? 0) > 0,
    ];
}
