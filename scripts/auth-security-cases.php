<?php
/** Functional auth regressions. Called only by the disposable API harness. */
function smartflow_test_auth_security(PDO $pdo, array $tokens): void
{
    global $base;
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Auth cases require the disposable harness database');
    }
    $raw = static function (string $path, array $headers = [], ?array $body = null) use ($base): array {
        $curl = curl_init("$base/$path");
        $responseHeaders = '';
        curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10,
            CURLOPT_HTTPHEADER => array_merge(['Content-Type: application/json'], $headers),
            CURLOPT_HEADERFUNCTION => static function ($handle, $line) use (&$responseHeaders) { $responseHeaders .= $line; return strlen($line); }]);
        if ($body !== null) curl_setopt_array($curl, [CURLOPT_POST => true, CURLOPT_POSTFIELDS => json_encode($body, JSON_THROW_ON_ERROR)]);
        $text = curl_exec($curl);
        if ($text === false) throw new RuntimeException(curl_error($curl));
        $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
        return [$status, $text, $responseHeaders];
    };
    // All former URL/body aliases are rejected; CGI-compatible headers remain valid.
    foreach (['token', 'access_token'] as $alias) {
        check(api('auth-session.php?' . http_build_query([$alias => $tokens['eng']]))[0] === 401,
            "$alias query cannot authenticate a session");
    }
    check(api('users-change-password.php', null, ['access_token' => $tokens['admin']])[0] === 401,
        'JSON-body credential cannot authenticate a session');
    foreach (['X-Authorization: Bearer ', 'X-Smartflow-Token: '] as $header) {
        check($raw('auth-session.php', [$header . $tokens['eng']])[0] === 200,
            'header fallback authenticates when CGI drops Authorization');
    }
    [$http, $folder] = register('eng', 1, 'Others: Auth label');
    check($http === 201, 'print-label fixture registers normally');
    $labelPath = 'qr-label.php?' . http_build_query(['id' => $folder['document']['id']]);
    check($raw($labelPath . '&token=' . rawurlencode($tokens['eng']))[0] === 401,
        'printable QR label rejects URL bearer credentials');
    [$http, $html, $headers] = $raw($labelPath, ['Authorization: Bearer ' . $tokens['eng']]);
    check($http === 200 && str_contains($html, 'QR Label') && !str_contains($html, $tokens['eng'])
        && stripos($headers, 'Cache-Control: no-store') !== false,
        'authenticated printable label has no session token and is not cached');

    $suffix = bin2hex(random_bytes(4));
    $signup = ['full_name' => 'Private Applicant', 'username' => "privacy_$suffix",
        'email' => "privacy_$suffix@example.test", 'password' => 'original-password',
        'office_id' => 1, 'requested_role' => 'staff'];
    [$http, $created] = api('auth-signup.php', null, $signup);
    check($http === 201 && preg_match('/^[a-f0-9]{64}$/D', $created['status_key'] ?? ''),
        'signup issues a private applicant status key');
    $request = $created['request']; $key = $created['status_key'];
    $storedHash = $pdo->query('SELECT status_key_hash FROM signup_requests WHERE id=' . (int)$request['id'])->fetchColumn();
    check($storedHash === hash('sha256', $key) && $storedHash !== $key,
        'signup stores only the status-key hash');
    check(api('signup-status.php?' . http_build_query(['code' => $request['request_code']]))[0] === 405,
        'signup status has no public GET enumeration route');
    [$unknownHttp, $unknown] = api('signup-status.php', null, ['username' => 'absent_' . $suffix, 'status_key' => str_repeat('a', 64)]);
    foreach ([['username' => $signup['username']], ['request_code' => $request['request_code']],
        ['request_code' => $request['request_code'], 'status_key' => str_repeat('a', 64)],
        ['username' => $signup['username'], 'password' => $signup['password']]] as $proof) {
        [$deniedHttp, $denied] = api('signup-status.php', null, $proof);
        check($deniedHttp === 404 && $unknownHttp === 404 && $denied === $unknown,
            'public identifiers or wrong proof reveal no applicant details');
    }
    [$http, $status] = api('signup-status.php', null, ['request_code' => $request['request_code'], 'status_key' => $key]);
    check($http === 200 && $status['request']['status'] === 'pending'
        && !isset($status['request']['email'], $status['request']['full_name'], $status['request']['password_hash']),
        'owner status proof returns only needed status/account fields');
    check(api('auth-login.php', null, ['username' => $signup['username'], 'password' => 'wrong-password'])[0] === 401,
        'wrong password does not disclose a pending applicant login');
    check(api('auth-login.php', null, ['username' => $signup['username'], 'password' => $signup['password']])[0] === 403,
        'actual applicant retains pending-approval login guidance');
    check(api('signup-approve.php', $tokens['admin'], ['request_id' => $request['id'], 'action' => 'reject'])[0] === 200,
        'admin can reject applicant fixture');
    [$http, $reapplied] = api('auth-signup.php', null, $signup);
    check($http === 201 && $reapplied['status_key'] !== $key
        && api('signup-status.php', null, ['request_code' => $request['request_code'], 'status_key' => $key])[0] === 404,
        'reapplication rotates ownership proof and rejects the old key');
    check(api('signup-status.php', null, ['request_code' => $request['request_code'], 'status_key' => $reapplied['status_key']])[0] === 200,
        'reapplication owner retains status access');

    // Legacy applicants get no public-code migration: supply their password afresh.
    $legacyUser = 'legacy_' . $suffix;
    $pdo->prepare('INSERT INTO signup_requests (request_code,full_name,username,email,password_hash,office_id,requested_role,status)
        VALUES (?,"Legacy Applicant",?,?,?,1,"staff","pending")')->execute([
            'LEGACY-' . $suffix, $legacyUser, "$legacyUser@example.test", password_hash('legacy-password', PASSWORD_DEFAULT)]);
    $legacyId = (int)$pdo->lastInsertId();
    check(api('signup-status.php', null, ['username' => $legacyUser, 'password' => 'wrong-password'])[0] === 404,
        'legacy applicant status rejects an incorrect password');
    check(api('signup-status.php', null, ['username' => $legacyUser, 'password' => 'legacy-password'])[0] === 200,
        'legacy applicant can verify a pending request with fresh credentials');
    check(api('signup-approve.php', $tokens['admin'], ['request_id' => $legacyId, 'action' => 'approve'])[0] === 200,
        'legacy applicant approval remains supported');
    $userId = (int)$pdo->query("SELECT id FROM users WHERE username='$legacyUser'")->fetchColumn();
    check((int)$pdo->query("SELECT approved_user_id FROM signup_requests WHERE id=$legacyId")->fetchColumn() === $userId,
        'approval records an immutable applicant-to-user binding');
    check(api('signup-approve.php', $tokens['admin'], ['request_id' => $legacyId, 'action' => 'approve'])[0] === 404,
        'repeated stale approval cannot create another account or replace its binding');
    $login = static fn(string $password): array => api('auth-login.php', null, ['username' => $legacyUser, 'password' => $password]);
    [$http, $first] = $login('legacy-password'); [$secondHttp, $second] = $login('legacy-password');
    check($http === 200 && $secondHttp === 200 && $first['token'] !== $second['token'],
        'two legitimate devices get separate server sessions');
    check(api('auth-logout.php', $first['token'], [])[0] === 200
        && api('auth-session.php', $first['token'])[0] === 401
        && api('auth-session.php', $second['token'])[0] === 200,
        'logout revokes only the presented session on the server');
    check(api('auth-logout.php', $first['token'], [])[0] === 200, 'completed logout can safely be repeated');
    [$http, $third] = $login('legacy-password');
    $oldHash = $pdo->query("SELECT password_hash FROM users WHERE id=$userId")->fetchColumn();
    $pdo->exec("CREATE TRIGGER test_auth_revoke_failure BEFORE UPDATE ON auth_tokens FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Injected auth revoke failure'");
    try {
        [$http] = api('users-change-password.php', $second['token'], ['current_password' => 'legacy-password', 'new_password' => 'changed-password']);
        check($http === 500 && $oldHash === $pdo->query("SELECT password_hash FROM users WHERE id=$userId")->fetchColumn(),
            'revocation failure rolls back the password change');
    } finally { $pdo->exec('DROP TRIGGER test_auth_revoke_failure'); }
    check(api('auth-session.php', $second['token'])[0] === 200, 'failed atomic password change retains the current session');
    [$http, $changed] = api('users-change-password.php', $second['token'], ['current_password' => 'legacy-password', 'new_password' => 'changed-password']);
    check($http === 200 && ($changed['reauthenticate'] ?? false)
        && api('auth-session.php', $second['token'])[0] === 401
        && api('auth-session.php', $third['token'])[0] === 401,
        'ordinary password change atomically revokes every existing device session');
    check($login('legacy-password')[0] === 401 && $login('changed-password')[0] === 200,
        'old credentials fail and the changed password signs in');
    check(api('signup-status.php', null, ['username' => $legacyUser, 'password' => 'legacy-password'])[0] === 404
        && api('signup-status.php', null, ['username' => $legacyUser, 'password' => 'changed-password'])[0] === 200,
        'approved legacy status validates the current password, not the stale application hash');
    [$http, $active] = $login('changed-password');
    check(api('users-set-active.php', $tokens['admin'], ['user_id' => $userId, 'active' => false])[0] === 200
        && api('users-set-active.php', $tokens['admin'], ['user_id' => $userId, 'active' => true])[0] === 200
        && api('auth-session.php', $active['token'])[0] === 401,
        'deactivation revokes sessions permanently even after reactivation');

    // Account names are mutable. A new account owning the old name is never the applicant.
    [$http, $renamingOwner] = $login('changed-password');
    $renamedUser = 'renamed_' . $suffix;
    check(api('users-profile-update.php', $renamingOwner['token'], ['name' => 'Renamed Applicant',
        'username' => $renamedUser, 'email' => "$legacyUser@example.test"])[0] === 200,
        'legacy approved owner can legitimately rename their account');
    $pdo->prepare('INSERT INTO users (name,username,password_hash,office_id,role) VALUES (?,?,?,1,"staff")')
        ->execute(['Different Account', $legacyUser, password_hash('other-password', PASSWORD_DEFAULT)]);
    [$http] = api('signup-status.php', null, ['request_code' => 'LEGACY-' . $suffix,
        'username' => $legacyUser, 'password' => 'other-password']);
    check($http === 404, 'reassigned old username cannot expose the original applicant status');
    [$http, $ownerStatus] = api('signup-status.php', null, ['request_code' => 'LEGACY-' . $suffix,
        'username' => $renamedUser, 'password' => 'changed-password']);
    check($http === 200 && $ownerStatus['request']['username'] === $renamedUser,
        'bound applicant retains status access with request code and current credentials after rename');
    $pdo->prepare('INSERT INTO signup_requests (request_code,full_name,username,password_hash,office_id,requested_role,status)
        VALUES (?,"Historic Applicant",?,?,1,"staff","approved")')
        ->execute(['UNBOUND-' . $suffix, $renamedUser, password_hash('changed-password', PASSWORD_DEFAULT)]);
    check(api('signup-status.php', null, ['request_code' => 'UNBOUND-' . $suffix,
        'username' => $renamedUser, 'password' => 'changed-password'])[0] === 404,
        'unbound historic approved requests fail closed without username-based ownership guesses');
}
