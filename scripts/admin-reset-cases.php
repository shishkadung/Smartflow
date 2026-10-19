<?php
/** Administrator backup password reset, included only by the disposable API harness. No email is involved. */
function smartflow_test_admin_reset(PDO $pdo, array $tokens): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Admin reset cases require the disposable harness database');
    }
    $insert = $pdo->prepare('INSERT INTO users (id, name, username, password_hash, office_id, role, is_active, email) VALUES (?,?,?,?,?,?,?,?)');
    $fixture = static function (string $label, string $role, string $password = 'original-synthetic-pw-1', bool $active = true, int $office = 1) use ($insert): array {
        $id = random_int(300000, 900000);
        $username = 'adminreset_' . $label . '_' . bin2hex(random_bytes(3));
        $insert->execute([$id, 'Reset fixture ' . $label, $username, password_hash($password, PASSWORD_DEFAULT), $office, $role, $active ? 1 : 0, null]);
        return [$id, $username];
    };
    $login = static fn(string $username, string $password): array => api('auth-login.php', null, ['username' => $username, 'password' => $password]);
    $signIn = static function (string $username, string $password): string {
        [$http, $result] = api('auth-login.php', null, ['username' => $username, 'password' => $password]);
        check($http === 200 && isset($result['token']), "reset fixture $username signs in");
        return $result['token'];
    };
    $reset = static fn(string $token, int $targetId): array => api('users-admin-reset-password.php', $token, ['user_id' => $targetId]);

    [, $adminName] = $fixture('admin', 'admin', 'admin-synthetic-pw-1', true, 4);
    $adminToken = $signIn($adminName, 'admin-synthetic-pw-1');
    [$adminTargetId] = $fixture('otheradmin', 'admin', 'admin-synthetic-pw-2', true, 4);
    [$staffId, $staffName] = $fixture('staff', 'staff');
    [$headId, $headName] = $fixture('head', 'head', 'original-synthetic-pw-3', true, 3);
    [$inactiveId] = $fixture('inactive', 'staff', 'original-synthetic-pw-4', false);
    $adminId = (int)$pdo->query("SELECT id FROM users WHERE username = " . $pdo->quote($adminName))->fetchColumn();

    // --- Who may use it.
    check(api('users-admin-reset-password.php', null, ['user_id' => $staffId])[0] === 401, 'an unsigned request cannot reset a password');
    foreach (['eng', 'head'] as $who) {
        check($reset($tokens[$who], $staffId)[0] === 403, "$who cannot issue a temporary password");
    }
    $get = curl_init($GLOBALS['base'] . '/users-admin-reset-password.php');
    curl_setopt_array($get, [CURLOPT_RETURNTRANSFER => true, CURLOPT_HTTPHEADER => ["Authorization: Bearer $adminToken"]]);
    curl_exec($get);
    check(curl_getinfo($get, CURLINFO_HTTP_CODE) === 405, 'the reset only accepts POST');
    curl_close($get);
    check(api('users-admin-reset-password.php', $adminToken, [])[0] === 400, 'a target user is required');
    check($reset($adminToken, $adminId)[0] === 403, 'an administrator cannot reset their own password this way');
    check($reset($adminToken, $adminTargetId)[0] === 403, 'another administrator account cannot be reset this way');
    check($reset($adminToken, 999999999)[0] === 404, 'an unknown user is reported as not found');
    check($reset($adminToken, $inactiveId)[0] === 409, 'an inactive account must be activated first');
    check((int)$pdo->query("SELECT must_change_password FROM users WHERE id = $staffId")->fetchColumn() === 0
        && (int)$pdo->query("SELECT COUNT(*) FROM audit_logs WHERE event_type = 'user.password_admin_reset'")->fetchColumn() === 0,
        'refused attempts change nothing and are not recorded as resets');

    // --- A successful reset for a staff account, end to end.
    $oldToken = $signIn($staffName, 'original-synthetic-pw-1');
    [$http, $issued] = $reset($adminToken, $staffId);
    $temporary = (string)($issued['temporary_password'] ?? '');
    check($http === 200 && $issued['success'] === true && preg_match('/^[A-HJ-NP-Za-km-z2-9]{12}$/', $temporary) === 1
        && $issued['must_change_password'] === true && $issued['user']['username'] === $staffName,
        'a temporary password of 12 unambiguous characters is issued once');
    $row = $pdo->query("SELECT password_hash, must_change_password, temp_password_expires_at > NOW() AS future, TIMESTAMPDIFF(HOUR, NOW(), temp_password_expires_at) AS hours FROM users WHERE id = $staffId")->fetch();
    check(!str_contains((string)$row['password_hash'], $temporary) && password_verify($temporary, (string)$row['password_hash'])
        && (int)$row['must_change_password'] === 1 && (int)$row['future'] === 1 && (int)$row['hours'] >= 23 && (int)$row['hours'] <= 24,
        'only a hash is stored, flagged for replacement and valid for about 24 hours');
    check(api('auth-session.php', $oldToken)[0] === 401, 'the account\'s earlier session ends immediately');
    check($login($staffName, 'original-synthetic-pw-1')[0] === 401, 'the previous password no longer works');
    [$http, $first] = $login($staffName, $temporary);
    check($http === 200 && $first['user']['must_change_password'] === true, 'the temporary password signs in and reports that a change is required');
    $tempToken = $first['token'];
    [$http, $blocked] = api('office-documents.php', $tempToken);
    check($http === 403 && ($blocked['password_change_required'] ?? false) === true && str_contains($blocked['message'], 'choose a new password'),
        'with only a temporary password every other action is refused until it is replaced');
    [$http, $session] = api('auth-session.php', $tempToken);
    check($http === 200 && $session['user']['must_change_password'] === true, 'the session check still works so the client can show the change screen');
    check(api('users-change-password.php', $tempToken, ['current_password' => 'wrong-synthetic-pw', 'new_password' => 'replacement-synthetic-pw-5'])[0] === 400,
        'a wrong current password cannot be used to replace the temporary one');
    check(api('users-change-password.php', $tempToken, ['current_password' => $temporary, 'new_password' => 'replacement-synthetic-pw-5'])[0] === 200,
        'the temporary password can be replaced by choosing a new password');
    check($login($staffName, $temporary)[0] === 401, 'the temporary password stops working once replaced');
    [$http, $normal] = $login($staffName, 'replacement-synthetic-pw-5');
    check($http === 200 && $normal['user']['must_change_password'] === false && api('office-documents.php', $normal['token'])[0] === 200
        && (int)$pdo->query("SELECT must_change_password FROM users WHERE id = $staffId")->fetchColumn() === 0,
        'after the change the account works normally again');

    // --- Audit trail without secrets, and heads are supported too.
    $audit = $pdo->query("SELECT COUNT(*) AS c, SUM(COALESCE(message,'') LIKE " . $pdo->quote("%$temporary%") . " OR COALESCE(meta_json,'') LIKE " . $pdo->quote("%$temporary%") . ") AS leaks
        FROM audit_logs WHERE event_type = 'user.password_admin_reset'")->fetch();
    check((int)$audit['c'] === 1 && (int)$audit['leaks'] === 0, 'the reset is audited with who and whom, and the password is nowhere in the audit trail');
    $headOld = $signIn($headName, 'original-synthetic-pw-3');
    [$http, $headIssued] = $reset($adminToken, $headId);
    check($http === 200 && api('auth-session.php', $headOld)[0] === 401 && $login($headName, (string)$headIssued['temporary_password'])[0] === 200,
        'a department head can be reset the same way');

    // --- Reissue, expiry and the emailed-code path.
    [, $second] = $reset($adminToken, $headId);
    check($login($headName, (string)$headIssued['temporary_password'])[0] === 401 && $login($headName, (string)$second['temporary_password'])[0] === 200
        && $second['temporary_password'] !== $headIssued['temporary_password'], 'issuing again replaces the earlier temporary password');
    $pdo->exec("UPDATE users SET temp_password_expires_at = DATE_SUB(NOW(), INTERVAL 1 MINUTE) WHERE id = $headId");
    [$http, $expired] = $login($headName, (string)$second['temporary_password']);
    check($http === 403 && str_contains($expired['message'], 'temporary password has expired') && !isset($expired['token']),
        'an expired temporary password is refused with an instruction to ask for another');
    $code = (string)random_int(100000, 999999);
    $pdo->prepare('INSERT INTO password_resets (user_id, token_hash, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR))')
        ->execute([$headId, password_hash($code, PASSWORD_DEFAULT)]);
    check(api('auth-reset-password.php', null, ['username' => $headName, 'code' => $code, 'new_password' => 'emailed-synthetic-pw-6'])[0] === 200
        && (int)$pdo->query("SELECT must_change_password FROM users WHERE id = $headId")->fetchColumn() === 0
        && $login($headName, 'emailed-synthetic-pw-6')[1]['user']['must_change_password'] === false,
        'resetting with an emailed code also clears a pending temporary password');
    [, $staffAgain] = $reset($adminToken, $staffId);
    $pdo->prepare('INSERT INTO password_resets (user_id, token_hash, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR))')
        ->execute([$staffId, password_hash('123456', PASSWORD_DEFAULT)]);
    $pdo->prepare('UPDATE password_resets SET used_at = NULL WHERE user_id = ?')->execute([$staffId]);
    check($pdo->query("SELECT COUNT(*) FROM password_resets WHERE user_id = $staffId AND used_at IS NULL")->fetchColumn() >= 1
        && api('auth-reset-password.php', null, ['username' => $staffName, 'code' => '123456', 'new_password' => 'another-synthetic-pw-7'])[0] === 200,
        'an emailed code remains a valid recovery path after an administrator reset');

    // --- A server upgraded from before this feature has no flag columns until the first sign-in adds them.
    $pdo->exec('ALTER TABLE users DROP COLUMN must_change_password, DROP COLUMN temp_password_expires_at');
    check(api('auth-session.php', $adminToken)[0] === 200 && api('office-documents.php', $adminToken)[0] !== 500,
        'existing sessions keep working before the flag columns exist');
    check($login($staffName, 'another-synthetic-pw-7')[0] === 200
        && (int)$pdo->query("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME IN ('must_change_password','temp_password_expires_at')")->fetchColumn() === 2,
        'the first sign-in after an upgrade adds the flag columns and works normally');

    // --- Abuse limit.
    [, $busyName] = $fixture('busyadmin', 'admin', 'busy-synthetic-pw-1', true, 4);
    $busyToken = $signIn($busyName, 'busy-synthetic-pw-1');
    [$targetId] = $fixture('target', 'staff', 'original-synthetic-pw-8');
    $statuses = [];
    for ($i = 0; $i < 11; $i++) $statuses[] = $reset($busyToken, $targetId)[0];
    check(array_slice($statuses, 0, 10) === array_fill(0, 10, 200) && $statuses[10] === 429,
        'an administrator can issue ten temporary passwords per hour, then is asked to wait');
}
