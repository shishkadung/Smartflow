<?php
/** Only called inside the guarded disposable API harness. */
require_once __DIR__ . '/../backend/backend/api/routing-helper.php';
require_once __DIR__ . '/../backend/backend/api/creation-requests-helper.php';

function smartflow_test_final_flow(PDO $pdo): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Final flow cases require the disposable database');
    }
    $tokens = []; $actors = [];
    $insert = $pdo->prepare('INSERT INTO users (name,username,password_hash,office_id,role) VALUES (?,?,?,?,?)');
    foreach ([['hr', 2, 'staff'], ['eng', 1, 'staff'], ['bud', 3, 'staff'], ['acc', 4, 'staff'],
        ['tre', 5, 'staff'], ['may', 6, 'staff'], ['head', 2, 'head'], ['admin', 4, 'admin'],
        ['audit', 2, 'auditor']] as [$name, $office, $role]) {
        $username = 'final_flow_' . $name . '_' . bin2hex(random_bytes(3));
        $insert->execute(['Final flow fixture', $username, password_hash('test-password', PASSWORD_DEFAULT), $office, $role]);
        $actors[$name] = (int)$pdo->lastInsertId();
        [$http, $login] = api('auth-login.php', null, ['username' => $username, 'password' => 'test-password']);
        check($http === 200 && isset($login['token']), "independent $name final flow fixture signs in");
        $tokens[$name] = $login['token'];
    }
    smartflow_test_named_others($pdo, $tokens, $actors);
    smartflow_test_pull_contract($pdo, $tokens, $actors);
}

function smartflow_test_named_others(PDO $pdo, array $tokens, array $actors): void
{
    foreach (['Others: Voucher copies', 'Others: Disbursement notes', 'Others: Approved budget references',
        'Others: Travel attachments', '  oThErS: approved budget voucher  '] as $type) {
        check(smartflow_type_is_other($type) && !smartflow_type_is_dv($type)
            && !smartflow_type_is_approved_budget($type) && !smartflow_type_has_fixed_route($type)
            && smartflow_suggest_forward_destination($type, 'HR', []) === null,
            "explicit $type keeps the Others workflow");
    }
    foreach (['Disbursement Voucher', 'Historical disbursement', 'Voucher'] as $type) {
        check(smartflow_type_is_dv($type) && smartflow_type_has_fixed_route($type)
            && smartflow_suggest_forward_destination($type, 'TRE', [])['code'] === 'MAY',
            "financial DV control $type keeps its existing route");
    }
    foreach (['Approved Budget', 'Historical approved budget', 'budget'] as $type) {
        check(smartflow_type_has_fixed_route($type)
            && smartflow_suggest_forward_destination($type, 'BUD', [])['code'] === 'ACC',
            "financial Budget control $type keeps its existing route");
    }
    $othersIds = [];
    foreach ([['Others: Voucher copies', 'may', 6, 'tre', 5],
        ['Others: Disbursement notes', 'may', 6, 'tre', 5],
        ['Others: Approved budget references', 'bud', 3, 'acc', 4]] as [$type, $first, $firstOffice, $holder, $holderOffice]) {
        [$http, $created] = api('documents-create.php', $tokens['hr'], ['title' => $type, 'type' => $type,
            'origin_office_id' => 2, 'due_at' => date('Y-m-d', strtotime('yesterday'))]);
        check($http === 201 && $created['document']['initial_in_recorded'], "$type registers without financial logbook fields");
        $id = $created['document']['id']; $othersIds[] = $id;
        [$http, $detail] = api('documents-show.php?id=' . $id, $tokens['hr']);
        check($http === 200 && $detail['document']['can_file'] && !$detail['document']['trail_complete']
            && $detail['document']['suggested_forward'] === null, "$type starts as a filable Others folder");
        $latest = (int)$detail['document']['last_movement_id'];
        foreach ([['hr', 2, 'OUT', $firstOffice], [$first, $firstOffice, 'IN', null],
            [$first, $firstOffice, 'OUT', $holderOffice], [$holder, $holderOffice, 'IN', null]] as [$who, $office, $status, $destination]) {
            $body = ['document_id' => $id, 'office_id' => $office, 'status' => $status,
                'movement_source' => 'system', 'expected_movement_id' => $latest];
            if ($destination !== null) $body['destination_office_id'] = $destination;
            if ($status === 'IN') $body['receipt_confirmed'] = true;
            [$http, $moved] = api('movements-create.php', $tokens[$who], $body);
            check($http === 200, "$type records the explicit $who $status handoff");
            $latest = (int)$moved['movement_id'];
        }
        [$http, $detail] = api('documents-show.php?id=' . $id, $tokens[$holder]);
        $doc = $detail['document'];
        check($http === 200 && !$doc['trail_complete'] && $doc['can_file'] && !$doc['can_return_to_accounting']
            && $doc['suggested_forward'] === null && $doc['is_overdue'] && $doc['due_at'] !== null
            && !smartflow_document_trail_complete($pdo, $id), "$type cannot auto-complete or lose its deadline from financial office history");
        [$http, $queue] = api('office-documents.php?id=' . $id, $tokens[$holder]);
        check($http === 200 && !$queue['document']['trail_complete'] && $queue['document']['can_file']
            && !$queue['document']['can_return_to_accounting'] && $queue['document']['is_overdue'],
            "$type queue agrees with direct folder detail");
        foreach (['head', 'admin', 'hr'] as $denied) {
            check(api('documents-file.php', $tokens[$denied], ['document_id' => $id, 'expected_movement_id' => $latest])[0]
                === ($denied === 'hr' ? 409 : 403), "$type still rejects $denied filing authority");
        }
        [$http] = api('documents-file.php', $tokens[$holder], ['document_id' => $id, 'expected_movement_id' => $latest]);
        check($http === 200 && smartflow_document_trail_complete($pdo, $id), "$type files only through the current staff holder action");
        [$http, $filed] = api('documents-show.php?id=' . $id, $tokens[$holder]);
        check($http === 200 && $filed['document']['trail_complete'] && !$filed['document']['can_file']
            && !$filed['document']['can_return_to_accounting'] && !$filed['document']['is_overdue']
            && $filed['document']['due_at'] === null && !str_contains($filed['document']['pilot_end_note'], 'Budget')
            && !str_contains($filed['document']['pilot_end_note'], 'DV'), "$type filed detail preserves the correct completion wording and state");
    }
    $legacyIds = [];
    $insertDoc = $pdo->prepare('INSERT INTO documents (id,title,type,origin_office_id,created_by) VALUES (?,?,?,1,?)');
    $insertMove = $pdo->prepare('INSERT INTO movements (document_id,office_id,status,user_id,scanned_at)
        VALUES (?, ?, "IN", ?, DATE_ADD(NOW(), INTERVAL ? SECOND))');
    foreach ([['Voucher', [6, 5], true], ['Historical disbursement', [6, 5], true],
        ['Historical approved budget', [3, 4], true], ['budget', [3, 4], false]] as [$type, $offices, $complete]) {
        $id = 'LEGACY-' . bin2hex(random_bytes(8)); $legacyIds[] = $id;
        $insertDoc->execute([$id, 'Financial legacy control', $type, $actors['eng']]);
        foreach ([1, ...$offices] as $index => $office) $insertMove->execute([$id, $office, $actors['eng'], $index - 10]);
        $latest = (int)$pdo->lastInsertId();
        check(smartflow_document_trail_complete($pdo, $id) === $complete, "$type keeps its legacy SQL completion behavior");
        check(api('documents-file.php', $tokens[$offices[1] === 4 ? 'acc' : 'tre'],
            ['document_id' => $id, 'expected_movement_id' => $latest])[0] === 409,
            "$type still rejects explicit filing for a financial route");
    }
    foreach ([["\tOthers: Voucher copies", [6, 5]], ["\n Others: Approved budget references", [3, 4]],
        [" \r\nOtHeRs: Disbursement notes", [6, 5]]] as $index => [$type, $offices]) {
        $id = 'LEGACY-OTHER-' . bin2hex(random_bytes(6)); $othersIds[] = $id;
        $insertDoc->execute([$id, 'Legacy named Others whitespace', $type, $actors['eng']]);
        foreach ([1, ...$offices] as $step => $office) $insertMove->execute([$id, $office, $actors['eng'], $step - 10]);
        $latest = (int)$pdo->lastInsertId();
        $holder = $offices[1] === 4 ? 'acc' : 'tre';
        check(smartflow_type_is_other($type) && !smartflow_document_trail_complete($pdo, $id),
            "legacy whitespace Others case $index cannot auto-complete under financial office history");
        [$http, $detail] = api('documents-show.php?id=' . $id, $tokens[$holder]);
        check($http === 200 && $detail['document']['can_file'] && !$detail['document']['trail_complete']
            && !$detail['document']['can_return_to_accounting'] && $detail['document']['suggested_forward'] === null,
            "legacy whitespace Others case $index detail agrees with SQL classification");
        check(api('documents-file.php', $tokens[$holder], ['document_id' => $id, 'expected_movement_id' => $latest])[0] === 200
            && smartflow_document_trail_complete($pdo, $id),
            "legacy whitespace Others case $index completes through explicit staff filing");
    }
    [$http, $audit] = api('audit-exceptions.php', $tokens['admin']);
    $othersSkipped = array_filter($audit['exceptions'], static fn(array $row): bool =>
        in_array($row['document_id'], $othersIds, true) && $row['exception_type'] === 'skipped_office');
    $legacySkipped = array_filter($audit['exceptions'], static fn(array $row): bool =>
        in_array($row['document_id'], array_slice($legacyIds, 0, 3), true) && $row['exception_type'] === 'skipped_office');
    check($http === 200 && count($othersSkipped) === 0 && count($legacySkipped) === 2,
        'audit skips financial-stage warnings for named Others while retaining legacy financial warnings');
}

function smartflow_test_pull_contract(PDO $pdo, array $tokens, array $actors): void
{
    $base = ['request_kind' => 'pull', 'target_office_id' => 1, 'purpose' => 'General office pull fixture',
        'required_by' => date('Y-m-d')];
    $staleDv = null;
    foreach (['hr', 'head', 'admin'] as $who) {
        foreach ([null, '', 'general', 'budget', 'disbursement', 'other'] as $category) {
            $body = $base;
            if ($category !== null) $body['document_category'] = $category;
            [$http, $created] = api('document-requests-create.php', $tokens[$who], $body);
            $request = $created['request'] ?? [];
            check($http === 201 && $request['request_kind'] === 'pull' && $request['document_category'] === 'general'
                && $request['handler_office']['office_code'] === 'ENG' && $request['target_office']['office_code'] === 'ENG',
                "$who pull stores general with category " . ($category ?? '(omitted)'));
            if ($who === 'hr' && $category === 'disbursement') $staleDv = $request;
        }
    }
    $decision = ['request_id' => $staleDv['id'], 'expected_status' => $staleDv['status'],
        'expected_revision' => $staleDv['revision'], 'action' => 'approve'];
    [$http, $accepted] = api('document-requests-update.php', $tokens['eng'], $decision);
    check($http === 200 && $accepted['request']['document_category'] === 'general', 'selected target office accepts the normalized general pull');
    $close = ['request_id' => $staleDv['id'], 'expected_status' => 'approved',
        'expected_revision' => $accepted['request']['revision'], 'action' => 'fulfill'];
    foreach (['hr', 'tre'] as $denied) check(api('document-requests-update.php', $tokens[$denied], $close)[0] === 403,
        "$denied cannot close another office general pull");
    check(api('document-requests-update.php', $tokens['eng'], $close)[0] === 200,
        'general pull closes at its handler without requiring Treasury payment release');

    foreach ([['budget', 3], ['disbursement', 4], ['other', 1]] as [$category, $expectedOffice]) {
        [$http, $created] = api('document-requests-create.php', $tokens['hr'], array_merge($base,
            ['request_kind' => 'access', 'document_category' => $category]));
        check($http === 201 && $created['request']['document_category'] === $category
            && $created['request']['handler_office']['office_id'] === $expectedOffice,
            "$category access keeps its established handler and category");
    }
    $defaultKind = $base; unset($defaultKind['request_kind']); $defaultKind['document_category'] = 'budget';
    [$http, $created] = api('document-requests-create.php', $tokens['hr'], $defaultKind);
    check($http === 201 && $created['request']['request_kind'] === 'access'
        && $created['request']['handler_office']['office_code'] === 'BUD', 'omitted request kind keeps the access default');
    $before = (int)$pdo->query('SELECT COUNT(*) FROM document_requests')->fetchColumn();
    foreach ([null, 0, -1, 'bad', true, 1.5, 999999, 2] as $target) {
        $invalid = $base; $invalid['target_office_id'] = $target;
        check(api('document-requests-create.php', $tokens['hr'], $invalid)[0] === 400,
            'pull rejects missing malformed nonexistent or own-office target ' . json_encode($target));
    }
    $missing = $base; unset($missing['target_office_id']);
    check(api('document-requests-create.php', $tokens['hr'], $missing)[0] === 400, 'pull requires a selected target office');
    foreach ([['audit', [], 403], ['hr', ['request_kind' => 'unknown'], 403],
        ['hr', ['document_category' => 'unknown'], 403], ['hr', ['document_category' => 'payroll'], 400],
        ['hr', ['request_kind' => 'access', 'document_category' => 'general'], 400]] as [$who, $extra, $expected]) {
        check(api('document-requests-create.php', $tokens[$who], array_merge($base, $extra))[0] === $expected,
            'pull normalization retains role kind and category validation (HTTP ' . $expected . ')');
    }
    check((int)$pdo->query('SELECT COUNT(*) FROM document_requests')->fetchColumn() === $before,
        'rejected pull submissions leave no request rows');

    $operation = $base + ['document_category' => 'disbursement', 'operation_id' => bin2hex(random_bytes(16))];
    [$http, $first] = api('document-requests-create.php', $tokens['hr'], $operation);
    [$againHttp, $again] = api('document-requests-create.php', $tokens['hr'], $operation);
    check($http === 201 && $againHttp === 201 && $first === $again && $first['request']['document_category'] === 'general',
        'normalized pull recovery replays the same saved result');
    $changed = $operation; $changed['document_category'] = 'general';
    check(api('document-requests-create.php', $tokens['hr'], $changed)[0] === 409,
        'normalization cannot change the payload bound to an existing creation operation');

    // An already recorded pre-fix operation remains historical evidence, including its original category.
    $historicalBody = $operation; $historicalBody['operation_id'] = bin2hex(random_bytes(16));
    $historicalBody['required_by'] = date('Y-m-d', strtotime('yesterday'));
    $pdo->prepare('INSERT INTO document_requests (request_code,request_kind,document_category,requested_by,
        requester_office_id,requester_role,handler_office_id,target_office_id,purpose,required_by,status)
        VALUES (?,"pull","disbursement",?,2,"staff",1,1,?,?,"pending")')
        ->execute(['HIST-' . bin2hex(random_bytes(5)), $actors['hr'], $base['purpose'], $historicalBody['required_by']]);
    $historicalId = (int)$pdo->lastInsertId();
    $query = $pdo->prepare(SMARTFLOW_DR_SELECT . ' WHERE r.id=?'); $query->execute([$historicalId]);
    $historicalResponse = ['success' => true, 'message' => 'Historical saved submission',
        'request' => smartflow_format_document_request_row($query->fetch())];
    $pdo->prepare('INSERT INTO creation_requests (operation_id,user_id,kind,body_hash,response_json) VALUES (?, ?, "request", ?, ?)')
        ->execute([$historicalBody['operation_id'], $actors['hr'], smartflow_creation_hash($historicalBody), json_encode($historicalResponse, JSON_THROW_ON_ERROR)]);
    [$http, $replayed] = api('document-requests-create.php', $tokens['hr'], $historicalBody);
    check($http === 201 && $replayed === $historicalResponse
        && $pdo->query('SELECT document_category FROM document_requests WHERE id=' . $historicalId)->fetchColumn() === 'disbursement',
        'legacy creation replay preserves the original category and expired deadline without migrating the saved ticket');
}
