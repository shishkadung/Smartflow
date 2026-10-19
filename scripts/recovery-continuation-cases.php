<?php
/** Password recovery regressions, included only by the disposable API harness. No email is sent. */
function smartflow_test_recovery_continuation(PDO $pdo): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Recovery continuation cases require the disposable harness database');
    }

    $createUser = static function (string $scenario) use ($pdo): array {
        $username = 'recovery_' . $scenario . '_' . bin2hex(random_bytes(4));
        $password = 'synthetic-recovery-original';
        $pdo->prepare('INSERT INTO users (name, username, password_hash, office_id, role, email)
            VALUES (?,?,?,1,"staff",NULL)')
            ->execute(['Synthetic recovery fixture', $username, password_hash($password, PASSWORD_DEFAULT)]);
        return [(int)$pdo->lastInsertId(), $username, $password];
    };
    $seedCode = static function (int $userId, bool $expired = false) use ($pdo): array {
        // Keep synthetic codes in memory; assertions and logs never print them.
        $code = (string)random_int(100000, 999999);
        $pdo->prepare('INSERT INTO password_resets (user_id, token_hash, expires_at)
            VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR))')
            ->execute([$userId, password_hash($code, PASSWORD_DEFAULT)]);
        $resetId = (int)$pdo->lastInsertId();
        if ($expired) $pdo->exec("UPDATE password_resets SET expires_at = DATE_SUB(NOW(), INTERVAL 1 SECOND) WHERE id = $resetId");
        return [$resetId, $code];
    };
    $login = static fn(string $username, string $password): array => api('auth-login.php', null,
        ['username' => $username, 'password' => $password]);
    $reset = static fn(string $username, string $code, string $password): array => api('auth-reset-password.php', null,
        ['username' => $username, 'code' => $code, 'new_password' => $password]);

    [$issuanceId, $issuanceName] = $createUser('issuance');
    [$previousReset] = $seedCode($issuanceId);
    [$http, $issued] = api('auth-forgot-password.php', null, ['username' => $issuanceName]);
    check($http === 200 && $issued === ['success' => true,
        'message' => 'If an account exists with that username, a password reset code has been generated.'],
        'recovery issuance exposes no code, expiry or delivery/account metadata');
    $issuedRow = $pdo->query("SELECT id, token_hash, used_at, TIMESTAMPDIFF(SECOND, NOW(), expires_at) AS seconds_remaining
        FROM password_resets WHERE user_id = $issuanceId ORDER BY id DESC LIMIT 1")->fetch();
    check($issuedRow && (int)$issuedRow['id'] !== $previousReset && $issuedRow['used_at'] === null
        && password_get_info($issuedRow['token_hash'])['algoName'] !== 'unknown'
        && (int)$issuedRow['seconds_remaining'] >= 3590 && (int)$issuedRow['seconds_remaining'] <= 3600,
        'recovery stores a private password hash with a one-hour database-clock expiry');
    check($pdo->query("SELECT used_at FROM password_resets WHERE id = $previousReset")->fetchColumn() !== null
        && (int)$pdo->query("SELECT COUNT(*) FROM password_resets WHERE user_id = $issuanceId AND used_at IS NULL")->fetchColumn() === 1,
        'new recovery issuance retires the earlier unused code');

    [$userId, $username, $originalPassword] = $createUser('success');
    [$http, $first] = $login($username, $originalPassword);
    [$secondHttp, $second] = $login($username, $originalPassword);
    check($http === 200 && $secondHttp === 200 && $first['token'] !== $second['token'],
        'recovery fixture has two independently valid pre-reset sessions');
    [$resetId, $code] = $seedCode($userId);
    $originalHash = $pdo->query("SELECT password_hash FROM users WHERE id = $userId")->fetchColumn();
    $wrongCode = $code === '100000' ? '100001' : '100000';
    check($reset($username, $wrongCode, 'synthetic-recovery-replacement')[0] === 401
        && $originalHash === $pdo->query("SELECT password_hash FROM users WHERE id = $userId")->fetchColumn()
        && $pdo->query("SELECT used_at FROM password_resets WHERE id = $resetId")->fetchColumn() === null,
        'wrong recovery code changes neither the password nor code consumption');
    check($reset($username, $code, 'short')[0] === 400
        && $pdo->query("SELECT used_at FROM password_resets WHERE id = $resetId")->fetchColumn() === null,
        'weak replacement password is rejected without consuming the valid code');

    // A failed session revocation must roll back both the password and code consumption.
    $pdo->exec("CREATE TRIGGER test_recovery_revoke_failure BEFORE UPDATE ON auth_tokens
        FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Injected synthetic reset revocation failure'");
    try {
        [$http] = $reset($username, $code, 'synthetic-recovery-replacement');
        check($http === 500 && $originalHash === $pdo->query("SELECT password_hash FROM users WHERE id = $userId")->fetchColumn()
            && $pdo->query("SELECT used_at FROM password_resets WHERE id = $resetId")->fetchColumn() === null,
            'failed reset revocation rolls back the replacement password and code consumption');
    } finally {
        $pdo->exec('DROP TRIGGER test_recovery_revoke_failure');
    }
    check(api('auth-session.php', $first['token'])[0] === 200 && api('auth-session.php', $second['token'])[0] === 200,
        'failed reset preserves both existing device sessions');
    [$http, $saved] = $reset($username, $code, 'synthetic-recovery-replacement');
    check($http === 200 && ($saved['success'] ?? false)
        && password_verify('synthetic-recovery-replacement', $pdo->query("SELECT password_hash FROM users WHERE id = $userId")->fetchColumn())
        && $pdo->query("SELECT used_at FROM password_resets WHERE id = $resetId")->fetchColumn() !== null,
        'valid recovery code atomically replaces the password and is consumed');
    check(api('auth-session.php', $first['token'])[0] === 401 && api('auth-session.php', $second['token'])[0] === 401
        && (int)$pdo->query("SELECT COUNT(*) FROM auth_tokens WHERE user_id = $userId AND is_revoked = 0")->fetchColumn() === 0,
        'successful recovery revokes every existing device session');
    check($login($username, $originalPassword)[0] === 401
        && $login($username, 'synthetic-recovery-replacement')[0] === 200,
        'after recovery only the replacement password can sign in');
    $replacementHash = $pdo->query("SELECT password_hash FROM users WHERE id = $userId")->fetchColumn();
    check($reset($username, $code, 'synthetic-recovery-replayed')[0] === 401
        && $replacementHash === $pdo->query("SELECT password_hash FROM users WHERE id = $userId")->fetchColumn(),
        'a consumed recovery code cannot replace the password again');

    [$expiredUserId, $expiredName] = $createUser('expired');
    [$expiredResetId, $expiredCode] = $seedCode($expiredUserId, true);
    $expiredHash = $pdo->query("SELECT password_hash FROM users WHERE id = $expiredUserId")->fetchColumn();
    check($reset($expiredName, $expiredCode, 'synthetic-recovery-replacement')[0] === 401
        && $expiredHash === $pdo->query("SELECT password_hash FROM users WHERE id = $expiredUserId")->fetchColumn()
        && $pdo->query("SELECT used_at FROM password_resets WHERE id = $expiredResetId")->fetchColumn() === null,
        'expired recovery code cannot alter credentials or consume unrelated evidence');

    [$inactiveId, $inactiveName] = $createUser('inactive');
    [$inactiveResetId, $inactiveCode] = $seedCode($inactiveId);
    $inactiveHash = $pdo->query("SELECT password_hash FROM users WHERE id = $inactiveId")->fetchColumn();
    $pdo->exec("UPDATE users SET is_active = 0 WHERE id = $inactiveId");
    check($reset($inactiveName, $inactiveCode, 'synthetic-recovery-replacement')[0] === 401
        && $inactiveHash === $pdo->query("SELECT password_hash FROM users WHERE id = $inactiveId")->fetchColumn()
        && $pdo->query("SELECT used_at FROM password_resets WHERE id = $inactiveResetId")->fetchColumn() === null,
        'inactive-account recovery code cannot alter credentials');
}
