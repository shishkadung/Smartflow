<?php
declare(strict_types=1);
// Queue endpoints must read thresholds and schema state once per request, not once per queue row,
// and a saved time limit must still be visible to the very next request.
require __DIR__ . '/stabilization-test-helper.php';
$f = new SmartflowStabilizationFixture();
$db = $f->db;
$statements = function () use ($db): int {
    $row = $db->query("SHOW GLOBAL STATUS LIKE 'Questions'")->fetch(PDO::FETCH_NUM);
    return (int)$row[1];
};
try {
    $f->user(701, 'memory_staff', 4); $f->user(702, 'memory_head', 4, 'head'); $f->user(703, 'memory_admin', 4, 'admin');
    $f->startServers();
    $head = $f->login('memory_head'); $admin = $f->login('memory_admin'); $staff = $f->login('memory_staff');

    // 120 Disbursement Vouchers received at Accounting 15 hours ago: inside the default 48 h limit, outside a 10 h limit.
    $db->beginTransaction();
    $doc = $db->prepare('INSERT INTO documents(id,title,type,origin_office_id,created_by) VALUES(?,?,?,?,?)');
    $mov = $db->prepare('INSERT INTO movements(document_id,office_id,status,user_id,scanned_at) VALUES(?,?,?,?,DATE_SUB(NOW(),INTERVAL 15 HOUR))');
    for ($i = 1; $i <= 120; $i++) {
        $id = sprintf('DOC-1950-%06d', $i);
        $doc->execute([$id, "Synthetic memory check $i", 'Disbursement Voucher', 4, 701]);
        $mov->execute([$id, 4, 'IN', 701]);
    }
    $db->commit();
    $db->query('ANALYZE TABLE movements, documents, offices, users, processing_thresholds')->fetchAll();
    $f->call('head-dashboard.php?office_id=4', $head);   // warm-up: runtime schema checks happen on the first request of a process

    $before = $statements();
    [$status, $body] = $f->call('head-dashboard.php?office_id=4', $head);
    $used = $statements() - $before - 1;                 // minus the status read that closed the window
    $f->check($status === 200 && count($body['queue']) === 120 && $body['stats']['in_office'] === 120 && $body['stats']['overdue'] === 0,
        'head dashboard lists all 120 folders at Accounting within the default limit');
    $f->check($used < 150, "head dashboard for 120 queue rows used $used SQL statements (the old per-row lookups needed over a thousand)");

    $before = $statements();
    [$status, $alerts] = $f->call('alerts-list.php?office_id=4', $staff);
    $usedAlerts = $statements() - $before - 1;
    $f->check($status === 200 && $usedAlerts < 150, "office alerts used $usedAlerts SQL statements for 120 open folders");

    [$status, $saved] = $f->call('admin-thresholds-update.php', $admin, ['office_id' => 4, 'document_type' => 'Disbursement Voucher', 'max_hours' => 10, 'out_unconfirmed_hours' => 8]);
    $f->check($status === 200 && $saved['threshold']['max_hours'] === 10, 'administrator saves a 10 hour Accounting limit');
    [$status, $body] = $f->call('head-dashboard.php?office_id=4', $head);
    $f->check($status === 200 && $body['stats']['overdue'] === 120 && $body['queue'][0]['max_hours'] === 10,
        'the next request applies the saved 10 hour limit to every folder (no stale rule)');
    [$status, $alerts] = $f->call('alerts-list.php?office_id=4', $staff);
    $f->check($status === 200 && count($alerts['alerts'] ?? []) === 120, 'the next alerts request reports all 120 folders as past the saved limit');

    $db->exec("UPDATE processing_thresholds SET is_active=0 WHERE office_id=4 AND document_type='Disbursement Voucher'");
    [$status, $body] = $f->call('head-dashboard.php?office_id=4', $head);
    $f->check($status === 200 && $body['queue'][0]['max_hours'] === 48 && $body['stats']['overdue'] === 0, 'a deactivated rule falls back to the default limit on the next request');
    $f->assertCopies();
} finally {
    $f->close();
}
echo "{$f->checks} threshold-memory checks passed\n";
