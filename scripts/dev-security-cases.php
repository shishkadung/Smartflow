<?php
/** Called only by the guarded disposable API harness; no mail is sent. */
function smartflow_test_dev_security(PDO $pdo): void
{
    $database = (string)$pdo->query('SELECT DATABASE()')->fetchColumn();
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', $database)) {
        throw new RuntimeException('Developer-security cases require the disposable test database');
    }
    $username = 'recovery_guard_' . bin2hex(random_bytes(4));
    $insert = $pdo->prepare('INSERT INTO users (name, username, password_hash, office_id, role, email) VALUES (?, ?, ?, 1, "staff", NULL)');
    $insert->execute(['Synthetic recovery fixture', $username, password_hash('test-password', PASSWORD_DEFAULT)]);
    $userId = (int)$pdo->lastInsertId();
    $expected = ['success' => true, 'message' => 'If an account exists with that username, a password reset code has been generated.'];
    foreach ([$username, 'absent_' . bin2hex(random_bytes(4))] as $name) {
        [$http, $response] = api('auth-forgot-password.php', null, ['username' => $name]);
        check($http === 200 && $response === $expected, 'recovery remains generic with developer mode explicitly enabled');
    }
    check((int)$pdo->query("SELECT COUNT(*) FROM password_resets WHERE user_id = $userId AND used_at IS NULL")->fetchColumn() === 1,
        'private reset evidence is still created without exposing the code');
    $pdo->prepare('UPDATE users SET is_active = 0 WHERE id = ?')->execute([$userId]);
    [$http, $response] = api('auth-forgot-password.php', null, ['username' => $username]);
    check($http === 200 && $response === $expected, 'inactive recovery has the same public shape');
    foreach (['dev-reset-system.php', 'dev-purge-demo-documents.php?all=1', 'dev-api-health.php', 'users-email-migration.php'] as $path) {
        [$http, $response] = api($path);
        check($http === 404 && $response === ['success' => false, 'message' => 'Not found'],
            'plain HTTP hosting cannot execute maintenance: ' . strtok($path, '?'));
    }
}
