<?php
/** Only called by the guarded disposable API regression harness. */
function smartflow_test_destination_corrections(PDO $pdo, array $tokens): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Destination correction tests require the disposable database');
    }
    [$http, $registered] = register('eng', 1, 'Others: Destination correction');
    check($http === 201, 'destination correction fixture registers at its actual sender');
    $id = $registered['document']['id'];
    $latest = static function(string $document) use ($pdo): array {
        $stmt = $pdo->prepare('SELECT * FROM movements WHERE document_id=? ORDER BY scanned_at DESC,id DESC LIMIT 1');
        $stmt->execute([$document]);
        return $stmt->fetch();
    };
    $movementBody = ['document_id' => $id, 'office_id' => 1, 'status' => 'OUT', 'destination_office_id' => 3,
        'movement_source' => 'system', 'expected_movement_id' => (int)$latest($id)['id'], 'request_id' => bin2hex(random_bytes(16))];
    [$http, $out] = api('movements-create.php', $tokens['eng'], $movementBody);
    check($http === 200, 'destination correction fixture records one real OUT');
    $original = $latest($id);
    $body = ['document_id' => $id, 'expected_movement_id' => (int)$original['id'], 'expected_destination_office_id' => 3,
        'expected_correction_id' => 0, 'destination_office_id' => 4, 'reason' => 'Selected Budget by mistake; actual receiving office is Accounting.',
        'correction_confirmed' => true, 'request_id' => bin2hex(random_bytes(16))];
    $correct = static fn(array $payload, string $who = 'eng'): array => api('movements-correct-destination.php', $tokens[$who], $payload);
    $next = static function(array $payload): array { $payload['request_id'] = bin2hex(random_bytes(16)); return $payload; };
    $movementCount = (int)$pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn();
    foreach (['head', 'admin', 'audit'] as $role) {
        [$http, $denied] = $correct($next($body), $role);
        check($http === 403 && ($denied['scan_error'] ?? '') === 'role_forbidden', "$role cannot correct a physical OUT destination");
    }
    check($correct($next($body), 'bud')[0] === 403, 'another office staff cannot correct the sender destination');
    foreach ([['correction_confirmed', false, 'confirmation_required'], ['reason', 'bad', 'correction_reason_required'],
        ['destination_office_id', 1, 'same_destination'], ['destination_office_id', 3, 'same_destination'],
        ['destination_office_id', 9999, 'destination_not_found'], ['expected_movement_id', (int)$original['id'] - 1, 'document_changed'],
        ['expected_destination_office_id', 5, 'document_changed'], ['expected_correction_id', 12345, 'document_changed']] as [$field, $value, $error]) {
        $invalid = $next($body); $invalid[$field] = $value;
        [$http, $denied] = $correct($invalid);
        check($http >= 400 && ($denied['scan_error'] ?? '') === $error, "destination correction validates $field ($error)");
    }
    $invalid = $next($body); unset($invalid['expected_correction_id']);
    check($correct($invalid)[0] === 400, 'destination correction requires its displayed correction revision');

    [$http, $saved] = $correct($body);
    check($http === 200 && $saved['movement_id'] === (int)$original['id'] && $saved['destination_office_id'] === 4 && $saved['correction_id'] > 0,
        'sending staff corrects the existing still-unreceived OUT destination');
    $changed = $latest($id); $before = $original; unset($changed['destination_office_id'], $before['destination_office_id']);
    check($changed === $before && (int)$pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn() === $movementCount,
        'correction preserves OUT ID/time/user/remarks/contents and inserts no IN or OUT');
    $stmt = $pdo->prepare('SELECT * FROM movement_destination_corrections WHERE id=?'); $stmt->execute([$saved['correction_id']]);
    $audit = $stmt->fetch();
    check($audit && $audit['reason'] === $body['reason'] && (int)$audit['previous_destination_office_id'] === 3
        && (int)$audit['destination_office_id'] === 4 && (int)$audit['corrected_by'] === 1 && (int)$audit['corrected_by_office_id'] === 1,
        'immutable correction evidence retains original/new destination, full reason and actor office');
    [$http, $replayed] = $correct($body);
    check($http === 200 && $replayed === $saved, 'same correction operation replays its exact saved response');
    [$http, $outcome] = api('movement-requests.php?request_id=' . $body['request_id'], $tokens['eng']);
    check($http === 200 && $outcome['state'] === 'recorded' && $outcome['result'] === $saved, 'a lost correction response is recoverable without another write');
    $changedBody = $body; $changedBody['reason'] = 'Different correction payload';
    check($correct($changedBody)[0] === 409, 'a correction operation cannot be reused with changed content');
    $collision = $body; $collision['request_id'] = $movementBody['request_id'];
    check($correct($collision)[0] === 409, 'correction cannot replay a normal movement operation');
    $collision = $body + ['office_id' => 1, 'status' => 'OUT', 'movement_source' => 'system'];
    $collision['_smartflow_operation'] = 'destination_correction';
    check(api('movements-create.php', $tokens['eng'], $collision)[0] === 409, 'normal movement cannot replay a correction operation even with its discriminator');
    foreach ([['bud', 0], ['acc', 1]] as [$who, $expected]) {
        [$http, $queue] = api("office-documents.php?limit=100&tray=incoming&search=$id", $tokens[$who]);
        check($http === 200 && $queue['total'] === $expected, "corrected destination updates $who incoming tray and count");
    }
    foreach ([['eng', true], ['admin', false], ['head', false]] as [$who, $allowed]) {
        [$http, $detail] = api("documents-show.php?id=$id", $tokens[$who]);
        check($http === 200 && $detail['document']['can_correct_destination'] === $allowed
            && $detail['document']['last_destination_correction_id'] === $saved['correction_id'] && count($detail['document']['destination_corrections']) === 1,
            "$who folder lookup exposes correction evidence with role-specific authority");
    }
    [$http, $detail] = api("office-documents.php?id=$id", $tokens['eng']);
    $outSteps = array_values(array_filter($detail['document']['journey'], static fn(array $step): bool => $step['status'] === 'OUT'));
    check($http === 200 && $detail['document']['can_correct_destination'] && count($outSteps) === 1
        && $outSteps[0]['destination_office_code'] === 'ACC' && $outSteps[0]['destination_corrections'][0]['reason'] === $body['reason'],
        'operational folder journey shows the corrected destination and its full audit reason');
    [$http, $history] = api("documents-movements.php?id=$id", $tokens['admin']);
    check($http === 200 && count($history['movements']) === 2 && count($history['movements'][1]['destination_corrections']) === 1,
        'document history preserves two physical events and attaches the correction to its OUT');
    [$http, $history] = api('office-movements-list.php?office_id=1&date=' . date('Y-m-d') . '&page_size=100', $tokens['eng']);
    $found = array_values(array_filter($history['movements'], static fn(array $row): bool => (int)$row['id'] === (int)$original['id']));
    check($http === 200 && count($found) === 1 && count($found[0]['destination_corrections']) === 1, 'complete office history includes the OUT correction audit');

    $back = $next($body); $back['expected_destination_office_id'] = 4; $back['expected_correction_id'] = $saved['correction_id']; $back['destination_office_id'] = 3;
    [$http, $backSaved] = $correct($back);
    check($http === 200, 'a later reviewed correction can change the still-unreceived OUT again');
    check($correct($next($body))[0] === 409, 'returning to the same destination cannot make an old correction revision current');
    $again = $next($body); $again['expected_correction_id'] = $backSaved['correction_id'];
    [$http, $finalCorrection] = $correct($again);
    check($http === 200, 'the latest displayed correction revision can update the destination');
    $receive = ['document_id' => $id, 'office_id' => 3, 'status' => 'IN', 'movement_source' => 'system',
        'receipt_confirmed' => true, 'expected_movement_id' => (int)$original['id']];
    [$http, $denied] = api('movements-create.php', $tokens['bud'], $receive);
    check($http === 409 && ($denied['scan_error'] ?? '') === 'wrong_receiver', 'the original mistaken destination cannot receive after correction');
    $receive['office_id'] = 4;
    check(api('movements-create.php', $tokens['acc'], $receive)[0] === 200, 'the corrected receiving office can confirm the actual IN');
    $afterReceipt = $next($again); $afterReceipt['expected_correction_id'] = $finalCorrection['correction_id'];
    check($correct($afterReceipt)[0] === 409, 'a received OUT can no longer have its destination corrected');
    check($correct($again) === [200, $finalCorrection], 'a committed correction remains recoverable after the actual receipt');

    smartflow_test_correction_rollback_and_routes($pdo, $tokens, $latest);
}

function smartflow_test_correction_rollback_and_routes(PDO $pdo, array $tokens, callable $latest): void
{
    [$http, $registered] = register('eng', 1, 'Others: Correction rollback');
    $id = $registered['document']['id'];
    $send = ['document_id' => $id, 'office_id' => 1, 'status' => 'OUT', 'destination_office_id' => 3,
        'remarks' => 'Returned to text supplied on an ordinary forward', 'movement_source' => 'system', 'expected_movement_id' => (int)$latest($id)['id']];
    check(api('movements-create.php', $tokens['eng'], $send)[0] === 200, 'ordinary OUT fixture uses an authoritative nonreturn flag');
    $out = $latest($id);
    $body = ['document_id' => $id, 'expected_movement_id' => (int)$out['id'], 'expected_destination_office_id' => 3,
        'expected_correction_id' => 0, 'destination_office_id' => 2, 'reason' => 'Fixing the recorded receiving department.',
        'correction_confirmed' => true, 'request_id' => bin2hex(random_bytes(16))];
    $cancel = $body; $cancel['request_id'] = bin2hex(random_bytes(16));
    check(api('movement-requests.php', $tokens['eng'], ['request_id' => $cancel['request_id'], 'document_id' => $id, 'action' => 'cancel'])[0] === 200
        && api('movements-correct-destination.php', $tokens['eng'], $cancel)[0] === 409, 'a cancelled destination correction cannot arrive late');
    $before = (int)$pdo->query('SELECT COUNT(*) FROM movement_destination_corrections')->fetchColumn();
    $pdo->exec("CREATE TRIGGER test_correction_failure BEFORE INSERT ON movement_destination_corrections FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Injected correction failure'");
    try { [$http] = api('movements-correct-destination.php', $tokens['eng'], $body); }
    finally { $pdo->exec('DROP TRIGGER test_correction_failure'); }
    $operation = $pdo->prepare('SELECT COUNT(*) FROM movement_requests WHERE request_id=?'); $operation->execute([$body['request_id']]);
    check($http === 500 && (int)$latest($id)['destination_office_id'] === 3 && (int)$operation->fetchColumn() === 0
        && $before === (int)$pdo->query('SELECT COUNT(*) FROM movement_destination_corrections')->fetchColumn(),
        'correction failure rolls back effective destination, audit evidence and recovery reservation');
    check(api('movements-correct-destination.php', $tokens['eng'], $body)[0] === 200,
        'explicit retry succeeds after rollback and new normal OUT ignores return-like custom remarks');

    [$http, $registered] = register('eng', 1, 'Others: Corrected return');
    $id = $registered['document']['id'];
    foreach ([['eng', 1, 'OUT', 4], ['acc', 4, 'IN', null], ['acc', 4, 'OUT', 3], ['bud', 3, 'IN', null], ['bud', 3, 'OUT', 1]] as [$who, $office, $status, $destination]) {
        $move = ['document_id' => $id, 'office_id' => $office, 'status' => $status, 'movement_source' => 'system',
            'expected_movement_id' => (int)$latest($id)['id']];
        if ($destination !== null) $move['destination_office_id'] = $destination;
        if ($status === 'IN') $move['receipt_confirmed'] = true;
        if ($who === 'bud' && $status === 'OUT') { $move['is_return'] = true; $move['remarks'] = 'Missing a required supporting paper'; }
        check(api('movements-create.php', $tokens[$who], $move)[0] === 200, "correction return fixture $who $status");
    }
    $out = $latest($id);
    $body = ['document_id' => $id, 'expected_movement_id' => (int)$out['id'], 'expected_destination_office_id' => 1,
        'expected_correction_id' => 0, 'destination_office_id' => 2, 'reason' => 'Correcting the recorded return destination.',
        'correction_confirmed' => true, 'request_id' => bin2hex(random_bytes(16))];
    [$http, $denied] = api('movements-correct-destination.php', $tokens['bud'], $body);
    check($http === 400 && ($denied['scan_error'] ?? '') === 'return_not_previous_holder', 'correcting a return cannot address an office with no prior receipt');
    $pdo->prepare('UPDATE movements SET is_return=NULL WHERE id=?')->execute([$out['id']]);
    $body['request_id'] = bin2hex(random_bytes(16));
    check(api('movements-correct-destination.php', $tokens['bud'], $body)[0] === 400, 'legacy return remarks preserve the prior-holder restriction');
    $body['destination_office_id'] = 4; $body['request_id'] = bin2hex(random_bytes(16));
    check(api('movements-correct-destination.php', $tokens['bud'], $body)[0] === 200, 'a corrected return may target another actual prior holder');

    [$http, $registered] = register('tre', 5, 'Disbursement Voucher');
    $id = $registered['document']['id'];
    $pdo->prepare("INSERT INTO movements (document_id,office_id,status,user_id,scanned_at) VALUES (?,6,'IN',8,DATE_SUB(NOW(),INTERVAL 2 MINUTE))")->execute([$id]);
    $send = ['document_id' => $id, 'office_id' => 5, 'status' => 'OUT', 'destination_office_id' => 4,
        'movement_source' => 'system', 'expected_movement_id' => (int)$latest($id)['id']];
    check(api('movements-create.php', $tokens['tre'], $send)[0] === 200, 'completed DV retains its optional real Treasury to Accounting OUT');
    $body = ['document_id' => $id, 'expected_movement_id' => (int)$latest($id)['id'], 'expected_destination_office_id' => 4,
        'expected_correction_id' => 0, 'destination_office_id' => 3, 'reason' => 'Attempting another completed route destination.',
        'correction_confirmed' => true, 'request_id' => bin2hex(random_bytes(16))];
    [$http, $denied] = api('movements-correct-destination.php', $tokens['tre'], $body);
    check($http === 409 && ($denied['scan_error'] ?? '') === 'route_finished', 'destination correction cannot reopen the completed DV route away from Accounting');
}
