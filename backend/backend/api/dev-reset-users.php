<?php
// GET /dev-reset-users.php
// Keep only Capstone team usernames; delete everyone else; reset passwords.

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';
require_once __DIR__ . '/users-helper.php';

smartflow_dev_localhost_or_admin($pdo);
smartflow_ensure_users_email_column($pdo);

$keepUsers = [
    'krizandra.tre',
    'angel.bud',
    'rainier.hr',
    'kristofer.eng',
    'neil.admin',
    'neil.acc.staff',
    'neil.acc.head',
    'neil.may.staff',
    'neil.may.head',
    'neil.eng.head',
    'neil.hr.head',
    'neil.bud.head',
    'neil.tre.head',
];

$emailByUser = [
    'krizandra.tre' => 'krizandra.tre@urbiztondo.gov.ph',
    'angel.bud' => 'angel.bud@urbiztondo.gov.ph',
    'rainier.hr' => 'rainier.hr@urbiztondo.gov.ph',
    'kristofer.eng' => 'kristofer.eng@urbiztondo.gov.ph',
    'neil.admin' => 'neil.admin@urbiztondo.gov.ph',
    'neil.acc.staff' => 'neil.acc.staff@urbiztondo.gov.ph',
    'neil.acc.head' => 'neil.acc.head@urbiztondo.gov.ph',
    'neil.may.staff' => 'neil.may.staff@urbiztondo.gov.ph',
    'neil.may.head' => 'neil.may.head@urbiztondo.gov.ph',
    'neil.eng.head' => 'neil.eng.head@urbiztondo.gov.ph',
    'neil.hr.head' => 'neil.hr.head@urbiztondo.gov.ph',
    'neil.bud.head' => 'neil.bud.head@urbiztondo.gov.ph',
    'neil.tre.head' => 'neil.tre.head@urbiztondo.gov.ph',
];

$stmt = $pdo->query('SELECT id, username, name FROM users ORDER BY id');
$allUsers = $stmt->fetchAll(PDO::FETCH_ASSOC);

$deletedUsers = [];
$keptUsers = [];
$defaultPass = password_hash('smartflow123', PASSWORD_DEFAULT);

foreach ($allUsers as $user) {
    if (in_array($user['username'], $keepUsers, true)) {
        $keptUsers[] = $user['username'];
        $email = $emailByUser[$user['username']] ?? null;
        $update = $pdo->prepare('UPDATE users SET password_hash = :pass, email = :email, is_active = 1 WHERE id = :id');
        $update->execute([
            ':pass' => $defaultPass,
            ':email' => $email,
            ':id' => $user['id'],
        ]);
    } else {
        $deletedUsers[] = $user['username'];
        try {
            $pdo->prepare('DELETE FROM auth_tokens WHERE user_id = :id')->execute([':id' => $user['id']]);
        } catch (Throwable $e) {
            // ignore
        }
        try {
            $pdo->prepare('DELETE FROM password_resets WHERE user_id = :id')->execute([':id' => $user['id']]);
        } catch (Throwable $e) {
            // ignore
        }
        $pdo->prepare('DELETE FROM users WHERE id = :id')->execute([':id' => $user['id']]);
    }
}

json_response([
    'success' => true,
    'message' => 'Users reset to Capstone team accounts.',
    'kept_users' => $keptUsers,
    'deleted_users' => $deletedUsers,
    'note' => 'Password for kept accounts: smartflow123. If team accounts are missing, open /dev-replace-team-users.php or /dev-seed-demo-users.php',
]);
