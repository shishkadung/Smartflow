<?php
// GET /dev-update-user-emails.php
// Bulk update Capstone team user emails

require __DIR__ . '/config.php';
require __DIR__ . '/dev-block.php';

smartflow_dev_localhost_or_admin($pdo);

$emailMapping = [
    'krizandra.tre'   => 'krizandra.tre@urbiztondo.gov.ph',
    'angel.bud'       => 'angel.bud@urbiztondo.gov.ph',
    'rainier.hr'      => 'rainier.hr@urbiztondo.gov.ph',
    'kristofer.eng'   => 'kristofer.eng@urbiztondo.gov.ph',
    'neil.admin'      => 'neil.admin@urbiztondo.gov.ph',
    'neil.acc.staff'  => 'neil.acc.staff@urbiztondo.gov.ph',
    'neil.acc.head'   => 'neil.acc.head@urbiztondo.gov.ph',
    'neil.may.staff'  => 'neil.may.staff@urbiztondo.gov.ph',
    'neil.may.head'   => 'neil.may.head@urbiztondo.gov.ph',
    'neil.eng.head'   => 'neil.eng.head@urbiztondo.gov.ph',
    'neil.hr.head'    => 'neil.hr.head@urbiztondo.gov.ph',
    'neil.bud.head'   => 'neil.bud.head@urbiztondo.gov.ph',
    'neil.tre.head'   => 'neil.tre.head@urbiztondo.gov.ph',
];

$updated = [];
$skipped = [];

foreach ($emailMapping as $username => $email) {
    $stmt = $pdo->prepare('SELECT id FROM users WHERE username = :username LIMIT 1');
    $stmt->execute([':username' => $username]);
    $user = $stmt->fetch();

    if (!$user) {
        $skipped[] = "$username (not found)";
        continue;
    }

    $update = $pdo->prepare('UPDATE users SET email = :email WHERE username = :username');
    $update->execute([
        ':email' => $email,
        ':username' => $username,
    ]);

    $updated[] = "$username → $email";
}

json_response([
    'success' => true,
    'message' => 'Team user emails updated',
    'updated' => $updated,
    'skipped' => $skipped,
]);
