<?php
// POST /users-set-active.php
// Body: { "user_id": 3, "active": false }
// Admin: deactivate or reactivate a user (soft delete).

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/audit-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$adminId = require_user_id();
smartflow_require_admin($pdo, $adminId);
smartflow_ensure_users_active_column($pdo);

$body = get_json_body();
$targetId = (int)($body['user_id'] ?? 0);
$activeRaw = $body['active'] ?? null;

if ($targetId <= 0) {
    json_response(['success' => false, 'message' => 'user_id is required'], 400);
}
if (!is_bool($activeRaw)) {
    json_response(['success' => false, 'message' => 'active must be true or false'], 400);
}
$active = $activeRaw;

if ($targetId === $adminId) {
    json_response(['success' => false, 'message' => 'You cannot deactivate your own account'], 403);
}

$pdo->beginTransaction();
// Serialize admin status changes before taking individual target locks. A
// locking read also sees the current count after another deactivation commits.
$admins = $pdo->query("SELECT id, is_active FROM users WHERE role = 'admin' ORDER BY id FOR UPDATE")->fetchAll();
$activeAdmins = 0;
$actingAdminActive = false;
foreach ($admins as $admin) {
    if ((int)$admin['is_active'] === 1) {
        $activeAdmins++;
        if ((int)$admin['id'] === $adminId) $actingAdminActive = true;
    }
}
if (!$actingAdminActive || user_id_from_token(get_bearer_token()) !== $adminId) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'Your session has ended. Please sign in again.'], 401);
}
$stmt = $pdo->prepare('
    SELECT id, username, role, is_active
    FROM users
    WHERE id = :id
    LIMIT 1 FOR UPDATE
');
$stmt->execute([':id' => $targetId]);
$target = $stmt->fetch();
if (!$target) {
    $pdo->rollBack();
    json_response(['success' => false, 'message' => 'User not found'], 404);
}

if (!$active && (string)$target['role'] === 'admin') {
    if ((int)$target['is_active'] === 1 && $activeAdmins <= 1) {
        $pdo->rollBack();
        json_response([
            'success' => false,
            'message' => 'Cannot deactivate the last active admin account',
        ], 403);
    }
}

$upd = $pdo->prepare('UPDATE users SET is_active = :active WHERE id = :id');
$upd->execute([
    ':active' => $active ? 1 : 0,
    ':id'     => $targetId,
]);
if (!$active) revoke_user_tokens($targetId);
$pdo->commit();

smartflow_audit_action(
    $pdo,
    $active ? 'user.reactivate' : 'user.deactivate',
    $adminId,
    ($active ? 'Reactivated ' : 'Deactivated ') . $target['username'],
    [
        'target_user_id' => $targetId,
        'username'       => $target['username'],
        'role'           => $target['role'],
        'was_active'     => (bool)(int)$target['is_active'],
    ]
);

json_response([
    'success' => true,
    'message' => $active ? 'Account reactivated' : 'Account deactivated',
    'user'    => [
        'id'        => $targetId,
        'username'  => $target['username'],
        'is_active' => $active,
    ],
]);
