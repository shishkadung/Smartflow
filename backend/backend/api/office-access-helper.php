<?php

declare(strict_types=1);

// Shared office scope for staff/head views. Municipal admins may inspect any office.
function smartflow_require_office_scope(PDO $pdo, int $userId, int $officeId): void
{
    $stmt = $pdo->prepare('SELECT role, office_id FROM users WHERE id = :id AND is_active = 1 LIMIT 1');
    $stmt->execute([':id' => $userId]);
    $user = $stmt->fetch();
    if (!$user) {
        json_response(['success' => false, 'message' => 'User not found or inactive'], 401);
    }
    if ($user['role'] !== 'admin' && (int)$user['office_id'] !== $officeId) {
        json_response(['success' => false, 'message' => 'Office data is limited to your own office'], 403);
    }
}
