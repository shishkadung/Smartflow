<?php
declare(strict_types=1);
require_once __DIR__ . '/folder-contents-helper.php';
require_once __DIR__ . '/users-helper.php';
require_once __DIR__ . '/movement-corrections-helper.php';

function smartflow_journey_steps(array $movements, ?int $now = null): array {
    $now ??= time();
    usort($movements, fn($a, $b) => strcmp($a['scanned_at'], $b['scanned_at']) ?: ((int)$a['id'] <=> (int)$b['id']));
    $steps = [];
    foreach ($movements as $i => $movement) {
        $next = $movements[$i + 1] ?? null;
        $from = strtotime($movement['scanned_at']);
        $to = $next ? strtotime($next['scanned_at']) : $now;
        $steps[] = $movement + [
            'is_current' => $next === null,
            'elapsed_hours' => round(max(0, $to - $from) / 3600, 2),
            'duration_kind' => $movement['status'] === 'IN' ? 'at_office' : 'in_transit',
            'interval_complete' => $next !== null,
        ];
    }
    return $steps;
}

function smartflow_document_journey(PDO $pdo, string $id): array {
    smartflow_ensure_folder_contents($pdo);
    smartflow_ensure_users_avatar_column($pdo);
    smartflow_ensure_movement_corrections($pdo);
    $stmt = $pdo->prepare('SELECT m.id, m.status, m.scanned_at, m.remarks, m.contents_receipt,
        o.name AS office_name, o.code AS office_code,
        dest.name AS destination_office_name, dest.code AS destination_office_code,
        u.id AS user_id, u.name AS user_name, u.avatar_path AS avatar_path
        FROM movements m JOIN offices o ON o.id = m.office_id
        LEFT JOIN offices dest ON dest.id = m.destination_office_id
        JOIN users u ON u.id = m.user_id WHERE m.document_id = ?
        ORDER BY m.scanned_at ASC, m.id ASC');
    $stmt->execute([$id]);
    $rows = $stmt->fetchAll();
    $corrections = smartflow_movement_destination_corrections($pdo, array_column($rows, 'id'));
    foreach ($rows as &$row) {
        $row['destination_corrections'] = $corrections[(int)$row['id']] ?? [];
        $row['contents_receipt'] = smartflow_contents_decode($row['contents_receipt']);
        $row['avatar_url'] = smartflow_avatar_url_for((int)$row['user_id'], $row['avatar_path'] ?? null);
        unset($row['avatar_path']);
    }
    unset($row);
    return smartflow_journey_steps($rows);
}
