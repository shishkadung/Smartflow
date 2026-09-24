<?php
// GET /dev-seed-demo-users.php
//
// Seeds Capstone team accounts (replaces old fictional demo names when used
// after /dev-replace-team-users.php). Password for all: `smartflow123`.
// Idempotent: existing usernames are left untouched.
//
// IMPORTANT: Disable or delete this file before deploying to production.

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';
require_once __DIR__ . '/users-helper.php';

smartflow_dev_localhost_or_admin($pdo);
smartflow_ensure_users_email_column($pdo);
smartflow_ensure_users_active_column($pdo);

$defaultPassword = 'smartflow123';
$hash = password_hash($defaultPassword, PASSWORD_DEFAULT);

// One DB user = one office + one role. Neil has multiple accounts for ACC/MAY × roles.
$demoUsers = [
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
$skipped = [];

foreach ($demoUsers as $u) {
    $stmtOffice = $pdo->prepare('SELECT id FROM offices WHERE code = :code LIMIT 1');
    $stmtOffice->execute([':code' => $u['office_code']]);
    $office = $stmtOffice->fetch();
    if (!$office) {
        $skipped[] = "{$u['username']} (office {$u['office_code']} missing)";
        continue;
    }

    $stmtCheck = $pdo->prepare('SELECT id FROM users WHERE username = :u LIMIT 1');
    $stmtCheck->execute([':u' => $u['username']]);
    if ($stmtCheck->fetch()) {
        $skipped[] = "{$u['username']} (already exists)";
        continue;
    }

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
    $created[] = $u['username'];
}

json_response([
    'success' => true,
    'message' => 'Team users seeded. Password for all accounts is `smartflow123`.',
    'created' => $created,
    'skipped' => $skipped,
    'accounts' => array_map(static function (array $u): array {
        return [
            'name' => $u['name'],
            'username' => $u['username'],
            'office' => $u['office_code'],
            'role' => $u['role'],
        ];
    }, $demoUsers),
]);
