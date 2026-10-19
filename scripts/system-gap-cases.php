<?php
/** API regressions run only inside the guarded disposable database harness. */
function smartflow_test_system_gaps(PDO $pdo, array $tokens): void
{
    $database = (string)$pdo->query('SELECT DATABASE()')->fetchColumn();
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', $database)) {
        throw new RuntimeException('System gap cases require the disposable harness database');
    }
    require_once __DIR__ . '/../backend/backend/api/creation-requests-helper.php';

    // Monitor roles must be denied even for their own office, not merely for cross-office writes.
    foreach ([['head', 'bud', 3, 'Approved Budget'], ['admin', 'acc', 4, 'Approved Budget']] as [$monitor, $staff, $office, $type]) {
        $before = (int)$pdo->query('SELECT COUNT(*) FROM documents')->fetchColumn();
        [$http] = register($monitor, $office, $type);
        check($http === 403 && $before === (int)$pdo->query('SELECT COUNT(*) FROM documents')->fetchColumn(),
            "$monitor cannot register a folder at their assigned office");
        [$http, $registered] = register($staff, $office, $type);
        check($http === 201, "$staff staff retains assigned-office registration authority");
        $documentId = $registered['document']['id'];
        $latest = $pdo->prepare('SELECT MAX(id) FROM movements WHERE document_id = ?');
        $latest->execute([$documentId]);
        $body = ['document_id' => $documentId, 'office_id' => $office, 'status' => 'OUT',
            'destination_office_id' => 2, 'movement_source' => 'system', 'expected_movement_id' => (int)$latest->fetchColumn()];
        $before = (int)$pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn();
        [$http, $denied] = api('movements-create.php', $tokens[$monitor], $body);
        check($http === 403 && ($denied['scan_error'] ?? '') === 'role_forbidden'
            && $before === (int)$pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn(),
            "$monitor cannot record assigned-office physical handoffs");
        check(api('movements-create.php', $tokens[$staff], $body)[0] === 200,
            "$staff staff retains confirmed physical handoff authority");
    }

    // Put the pending ticket beyond the old 100-record window and retain independent aggregate counts.
    $needle = 'PAGING-' . bin2hex(random_bytes(4));
    $insert = $pdo->prepare('INSERT INTO document_requests (request_code, request_kind, document_category,
        requested_by, requester_office_id, requester_role, handler_office_id, purpose, required_by, status, created_at)
        VALUES (?, "access", "budget", 1, 1, "staff", 3, ?, DATE_SUB(CURDATE(), INTERVAL 1 DAY), ?, ?)');
    $oldId = 0;
    for ($i = 0; $i < 115; $i++) {
        $insert->execute([sprintf('%s-%03d', $needle, $i), "$needle complete purpose $i",
            $i === 0 ? 'pending' : 'approved', $i === 0 ? '2000-01-01 12:00:00' : '2000-01-02 12:00:00']);
        if ($i === 0) $oldId = (int)$pdo->lastInsertId();
    }
    $query = static fn(array $params): string => 'document-requests-list.php?' . http_build_query($params);
    [$http, $first] = api($query(['view' => 'inbox', 'q' => $needle, 'page_size' => 100]), $tokens['bud']);
    check($http === 200 && $first['total'] === 115 && count($first['requests']) === 100 && $first['has_more'],
        'request search reports all matching rows before the 100-row page limit');
    [$http, $last] = api($query(['view' => 'inbox', 'q' => $needle, 'page_size' => 100, 'page' => 2]), $tokens['bud']);
    check($http === 200 && count($last['requests']) === 15 && !$last['has_more']
        && in_array($oldId, array_column($last['requests'], 'id'), true),
        'old pending requests remain reachable beyond the first hundred records');
    [$http, $pending] = api($query(['view' => 'inbox', 'q' => $needle, 'status' => 'pending', 'page_size' => 1]), $tokens['bud']);
    check($http === 200 && $pending['total'] === 1 && $pending['requests'][0]['id'] === $oldId,
        'request status filtering runs over all records before pagination');
    [$http, $exact] = api($query(['view' => 'inbox', 'id' => $oldId, 'status' => 'cancelled', 'q' => 'unrelated']), $tokens['bud']);
    check($http === 200 && $exact['total'] === 1 && $exact['requests'][0]['id'] === $oldId,
        'exact request deep links resolve old records independently of list filters');
    $expectedCounts = array_map('intval', $pdo->query("SELECT COUNT(*) AS total,
        COALESCE(SUM(status='pending'),0) AS pending,
        COALESCE(SUM(status IN ('pending','approved') AND required_by<CURDATE()),0) AS overdue,
        COALESCE(SUM(status IN ('pending','approved')),0) AS active,
        COALESCE(SUM(status IN ('fulfilled','rejected','cancelled')),0) AS past
        FROM document_requests WHERE handler_office_id=3")->fetch());
    check($first['counts'] === $expectedCounts && $pending['counts'] === $expectedCounts,
        'request whole-view counts do not shrink with page or status/search filters');
    [$http, $overdue] = api($query(['view' => 'inbox', 'q' => $needle, 'overdue' => 1, 'page_size' => 1]), $tokens['bud']);
    check($http === 200 && $overdue['total'] === 115 && count($overdue['requests']) === 1,
        'request overdue filtering includes old pending and accepted work');
    [$http, $outbox] = api($query(['view' => 'outbox', 'id' => $oldId]), $tokens['eng']);
    check($http === 200 && $outbox['total'] === 1, 'requester deep links retain old request access');
    [$http, $isolated] = api($query(['view' => 'inbox', 'id' => $oldId]), $tokens['hr']);
    check($http === 200 && $isolated['total'] === 0, 'exact request links cannot bypass office scope');
    check(api($query(['view' => 'all', 'id' => $oldId]), $tokens['bud'])[0] === 403,
        'request pagination does not expose the municipal view to staff');
    [$http, $municipal] = api($query(['view' => 'all', 'id' => $oldId]), $tokens['admin']);
    check($http === 200 && $municipal['total'] === 1, 'admin can still inspect an old municipal request');

    // Grouped views are server-side: terminal records must not displace an active page.
    $pastIds = [];
    for ($i = 0; $i < 12; $i++) {
        $insert->execute([sprintf('%s-P%02d', $needle, $i), "$needle past purpose $i",
            ['fulfilled', 'rejected', 'cancelled'][$i % 3], '2000-01-03 12:00:00']);
        $pastIds[] = (int)$pdo->lastInsertId();
    }
    [$http, $active] = api($query(['view' => 'inbox', 'q' => $needle, 'status' => 'active', 'page_size' => 100]), $tokens['bud']);
    check($http === 200 && $active['total'] === 115 && count($active['requests']) === 100 && $active['has_more']
        && !array_diff(array_column($active['requests'], 'status'), ['pending', 'approved']),
        'active request pages exclude closed declined and cancelled work before pagination');
    [$http, $activeLast] = api($query(['view' => 'inbox', 'q' => $needle, 'status' => 'active', 'page_size' => 100, 'page' => 2]), $tokens['bud']);
    check($http === 200 && count($activeLast['requests']) === 15 && !$activeLast['has_more']
        && in_array($oldId, array_column($activeLast['requests'], 'id'), true),
        'active requests retain accepted work and an old pending ticket beyond the first hundred');
    [$http, $past] = api($query(['view' => 'inbox', 'q' => $needle, 'status' => 'past', 'page_size' => 7]), $tokens['bud']);
    [$lastHttp, $pastLast] = api($query(['view' => 'inbox', 'q' => $needle, 'status' => 'past', 'page_size' => 7, 'page' => 2]), $tokens['bud']);
    $returnedPastIds = array_merge(array_column($past['requests'], 'id'), array_column($pastLast['requests'], 'id'));
    sort($returnedPastIds); sort($pastIds);
    check($http === 200 && $lastHttp === 200 && $past['total'] === 12 && count($past['requests']) === 7
        && $past['has_more'] && count($pastLast['requests']) === 5 && !$pastLast['has_more'] && $returnedPastIds === $pastIds,
        'past request pages include each fulfilled rejected and cancelled ticket exactly once');
    $groupCounts = array_map('intval', $pdo->query("SELECT COUNT(*) AS total,
        COALESCE(SUM(status='pending'),0) AS pending,
        COALESCE(SUM(status IN ('pending','approved') AND required_by<CURDATE()),0) AS overdue,
        COALESCE(SUM(status IN ('pending','approved')),0) AS active,
        COALESCE(SUM(status IN ('fulfilled','rejected','cancelled')),0) AS past
        FROM document_requests WHERE handler_office_id=3")->fetch());
    check($active['counts'] === $groupCounts && $pastLast['counts'] === $groupCounts
        && $groupCounts['active'] + $groupCounts['past'] === $groupCounts['total'],
        'active and past counts cover the whole scoped view independently of search pages and status');
    [$http, $outbox] = api($query(['view' => 'outbox', 'q' => $needle, 'status' => 'past', 'page_size' => 1]), $tokens['eng']);
    check($http === 200 && $outbox['total'] === 12 && count($outbox['requests']) === 1,
        'requester past view uses the same complete server filtering');
    [$http, $otherInbox] = api($query(['view' => 'inbox', 'q' => $needle, 'status' => 'past']), $tokens['hr']);
    check($http === 200 && $otherInbox['total'] === 0 && $otherInbox['counts']['past'] === 0,
        'grouped request views and their counts retain office scope');
    [$http, $pastOverdue] = api($query(['view' => 'inbox', 'q' => $needle, 'status' => 'past', 'overdue' => 1]), $tokens['bud']);
    check($http === 200 && $pastOverdue['total'] === 0, 'past request groups cannot become overdue again');
    [$http, $exactPast] = api($query(['view' => 'inbox', 'id' => $pastIds[0], 'status' => 'active', 'overdue' => 1, 'q' => 'unrelated', 'page' => 99]), $tokens['bud']);
    check($http === 200 && $exactPast['total'] === 1 && $exactPast['page'] === 1 && $exactPast['requests'][0]['id'] === $pastIds[0],
        'exact permitted past ticket remains accessible outside the active overdue search view');
    check(api($query(['view' => 'inbox', 'status' => 'unknown']), $tokens['bud'])[0] === 400,
        'grouped request filtering still rejects unsupported statuses');

    // Closing office is historical evidence; moving the closer's account must not hide their old work.
    $closedId = (int)$pdo->query('SELECT id FROM document_requests WHERE fulfilled_by=4 AND fulfilled_office_id=5 ORDER BY id DESC LIMIT 1')->fetchColumn();
    $fixtureUser = $pdo->prepare('INSERT INTO users (name,username,password_hash,office_id,role) VALUES (?,?,?,? ,"staff")');
    $fixtureUser->execute(['History Treasury', 'tre_history', password_hash('test-password', PASSWORD_DEFAULT), 5]);
    [$http, $login] = api('auth-login.php', null, ['username' => 'tre_history', 'password' => 'test-password']);
    check($http === 200 && isset($login['token']), 'historical Treasury viewer fixture signs in');
    $pdo->exec('UPDATE users SET office_id=2 WHERE id=4');
    try {
        [$http, $closed] = api($query(['view' => 'inbox', 'id' => $closedId]), $login['token']);
        check($closedId > 0 && $http === 200 && $closed['total'] === 1
            && $closed['requests'][0]['fulfilled_office_id'] === 5,
            'Treasury retains completed payment tickets after the closer changes office');
    } finally {
        $pdo->exec('UPDATE users SET office_id=5 WHERE id=4');
    }
    $unknownCloser = requestFixture(handler: 4, category: 'disbursement', status: 'fulfilled');
    [$http, $legacy] = api($query(['view' => 'inbox', 'id' => $unknownCloser]), $login['token']);
    check($http === 200 && $legacy['total'] === 0,
        'legacy completed DVs without Treasury closer evidence are not guessed into its inbox');

    // Complete day log: 14 own-office events, foreign events and midnight boundaries.
    [$http, $historyFolder] = register('hr', 2, 'Others: History coverage');
    check($http === 201, 'office history fixture folder registers');
    $historyId = $historyFolder['document']['id'];
    $event = $pdo->prepare('INSERT INTO movements (document_id,office_id,status,user_id,destination_office_id,scanned_at,remarks)
        VALUES (?, ?, ?, 9, ?, ?, "Isolated complete history fixture")');
    $historyIds = [];
    for ($i = 0; $i < 14; $i++) {
        $event->execute([$historyId, 2, $i % 2 ? 'OUT' : 'IN', $i % 2 ? 3 : null, sprintf('2001-03-04 12:%02d:00', $i)]);
        $historyIds[] = (int)$pdo->lastInsertId();
    }
    foreach ([[2, '2001-03-03 23:59:59'], [2, '2001-03-05 00:00:00'], [3, '2001-03-04 14:00:00']] as [$office, $time]) {
        $event->execute([$historyId, $office, 'IN', null, $time]);
    }
    $historyQuery = static fn(array $params): string => 'office-movements-list.php?' . http_build_query(
        array_merge(['office_id' => 2, 'date' => '2001-03-04'], $params));
    [$http, $history] = api($historyQuery(['page_size' => 8]), $tokens['hr']);
    check($http === 200 && count($history['movements']) === 8 && $history['total'] === 14 && $history['has_more']
        && $history['stats'] === ['total' => 14, 'in_flow' => 7, 'out_flow' => 7],
        'complete office history counts more than eight events and excludes other offices/days');
    [$http, $historyLast] = api($historyQuery(['page_size' => 8, 'page' => 2]), $tokens['hr']);
    $returnedIds = array_merge(array_column($history['movements'], 'id'), array_column($historyLast['movements'], 'id'));
    sort($returnedIds); sort($historyIds);
    check($http === 200 && count($historyLast['movements']) === 6 && !$historyLast['has_more'] && $returnedIds === $historyIds,
        'office history pagination returns each daily movement once without omissions');
    [$http, $outs] = api($historyQuery(['status' => 'OUT', 'page_size' => 3, 'page' => 3]), $tokens['hr']);
    check($http === 200 && $outs['total'] === 7 && count($outs['movements']) === 1
        && $outs['stats']['in_flow'] === 7 && $outs['movements'][0]['status'] === 'OUT',
        'office history status pagination keeps complete daily totals');
    check(api($historyQuery([]), $tokens['bud'])[0] === 403
        && api($historyQuery([]), $tokens['head'])[0] === 403,
        'staff and heads cannot request another office daily history');
    [$http, $adminHistory] = api($historyQuery(['page_size' => 100]), $tokens['admin']);
    check($http === 200 && $adminHistory['total'] === 14 && count($adminHistory['movements']) === 14,
        'admin retains read-only access to a complete selected-office history');
    check(api($historyQuery(['date' => '2001-02-30']), $tokens['hr'])[0] === 400
        && api($historyQuery(['status' => 'filed']), $tokens['hr'])[0] === 400,
        'office history rejects impossible dates and unsupported movement filters');

    smartflow_test_creation_recovery($pdo, $tokens);
}

function smartflow_test_creation_recovery(PDO $pdo, array $tokens): void
{
    $fixture = $pdo->prepare('INSERT INTO users (name,username,password_hash,office_id,role) VALUES (?,?,?,1,"staff")');
    $fixture->execute(['Other Engineering', 'eng_retry', password_hash('test-password', PASSWORD_DEFAULT)]);
    [$http, $login] = api('auth-login.php', null, ['username' => 'eng_retry', 'password' => 'test-password']);
    check($http === 200 && isset($login['token']), 'same-office creation collision fixture signs in');
    $otherActor = $login['token'];
    $outcomePath = static fn(string $id, string $kind): string => 'creation-requests.php?' . http_build_query(['operation_id' => $id, 'kind' => $kind]);
    $documentBody = ['operation_id' => bin2hex(random_bytes(16)), 'title' => 'Recoverable folder creation',
        'type' => 'Others: Creation retry', 'origin_office_id' => 1,
        'folder_inventory' => ['count_confirmed' => true, 'items' => [['pages' => 2], ['name' => 'Supporting note', 'pages' => 1, 'required' => true]]]];
    [$http, $unknown] = api($outcomePath($documentBody['operation_id'], 'document'), $tokens['eng']);
    check($http === 200 && $unknown['state'] === 'unknown' && $unknown['result'] === null,
        'creation outcome is unknown before a submission is committed');
    $before = (int)$pdo->query('SELECT COUNT(*) FROM documents')->fetchColumn();
    [$http, $created] = api('documents-create.php', $tokens['eng'], $documentBody);
    check($http === 201 && isset($created['document']['id']), 'operation-protected folder creation succeeds');
    [$http, $replayed] = api('documents-create.php', $tokens['eng'], $documentBody);
    check($http === 201 && $replayed === $created
        && (int)$pdo->query('SELECT COUNT(*) FROM documents')->fetchColumn() === $before + 1,
        'identical folder retry returns the original folder and QR without duplicate registration');
    $count = $pdo->prepare('SELECT COUNT(*) FROM movements WHERE document_id=?');
    $count->execute([$created['document']['id']]);
    check((int)$count->fetchColumn() === 1, 'folder retry creates exactly one initial custody record');
    [$http, $outcome] = api($outcomePath($documentBody['operation_id'], 'document'), $tokens['eng']);
    check($http === 200 && $outcome['state'] === 'recorded' && $outcome['result'] === $created,
        'lost folder response can be recovered by its recorded operation outcome');
    $changed = $documentBody; $changed['title'] = 'Changed folder payload';
    check(api('documents-create.php', $tokens['eng'], $changed)[0] === 409
        && api('documents-create.php', $otherActor, $documentBody)[0] === 409,
        'folder operation IDs cannot be reused for changed content or another staff actor');
    [$http, $private] = api($outcomePath($documentBody['operation_id'], 'document'), $otherActor);
    check($http === 200 && $private['state'] === 'unknown' && $private['result'] === null,
        'creation outcome lookup does not reveal another actor record');
    $reordered = array_reverse($documentBody, true);
    $reordered['token'] = 'ignored-transport-value'; $reordered['access_token'] = 'ignored-transport-value';
    check(smartflow_creation_hash($documentBody) === smartflow_creation_hash($reordered),
        'creation fingerprint ignores transport tokens and object key order');
    [$http, $replayed] = api('documents-create.php', $tokens['eng'], $reordered);
    check($http === 201 && $replayed['document']['id'] === $created['document']['id'],
        'folder retry after token or object-order changes retains its original outcome');

    $requestBody = ['operation_id' => bin2hex(random_bytes(16)), 'request_kind' => 'access',
        'document_category' => 'budget', 'purpose' => 'Recoverable formal request', 'required_by' => date('Y-m-d')];
    $before = (int)$pdo->query('SELECT COUNT(*) FROM document_requests')->fetchColumn();
    [$http, $requestCreated] = api('document-requests-create.php', $tokens['eng'], $requestBody);
    check($http === 201 && isset($requestCreated['request']['id']), 'operation-protected ticket creation succeeds');
    [$http, $requestReplay] = api('document-requests-create.php', $tokens['eng'], $requestBody);
    check($http === 201 && $requestReplay === $requestCreated
        && (int)$pdo->query('SELECT COUNT(*) FROM document_requests')->fetchColumn() === $before + 1,
        'identical ticket retry returns the original request without duplicate tickets');
    [$http, $requestOutcome] = api($outcomePath($requestBody['operation_id'], 'request'), $tokens['eng']);
    check($http === 200 && $requestOutcome['state'] === 'recorded' && $requestOutcome['result'] === $requestCreated,
        'lost ticket response can be recovered without another create');
    $requestChanged = $requestBody; $requestChanged['purpose'] = 'Changed formal request';
    check(api('document-requests-create.php', $tokens['eng'], $requestChanged)[0] === 409
        && api('document-requests-create.php', $otherActor, $requestBody)[0] === 409,
        'ticket operation IDs reject changed content and actor collisions');
    $wrongKind = $requestBody; $wrongKind['operation_id'] = $documentBody['operation_id'];
    check(api('document-requests-create.php', $tokens['eng'], $wrongKind)[0] === 409,
        'one creation operation ID cannot be reused for a different record kind');

    // Simulate a committed ticket from yesterday; retry must precede time-sensitive validation.
    $pastBody = $requestBody; $pastBody['required_by'] = date('Y-m-d', strtotime('yesterday'));
    $pastResult = $requestCreated; $pastResult['request']['required_by'] = $pastBody['required_by'];
    $pdo->prepare('UPDATE creation_requests SET body_hash=?,response_json=? WHERE operation_id=?')->execute([
        smartflow_creation_hash($pastBody), json_encode($pastResult, JSON_THROW_ON_ERROR), $requestBody['operation_id']]);
    $pdo->prepare('UPDATE document_requests SET required_by=? WHERE id=?')->execute([$pastBody['required_by'], $requestCreated['request']['id']]);
    [$http, $pastReplay] = api('document-requests-create.php', $tokens['eng'], $pastBody);
    check($http === 201 && $pastReplay === $pastResult,
        'a committed request remains recoverable after its required-by date passes');

    foreach (['document', 'request'] as $kind) {
        $body = $kind === 'document' ? $documentBody : $requestBody;
        $body['operation_id'] = bin2hex(random_bytes(16));
        $table = $kind === 'document' ? 'movements' : 'document_requests';
        $endpoint = $kind === 'document' ? 'documents-create.php' : 'document-requests-create.php';
        $before = (int)$pdo->query('SELECT (SELECT COUNT(*) FROM documents)+(SELECT COUNT(*) FROM document_requests)+(SELECT COUNT(*) FROM movements)')->fetchColumn();
        $pdo->exec("CREATE TRIGGER test_creation_failure BEFORE INSERT ON $table FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Injected creation failure'");
        try { [$http] = api($endpoint, $tokens['eng'], $body); }
        finally { $pdo->exec('DROP TRIGGER test_creation_failure'); }
        $operation = $pdo->prepare('SELECT COUNT(*) FROM creation_requests WHERE operation_id=?');
        $operation->execute([$body['operation_id']]);
        check($http === 500 && (int)$operation->fetchColumn() === 0 && $before === (int)$pdo->query(
            'SELECT (SELECT COUNT(*) FROM documents)+(SELECT COUNT(*) FROM document_requests)+(SELECT COUNT(*) FROM movements)')->fetchColumn(),
            "$kind creation failure rolls back both records and its operation reservation");
        [$http, $failedOutcome] = api($outcomePath($body['operation_id'], $kind), $tokens['eng']);
        check($http === 200 && $failedOutcome['state'] === 'unknown', "$kind failed creation has no false recorded outcome");
        check(api($endpoint, $tokens['eng'], $body)[0] === 201,
            "$kind explicitly retried rolled-back operation can subsequently commit");
    }
    $invalid = $documentBody; $invalid['operation_id'] = 'bad-operation-id';
    check(api('documents-create.php', $tokens['eng'], $invalid)[0] === 400
        && api('creation-requests.php?operation_id=bad-operation-id&kind=document', $tokens['eng'])[0] === 400,
        'creation writes and outcome reads reject malformed operation IDs');
}
