<?php
// Folder-linked purposes use the same permissions as actual Requests views.
declare(strict_types=1);
require __DIR__ . '/stabilization-test-helper.php';
$fixture = new SmartflowStabilizationFixture();
try {
    $people = [[101, 'requester', 1, 'staff'], [102, 'coworker', 1, 'staff'], [103, 'handler', 4, 'staff'],
        [104, 'unrelated', 2, 'staff'], [105, 'admin', 4, 'admin'], [106, 'treasury', 5, 'staff'],
        [107, 'closer', 5, 'staff'], [108, 'auditor', 4, 'auditor'], [109, 'head', 4, 'head']];
    foreach ($people as [$id, $name, $office, $role]) $fixture->user($id, $name, $office, $role);
    $fixture->startServers();
    $tokens = [];
    foreach ($people as [$id, $name]) $tokens[$name] = $fixture->login($name);
    $fixture->check($fixture->call('document-requests-list.php?view=all', $tokens['admin'])[0] === 200,
        'actual Requests endpoint initializes only the disposable request schema');
    $db = $fixture->db;
    $folder = 'DOC-2001-000001';
    $db->prepare('INSERT INTO documents(id,title,type,origin_office_id,created_by) VALUES (?,"Synthetic scope folder","Others: Scope test",1,101)')->execute([$folder]);
    $db->prepare('INSERT INTO movements(document_id,office_id,status,user_id) VALUES (?,1,"IN",101)')->execute([$folder]);
    $purpose = "Synthetic full purpose with line breaks\n" . str_repeat('Full permitted ticket evidence. ', 30) . "\nEnd of purpose.";
    $tickets = [];
    $purposes = [];
    $insert = $db->prepare('INSERT INTO document_requests(request_code,request_kind,document_category,requested_by,requester_office_id,requester_role,
        handler_office_id,purpose,status,related_document_id,fulfilled_by,fulfilled_office_id) VALUES (?,"access",?,?,1,"staff",?,?,?,?,?,?)');
    foreach ([
        ['own', 101, 4, 'general', 'approved', null, null],
        ['coworker', 102, 3, 'general', 'approved', null, null],
        ['dv_approved', 101, 4, 'disbursement', 'approved', null, null],
        ['dv_tre_snapshot', 101, 4, 'disbursement', 'fulfilled', 107, 5],
        ['legacy_no_office', 101, 4, 'disbursement', 'fulfilled', 107, null],
        ['legacy_no_closer', 101, 4, 'disbursement', 'fulfilled', null, 5],
        ['cancelled', 101, 4, 'general', 'cancelled', null, null],
        ['rejected', 101, 4, 'general', 'rejected', null, null],
        ['dv_non_tre_snapshot', 101, 4, 'disbursement', 'fulfilled', 107, 4],
    ] as [$key, $requester, $handler, $category, $status, $closer, $closedOffice]) {
        $fullPurpose = $purpose . ' ' . $key;
        $insert->execute(['TEST-' . $key, $category, $requester, $handler, $fullPurpose, $status, $folder, $closer, $closedOffice]);
        $id = $tickets[$key] = (int)$db->lastInsertId();
        $purposes[$id] = $fullPurpose;
    }
    $ids = static function (array $rows): array { $values = array_column($rows, 'id'); sort($values); return $values; };
    $expected = static function (array $keys) use ($tickets): array { $values = array_map(static fn(string $key): int => $tickets[$key], $keys); sort($values); return $values; };
    [$status, $before] = $fixture->call('documents-show.php?id=' . $folder, $tokens['treasury']);
    $fixture->check($status === 200 && $ids($before['document']['linked_requests']) === $expected(['dv_approved', 'dv_tre_snapshot']),
        'Treasury reads approved DV and Treasury-closed DV, withholds missing or non-Treasury completion evidence');
    $db->exec('UPDATE users SET office_id=2 WHERE id=107');
    $common = ['own', 'dv_approved', 'dv_tre_snapshot', 'legacy_no_office', 'legacy_no_closer', 'rejected', 'dv_non_tre_snapshot'];
    $matrix = ['requester' => $common, 'coworker' => ['coworker'], 'handler' => $common, 'unrelated' => [],
        'admin' => array_merge($common, ['coworker']), 'treasury' => ['dv_approved', 'dv_tre_snapshot'],
        'closer' => [], 'auditor' => $common, 'head' => $common];
    foreach ($matrix as $who => $keys) {
        [$status, $detail, $raw] = $fixture->call('documents-show.php?id=' . $folder, $tokens[$who]);
        $fixture->check($status === 200 && $detail['document']['id'] === $folder, "$who retains existing authenticated direct-folder lookup");
        $rows = $detail['document']['linked_requests'];
        $fixture->check($ids($rows) === $expected($keys), "$who sees exactly the permitted linked tickets after closer office reassignment");
        $allPurposes = true;
        foreach ($rows as $row) if ($row['purpose'] !== $purposes[$row['id']]) $allPurposes = false;
        foreach ($purposes as $id => $fullPurpose) if (!in_array($id, $ids($rows), true)
            && str_contains($raw, json_encode($fullPurpose, JSON_THROW_ON_ERROR))) $allPurposes = false;
        $fixture->check($allPurposes && !in_array($tickets['cancelled'], $ids($rows), true),
            "$who keeps complete permitted purposes while withholding all other purposes and the cancelled linked ticket");
        $visible = [];
        foreach ($who === 'admin' ? ['all'] : ['inbox', 'outbox'] as $view) {
            [$http, $list] = $fixture->call('document-requests-list.php?view=' . $view . '&page_size=100', $tokens[$who]);
            if ($http !== 200) throw new RuntimeException('Expected existing Requests view denied');
            foreach ($list['requests'] as $request) if ($request['status'] !== 'cancelled' && $request['related_document_id'] === $folder) $visible[$request['id']] = $request;
        }
        $fixture->check($ids(array_values($visible)) === $ids($rows), "$who linked ticket scope agrees with existing Requests inbox/outbox or municipal reads");
        if ($who !== 'admin') $fixture->check($fixture->call('document-requests-list.php?view=all', $tokens[$who])[0] === 403,
            "$who cannot widen a Requests view to municipal access");
    }
    foreach (['requester', 'handler', 'treasury', 'admin', 'auditor'] as $who) {
        $view = $who === 'admin' ? 'all' : ($who === 'requester' ? 'outbox' : 'inbox');
        [$status, $exact] = $fixture->call('document-requests-list.php?view=' . $view . '&id=' . $tickets['dv_tre_snapshot'], $tokens[$who]);
        $fixture->check($status === 200 && $ids($exact['requests']) === [$tickets['dv_tre_snapshot']],
            "$who exact-ticket read preserves approved handler/requester/Treasury/auditor authority");
    }
    foreach (['coworker', 'unrelated', 'closer'] as $who) {
        [$status, $denied] = $fixture->call('document-requests-list.php?view=inbox&id=' . $tickets['own'], $tokens[$who]);
        $fixture->check($status === 200 && $denied['requests'] === [], "$who exact unrelated ticket lookup exposes no purpose");
    }
    [$status, $cancelled] = $fixture->call('document-requests-list.php?view=outbox&id=' . $tickets['cancelled'], $tokens['requester']);
    $fixture->check($status === 200 && $ids($cancelled['requests']) === [$tickets['cancelled']],
        'cancelled request remains available in permitted Requests history while excluded from folder-linked presentation');
    $fixture->check((int)$db->query('SELECT COUNT(*) FROM document_requests')->fetchColumn() === 9
        && (int)$db->query('SELECT COUNT(*) FROM movements')->fetchColumn() === 1
        && $db->query('SELECT fulfilled_office_id FROM document_requests WHERE id=' . $tickets['dv_tre_snapshot'])->fetchColumn() == 5,
        'read-scope matrix preserves tickets, custody and recorded Treasury completion office');
    $fixture->assertCopies();
} finally { $fixture->close(); }
echo "{$fixture->checks} isolated linked-ticket scope checks passed\n";
