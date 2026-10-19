<?php
// Actual delayed privileged requests; only generated disposable records are changed.
declare(strict_types=1);
require __DIR__ . '/stabilization-test-helper.php';
$fixture = new SmartflowStabilizationFixture();
$db = $fixture->db;
$lock = null;
$pending = null;
try {
    $fixture->user(101, 'admin_a', 4, 'admin');
    $fixture->user(102, 'admin_b', 4, 'admin');
    $fixture->user(103, 'staff', 4);
    $fixture->startServers(2);
    $a = $fixture->login('admin_a', 1);
    $b = $fixture->login('admin_b', 1);
    $staff = $fixture->login('staff', 1);
    $threshold = ['office_id' => 2, 'document_type' => 'Others: Boundary test', 'max_hours' => 36, 'out_unconfirmed_hours' => 12];
    $makeRequest = static function () use ($db): array {
        $name = 'applicant_' . bin2hex(random_bytes(5));
        $db->prepare('INSERT INTO signup_requests(request_code,full_name,username,email,password_hash,office_id,requested_role,status) VALUES(?,?,?,?,?,4,"staff","pending")')
            ->execute(['TEST-' . bin2hex(random_bytes(5)), 'Synthetic Applicant', $name, $name . '@example.test', password_hash('synthetic-only-password', PASSWORD_DEFAULT)]);
        return [(int)$db->lastInsertId(), $name];
    };
    foreach (['approve', 'reject'] as $action) {
        [$id, $name] = $makeRequest();
        $body = ['request_id' => $id, 'action' => $action];
        $fixture->check($fixture->call('signup-approve.php', $staff, $body, 1)[0] === 403, "staff cannot $action a signup");
        $fixture->check($fixture->call('signup-approve.php', $a, $body, 1)[0] === 200
            && $db->query('SELECT status FROM signup_requests WHERE id=' . $id)->fetchColumn() === ($action === 'approve' ? 'approved' : 'rejected'),
            "active administrator can $action a signup");
        if ($action === 'approve') $fixture->check($fixture->call('auth-session.php', $fixture->login($name, 1), server: 1)[0] === 200,
            'valid approval creates a usable synthetic account');
    }
    $fixture->check($fixture->call('admin-thresholds-update.php', $staff, $threshold, 1)[0] === 403, 'staff cannot change time limits');
    $fixture->check($fixture->call('admin-thresholds-update.php', $a, $threshold, 1)[0] === 200, 'active administrator can create time limits');
    $omitted = $threshold; unset($omitted['out_unconfirmed_hours']);
    $fixture->check($fixture->call('admin-thresholds-update.php', $a, $omitted, 1)[0] === 200
        && (int)$db->query('SELECT out_unconfirmed_hours FROM processing_thresholds WHERE document_type="Others: Boundary test"')->fetchColumn() === 12,
        'valid update with an omitted OUT limit preserves its saved value');
    $lock = $fixture->connect();
    foreach (['approve', 'reject', 'threshold'] as $action) {
        foreach (['deactivation', 'logout', 'expiry'] as $revocation) {
            $a = $fixture->login('admin_a', 1);
            [$id, $name] = $makeRequest();
            $path = $action === 'threshold' ? 'admin-thresholds-update.php' : 'signup-approve.php';
            $body = $action === 'threshold' ? array_replace($threshold, ['max_hours' => 37]) : ['request_id' => $id, 'action' => $action];
            $auditBefore = (int)$db->query("SELECT COUNT(*) FROM audit_logs WHERE event_type IN ('signup.approve','signup.reject','threshold.update')")->fetchColumn();
            $usersBefore = (int)$db->query('SELECT COUNT(*) FROM users')->fetchColumn();
            $lock->beginTransaction();
            if ($action === 'threshold') $lock->query('SELECT id FROM offices WHERE id=2 FOR UPDATE')->fetchColumn();
            else $lock->query('SELECT id FROM signup_requests WHERE id=' . $id . ' FOR UPDATE')->fetchColumn();
            $pending = $fixture->begin($path, $a, $body);
            $fixture->waitForLock($pending, $action === 'threshold' ? 'processing_thresholds' : 'signup_requests');
            $fixture->check(true, "$action/$revocation is observed waiting on its actual resource row");
            if ($revocation === 'deactivation') {
                $fixture->check($fixture->call('users-set-active.php', $b, ['user_id' => 101, 'active' => false], 1)[0] === 200,
                    "$action waiting caller deactivation commits through the real endpoint");
            } elseif ($revocation === 'logout') {
                $fixture->check($fixture->call('auth-logout.php', $a, [], 1)[0] === 200, "$action waiting session logs out through the real endpoint");
            } else {
                $db->prepare('UPDATE auth_tokens SET expires_at=DATE_SUB(NOW(), INTERVAL 1 SECOND) WHERE token_hash=?')->execute([hash('sha256', $a)]);
                $fixture->check(true, "$action waiting synthetic session expires");
            }
            $fixture->check($fixture->call('auth-session.php', $a, server: 1)[0] === 401, "$action/$revocation session is invalid before releasing the resource lock");
            $lock->commit();
            [$status] = $fixture->finish($pending); $pending = null;
            $fixture->check($status === 401, "$action/$revocation delayed commit rejects the ended session");
            $request = $db->query('SELECT status,approved_by,approved_at,approved_user_id FROM signup_requests WHERE id=' . $id)->fetch();
            $fixture->check($request === ['status' => 'pending', 'approved_by' => null, 'approved_at' => null, 'approved_user_id' => null]
                && (int)$db->query('SELECT COUNT(*) FROM users')->fetchColumn() === $usersBefore
                && (int)$db->query('SELECT max_hours FROM processing_thresholds WHERE document_type="Others: Boundary test"')->fetchColumn() === 36,
                "$action/$revocation rolls back request evidence/account creation/time limits");
            $fixture->check((int)$db->query("SELECT COUNT(*) FROM audit_logs WHERE event_type IN ('signup.approve','signup.reject','threshold.update')")->fetchColumn() === $auditBefore,
                "$action/$revocation records no successful privileged action audit");
            $fixture->check($fixture->call($path, $a, $body, 1)[0] === 401, "$action/$revocation fresh retry with the old session stays denied");
            if ($revocation === 'deactivation') {
                $fixture->check($fixture->call('users-set-active.php', $b, ['user_id' => 101, 'active' => true], 1)[0] === 200
                    && $fixture->call('auth-session.php', $a, server: 1)[0] === 401,
                    "$action reactivation does not revive the revoked login");
            }
        }
    }
    // Resource waits alone must not reject an administrator whose reviewed session remains valid.
    $a = $fixture->login('admin_a', 1);
    foreach (['approve', 'reject', 'threshold'] as $action) {
        [$id, $name] = $makeRequest();
        $body = $action === 'threshold' ? array_replace($threshold, ['max_hours' => 38]) : ['request_id' => $id, 'action' => $action];
        $lock->beginTransaction();
        if ($action === 'threshold') $lock->query('SELECT id FROM offices WHERE id=2 FOR UPDATE')->fetchColumn();
        else $lock->query('SELECT id FROM signup_requests WHERE id=' . $id . ' FOR UPDATE')->fetchColumn();
        $pending = $fixture->begin($action === 'threshold' ? 'admin-thresholds-update.php' : 'signup-approve.php', $a, $body);
        $fixture->waitForLock($pending, $action === 'threshold' ? 'processing_thresholds' : 'signup_requests');
        $lock->commit(); [$status] = $fixture->finish($pending); $pending = null;
        $fixture->check($status === 200 && ($action === 'threshold'
            ? (int)$db->query('SELECT max_hours FROM processing_thresholds WHERE document_type="Others: Boundary test"')->fetchColumn() === 38
            : $db->query('SELECT status FROM signup_requests WHERE id=' . $id)->fetchColumn() === ($action === 'approve' ? 'approved' : 'rejected')),
            "$action succeeds after the same resource wait when the original administrator/session remains valid");
    }
    // Force a real resource -> caller row deadlock. Weight the controlling
    // transaction so InnoDB rolls back the smaller copied-endpoint transaction.
    $db->exec('CREATE TABLE stabilization_deadlock_weight (id INT PRIMARY KEY, value INT NOT NULL) ENGINE=InnoDB');
    for ($id = 1; $id <= 50; $id++) $db->exec("INSERT INTO stabilization_deadlock_weight VALUES ($id,0)");
    foreach (['approve', 'reject', 'threshold'] as $action) {
        [$id, $name] = $makeRequest();
        $body = $action === 'threshold' ? array_replace($threshold, ['max_hours' => 39]) : ['request_id' => $id, 'action' => $action];
        $usersBefore = (int)$db->query('SELECT COUNT(*) FROM users')->fetchColumn();
        $auditBefore = (int)$db->query("SELECT COUNT(*) FROM audit_logs WHERE event_type IN ('signup.approve','signup.reject','threshold.update')")->fetchColumn();
        $lock->beginTransaction();
        $lock->exec('UPDATE stabilization_deadlock_weight SET value=value+1');
        $lock->query('SELECT id FROM users WHERE id=101 FOR UPDATE')->fetchColumn();
        $pending = $fixture->begin($action === 'threshold' ? 'admin-thresholds-update.php' : 'signup-approve.php', $a, $body);
        $fixture->waitForLock($pending, 'users');
        if ($action === 'threshold') $lock->query('SELECT id FROM offices WHERE id=2 FOR UPDATE')->fetchColumn();
        else $lock->query('SELECT id FROM signup_requests WHERE id=' . $id . ' FOR UPDATE')->fetchColumn();
        $lock->rollBack();
        [$status, $result] = $fixture->finish($pending); $pending = null;
        $fixture->check($status === 409 && str_contains($result['message'] ?? '', 'Refresh'),
            "$action real lock cycle returns an actionable 409 after InnoDB rolls back the request");
        $fixture->check($db->query('SELECT status FROM signup_requests WHERE id=' . $id)->fetchColumn() === 'pending'
            && (int)$db->query('SELECT COUNT(*) FROM users')->fetchColumn() === $usersBefore
            && (int)$db->query('SELECT max_hours FROM processing_thresholds WHERE document_type="Others: Boundary test"')->fetchColumn() === 38
            && (int)$db->query("SELECT COUNT(*) FROM audit_logs WHERE event_type IN ('signup.approve','signup.reject','threshold.update')")->fetchColumn() === $auditBefore,
            "$action deadlock leaves no partial decision, account, threshold or success audit");
        $fixture->check($fixture->call('auth-session.php', $a, server: 1)[0] === 200,
            "$action transaction conflict preserves the still-valid original login");
    }
    $fixture->assertCopies();
} finally {
    if ($lock?->inTransaction()) $lock->rollBack();
    if ($pending !== null) { [$multi, $curl] = $pending; curl_multi_remove_handle($multi, $curl); curl_close($curl); curl_multi_close($multi); }
    $lock = null;
    $fixture->close();
}
echo "{$fixture->checks} isolated admin/session boundary checks passed\n";
