<?php
/** Administrator reset-email editor, included only by the disposable API harness. */
function smartflow_test_admin_email(PDO $pdo, array $tokens): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Admin email cases require the disposable harness database');
    }
    $insert = $pdo->prepare('INSERT INTO users (id, name, username, password_hash, office_id, role, is_active, email) VALUES (?,?,?,?,?,?,?,?)');
    $fixture = static function (string $label, string $role, ?string $email = null) use ($insert): array {
        $id = random_int(300000, 900000);
        $username = 'adminemail_' . $label . '_' . bin2hex(random_bytes(3));
        $insert->execute([$id, 'Email fixture ' . $label, $username, password_hash('synthetic-email-pw-1', PASSWORD_DEFAULT), $role === 'admin' ? 4 : 1, $role, 1, $email]);
        return [$id, $username];
    };
    [, $adminName] = $fixture('admin', 'admin', 'admin.email.fixture@example.test');
    [$http, $in] = api('auth-login.php', null, ['username' => $adminName, 'password' => 'synthetic-email-pw-1']);
    check($http === 200, 'email editor fixture admin signs in');
    $adminToken = $in['token'];
    [$otherAdminId] = $fixture('otheradmin', 'admin', 'other.admin.fixture@example.test');
    [$staffId, $staffName] = $fixture('staff', 'staff', 'wrong.address@example.test');
    [$headId] = $fixture('head', 'head', 'head.fixture@example.test');
    [$takenId] = $fixture('taken', 'staff', 'taken.fixture@example.test');
    $set = static fn(?string $token, int $id, string $email): array => api('users-admin-set-email.php', $token, ['user_id' => $id, 'email' => $email]);

    check($set(null, $staffId, 'new@example.test')[0] === 401, 'an unsigned request cannot change an email');
    foreach (['eng', 'head'] as $who) {
        check($set($tokens[$who], $staffId, 'new@example.test')[0] === 403, "$who cannot change a user's email");
    }
    check($set($adminToken, 0, 'new@example.test')[0] === 400, 'a target user is required');
    foreach (['', 'not-an-email', 'a@b', str_repeat('x', 115) . '@example.test'] as $bad) {
        check($set($adminToken, $staffId, $bad)[0] === 400, 'an invalid address is refused: ' . substr($bad, 0, 12));
    }
    check($set($adminToken, 999999999, 'new@example.test')[0] === 404, 'an unknown user is not found');
    check($set($adminToken, $otherAdminId, 'new@example.test')[0] === 403, 'administrator addresses are changed in Profile, not here');
    check($set($adminToken, $staffId, 'TAKEN.fixture@example.test')[0] === 409, 'an address used by another account is refused');
    check($pdo->query("SELECT email FROM users WHERE id = $staffId")->fetchColumn() === 'wrong.address@example.test',
        'refused attempts leave the address unchanged');

    // An unused emailed code for the old address must stop working.
    $pdo->prepare('INSERT INTO password_resets (user_id, token_hash, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 15 MINUTE))')
        ->execute([$staffId, hash('sha256', 'synthetic-old-code')]);
    [$http, $ok] = $set($adminToken, $staffId, '  Correct.Address@Example.test ');
    check($http === 200 && $ok['user']['email'] === 'correct.address@example.test'
        && $pdo->query("SELECT email FROM users WHERE id = $staffId")->fetchColumn() === 'correct.address@example.test',
        'a staff address is trimmed, lower-cased and saved');
    check((int)$pdo->query("SELECT COUNT(*) FROM password_resets WHERE user_id = $staffId AND used_at IS NULL")->fetchColumn() === 0,
        'unused codes sent to the previous address are cancelled');
    [$http, $same] = $set($adminToken, $staffId, 'correct.address@example.test');
    check($http === 200 && ($same['unchanged'] ?? false) === true, 'saving the same address is reported as unchanged');
    check($set($adminToken, $headId, 'head.new@example.test')[0] === 200, 'a head address can be changed');

    $audit = (string)$pdo->query("SELECT GROUP_CONCAT(CONCAT(message, ' ', COALESCE(meta_json, '')) SEPARATOR ' ') FROM audit_logs WHERE event_type = 'user.email_update'")->fetchColumn();
    check(substr_count($audit, 'Changed the reset email address') === 2
        && !str_contains($audit, 'wrong.address') && !str_contains($audit, 'correct.address'),
        'changes are audited with masked addresses only');

    [, $list] = api('users-list.php', $adminToken);
    $found = array_values(array_filter($list['users'] ?? [], static fn($u) => (int)$u['id'] === $staffId));
    check(($found[0]['email'] ?? null) === 'correct.address@example.test', 'the administrator list shows the saved address');
    check(api('users-list.php', $tokens['eng'])[0] === 403, 'staff still cannot list users or their addresses');

    $statuses = [];
    for ($i = 0; $i < 61; $i++) $statuses[] = $set($adminToken, $takenId, "limit$i@example.test")[0];
    check($statuses[60] === 429, 'an administrator is limited to sixty address changes per hour');
}
