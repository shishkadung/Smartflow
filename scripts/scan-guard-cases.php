<?php
/** Scanner movement guards run only inside the disposable API regression harness. */
function smartflow_test_scan_guards(PDO $pdo, array $tokens): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Scan guard tests require the disposable database');
    }
    // Independent actors keep this movement-cycle scenario within normal per-user rate limits.
    $actors = $tokens;
    $actor = $pdo->prepare('INSERT INTO users (name,username,password_hash,office_id,role) VALUES (?,?,?,? ,"staff")');
    foreach (['eng' => 1, 'bud' => 3, 'acc' => 4, 'hr' => 2] as $office => $officeId) {
        $username = 'scan_guard_' . $office . '_' . bin2hex(random_bytes(3));
        $actor->execute(['Scan guard fixture', $username, password_hash('test-password', PASSWORD_DEFAULT), $officeId]);
        [$http, $login] = api('auth-login.php', null, ['username' => $username, 'password' => 'test-password']);
        check($http === 200 && isset($login['token']), "independent $office Scan guard fixture signs in");
        $actors[$office] = $login['token'];
    }
    [$http, $registered] = api('documents-create.php', $actors['eng'],
        ['title' => 'Scan guard fixture', 'type' => 'Others: Scan guards', 'origin_office_id' => 1]);
    check($http === 201, 'scan guard fixture registers at its physical Engineering holder');
    $id = $registered['document']['id'];
    $latest = static function() use ($pdo, $id): int {
        $stmt = $pdo->prepare('SELECT id FROM movements WHERE document_id=? ORDER BY scanned_at DESC,id DESC LIMIT 1');
        $stmt->execute([$id]);
        return (int)$stmt->fetchColumn();
    };
    $count = static function() use ($pdo, $id): int {
        $stmt = $pdo->prepare('SELECT COUNT(*) FROM movements WHERE document_id=?');
        $stmt->execute([$id]);
        return (int)$stmt->fetchColumn();
    };
    $scan = ['document_id' => $id, 'office_id' => 1, 'status' => 'OUT', 'destination_office_id' => 3,
        'movement_source' => 'scan', 'scan_started_at' => date('Y-m-d H:i:s'),
        'qr_payload' => $registered['document']['qr_payload'], 'expected_movement_id' => $latest(),
        'request_id' => bin2hex(random_bytes(16))];
    $missing = $scan; unset($missing['expected_movement_id']);
    [$http, $denied] = api('movements-create.php', $actors['eng'], $missing);
    check($http === 400 && ($denied['scan_error'] ?? '') === 'confirmation_required' && $count() === 1,
        'Scan cannot omit the movement that was displayed to the user');
    foreach ([null, -1, 'bad', true, 1.5] as $invalidId) {
        $invalid = $scan; $invalid['expected_movement_id'] = $invalidId;
        [$http, $denied] = api('movements-create.php', $actors['eng'], $invalid);
        check($http === 400 && ($denied['scan_error'] ?? '') === 'confirmation_required' && $count() === 1,
            'Scan rejects malformed displayed-movement guards without recording a handoff (HTTP ' . $http . ', ' . ($denied['scan_error'] ?? 'no scan error') . ')');
    }
    $zero = $scan; $zero['expected_movement_id'] = 0;
    [$http, $denied] = api('movements-create.php', $actors['eng'], $zero);
    check($http === 409 && ($denied['scan_error'] ?? '') === 'document_changed' && $count() === 1,
        'zero cannot bypass a Scan guard when a registered movement already exists');

    [$http, $sent] = api('movements-create.php', $actors['eng'], $scan);
    check($http === 200 && $count() === 2, 'a reviewed Scan records one OUT with its exact displayed movement');
    $receive = ['document_id' => $id, 'office_id' => 2, 'status' => 'IN', 'movement_source' => 'scan',
        'scan_started_at' => $scan['scan_started_at'], 'expected_movement_id' => $latest(), 'receipt_confirmed' => true];
    [$http, $wrong] = api('movements-create.php', $actors['hr'], $receive);
    check($http === 409 && ($wrong['scan_error'] ?? '') === 'wrong_receiver' && $count() === 2,
        'a current Scan guard does not grant receipt to an office other than the destination');
    $receive['office_id'] = 3;
    check(api('movements-create.php', $actors['bud'], $receive)[0] === 200,
        'the addressed office can receive the reviewed Scan OUT');
    $return = ['document_id' => $id, 'office_id' => 3, 'status' => 'OUT', 'movement_source' => 'scan',
        'scan_started_at' => $scan['scan_started_at'], 'expected_movement_id' => $latest(),
        'destination_office_id' => 1, 'is_return' => true, 'remarks' => 'Return for the scan cycle regression'];
    check(api('movements-create.php', $actors['bud'], $return)[0] === 200,
        'Scan can return a folder to its actual previous holder after reviewing its new receipt');
    $receive['office_id'] = 1; $receive['expected_movement_id'] = $latest();
    check(api('movements-create.php', $actors['eng'], $receive)[0] === 200,
        'the Scan cycle returns to Engineering IN within the original scan timestamp window');
    $before = $count();
    $stale = $scan; $stale['request_id'] = bin2hex(random_bytes(16));
    [$http, $denied] = api('movements-create.php', $actors['eng'], $stale);
    check($http === 409 && ($denied['scan_error'] ?? '') === 'document_changed' && $count() === $before,
        'an intervening send receive and return cycle rejects an old Scan despite matching office IN state');
    [$http, $outcome] = api('movement-requests.php?request_id=' . $stale['request_id'], $actors['eng']);
    check($http === 200 && $outcome['state'] === 'unknown' && $outcome['result'] === null,
        'a rejected stale Scan leaves no false recorded recovery outcome');
    unset($stale['movement_source']); $stale['request_id'] = bin2hex(random_bytes(16));
    [$http, $denied] = api('movements-create.php', $actors['eng'], $stale);
    check($http === 409 && ($denied['scan_error'] ?? '') === 'document_changed' && $count() === $before,
        'omitting the Scan source cannot bypass the displayed-movement comparison');
    [$http, $replayed] = api('movements-create.php', $actors['eng'], $scan);
    check($http === 200 && $replayed === $sent && $count() === $before,
        'a recorded Scan operation still replays its saved outcome after later movements without another OUT');

    $reviewed = $scan; $reviewed['expected_movement_id'] = $latest(); $reviewed['request_id'] = bin2hex(random_bytes(16));
    [$http] = api('movements-create.php', $actors['eng'], $reviewed);
    check($http === 200, 'a newly reviewed Scan can send again after the intervening cycle');
    $outId = $latest(); $before = $count();
    $correction = ['document_id' => $id, 'expected_movement_id' => $outId, 'expected_destination_office_id' => 3,
        'expected_correction_id' => 0, 'destination_office_id' => 4, 'reason' => 'Correct receiving office after the Scan send',
        'correction_confirmed' => true, 'request_id' => bin2hex(random_bytes(16))];
    check(api('movements-correct-destination.php', $actors['eng'], $correction)[0] === 200
        && $latest() === $outId && $count() === $before,
        'destination correction preserves the reviewed OUT identity and physical movement count');
    $receive['office_id'] = 3; $receive['expected_movement_id'] = $outId;
    [$http, $denied] = api('movements-create.php', $actors['bud'], $receive);
    check($http === 409 && ($denied['scan_error'] ?? '') === 'wrong_receiver' && $count() === $before,
        'the original destination cannot receive a corrected OUT even when its movement ID is unchanged');
    $receive['office_id'] = 4;
    check(api('movements-create.php', $actors['acc'], $receive)[0] === 200 && $count() === $before + 1,
        'the corrected destination can record the actual Scan receipt after reviewing the effective OUT');

    // Historical tracked folders can exist without a movement; zero means that exact displayed absence.
    $legacyId = 'DOC-1880-' . bin2hex(random_bytes(3));
    $pdo->prepare('INSERT INTO documents (id,title,type,origin_office_id,created_by) VALUES (?,"Legacy no-movement Scan fixture","Others: Scan guard",1,1)')->execute([$legacyId]);
    $legacy = ['document_id' => $legacyId, 'office_id' => 1, 'status' => 'IN', 'movement_source' => 'system',
        'expected_movement_id' => 0, 'receipt_confirmed' => true];
    check(api('movements-create.php', $actors['eng'], $legacy)[0] === 400,
        'system receipt retains its positive displayed-movement requirement');
    $legacy['movement_source'] = 'scan';
    check(api('movements-create.php', $actors['eng'], $legacy)[0] === 200,
        'Scan preserves an explicit reviewed no-movement legacy receipt with guard zero');
    [$http, $denied] = api('movements-create.php', $actors['eng'], $legacy);
    check($http === 409 && ($denied['scan_error'] ?? '') === 'document_changed',
        'a later first movement invalidates the displayed no-movement Scan guard');
}
