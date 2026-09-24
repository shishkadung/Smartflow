<?php
// GET /dev-replace-team-users.php
//
// Destructive (localhost only): clears custody data + ALL users, then seeds
// Capstone team accounts. Password: smartflow123
//
// Prefer this once when switching from old fictional demo users to the team.

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';
require_once __DIR__ . '/users-helper.php';

smartflow_dev_localhost_or_admin($pdo);
smartflow_ensure_users_email_column($pdo);
smartflow_ensure_users_active_column($pdo);

$pdo->exec('SET FOREIGN_KEY_CHECKS = 0');

$cleared = [];
foreach ([
    'movements',
    'documents',
    'qr_tokens',
    'audit_logs',
    'password_resets',
    'signup_requests',
    'auth_tokens',
    'document_requests',
    'users',
] as $table) {
    try {
        $pdo->exec("DELETE FROM `$table`");
        $cleared[] = $table;
    } catch (Throwable $e) {
        // Table may not exist on older DBs.
    }
}

$pdo->exec('SET FOREIGN_KEY_CHECKS = 1');

$defaultPassword = 'smartflow123';
$hash = password_hash($defaultPassword, PASSWORD_DEFAULT);

$teamUsers = [
    [
        'name' => 'Basit, Krizandra Josephine L.',
        'username' => 'krizandra.tre',
        'email' => 'krizandra.tre@urbiztondo.gov.ph',
        'office_code' => 'TRE',
        'role' => 'staff',
    ],
    [
        'name' => 'Buenaventura, Angel A.',
        'username' => 'angel.bud',
        'email' => 'angel.bud@urbiztondo.gov.ph',
        'office_code' => 'BUD',
        'role' => 'staff',
    ],
    [
        'name' => 'Fallarcuna, Rainier B.',
        'username' => 'rainier.hr',
        'email' => 'rainier.hr@urbiztondo.gov.ph',
        'office_code' => 'HR',
        'role' => 'staff',
    ],
    [
        'name' => 'Fernandez, Kristofer Cyle',
        'username' => 'kristofer.eng',
        'email' => 'kristofer.eng@urbiztondo.gov.ph',
        'office_code' => 'ENG',
        'role' => 'staff',
    ],
    [
        'name' => 'Pascua, Neil John A.',
        'username' => 'neil.admin',
        'email' => 'neil.admin@urbiztondo.gov.ph',
        'office_code' => 'ACC',
        'role' => 'admin',
    ],
    [
        'name' => 'Pascua, Neil John A.',
        'username' => 'neil.acc.staff',
        'email' => 'neil.acc.staff@urbiztondo.gov.ph',
        'office_code' => 'ACC',
        'role' => 'staff',
    ],
    [
        'name' => 'Pascua, Neil John A.',
        'username' => 'neil.acc.head',
        'email' => 'neil.acc.head@urbiztondo.gov.ph',
        'office_code' => 'ACC',
        'role' => 'head',
    ],
    [
        'name' => 'Pascua, Neil John A.',
        'username' => 'neil.may.staff',
        'email' => 'neil.may.staff@urbiztondo.gov.ph',
        'office_code' => 'MAY',
        'role' => 'staff',
    ],
    [
        'name' => 'Pascua, Neil John A.',
        'username' => 'neil.may.head',
        'email' => 'neil.may.head@urbiztondo.gov.ph',
        'office_code' => 'MAY',
        'role' => 'head',
    ],
    [
        'name' => 'Pascua, Neil John A.',
        'username' => 'neil.eng.head',
        'email' => 'neil.eng.head@urbiztondo.gov.ph',
        'office_code' => 'ENG',
        'role' => 'head',
    ],
    [
        'name' => 'Pascua, Neil John A.',
        'username' => 'neil.hr.head',
        'email' => 'neil.hr.head@urbiztondo.gov.ph',
        'office_code' => 'HR',
        'role' => 'head',
    ],
    [
        'name' => 'Pascua, Neil John A.',
        'username' => 'neil.bud.head',
        'email' => 'neil.bud.head@urbiztondo.gov.ph',
        'office_code' => 'BUD',
        'role' => 'head',
    ],
    [
        'name' => 'Pascua, Neil John A.',
        'username' => 'neil.tre.head',
        'email' => 'neil.tre.head@urbiztondo.gov.ph',
        'office_code' => 'TRE',
        'role' => 'head',
    ],
];

$created = [];
$errors = [];

foreach ($teamUsers as $u) {
    $stmtOffice = $pdo->prepare('SELECT id FROM offices WHERE code = :code LIMIT 1');
    $stmtOffice->execute([':code' => $u['office_code']]);
    $office = $stmtOffice->fetch();
    if (!$office) {
        $errors[] = "{$u['username']}: office {$u['office_code']} missing";
        continue;
    }

    try {
        $stmt = $pdo->prepare('
            INSERT INTO users (name, username, email, password_hash, office_id, role, is_active)
            VALUES (:name, :username, :email, :hash, :office_id, :role, 1)
        ');
        $stmt->execute([
            ':name'      => $u['name'],
            ':username'  => $u['username'],
            ':email'     => $u['email'],
            ':hash'      => $hash,
            ':office_id' => (int)$office['id'],
            ':role'      => $u['role'],
        ]);
        $created[] = [
            'username' => $u['username'],
            'name' => $u['name'],
            'office' => $u['office_code'],
            'role' => $u['role'],
        ];
    } catch (Throwable $e) {
        $errors[] = $u['username'] . ': ' . $e->getMessage();
    }
}

json_response([
    'success' => count($errors) === 0,
    'message' => 'Old users removed. Capstone team accounts installed. Password: smartflow123',
    'cleared_tables' => $cleared,
    'created' => $created,
    'errors' => $errors,
    'dv_demo_logins' => [
        'ENG staff' => 'kristofer.eng',
        'BUD staff' => 'angel.bud',
        'ACC staff' => 'neil.acc.staff',
        'TRE staff' => 'krizandra.tre',
        'MAY staff' => 'neil.may.staff',
        'Admin / COA' => 'neil.admin',
    ],
]);
