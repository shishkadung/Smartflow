<?php
/** Only called inside the guarded disposable API harness. */
function smartflow_test_followup_integrity(PDO $pdo): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Follow-up integrity cases require the disposable database');
    }
    $tokens = []; $actors = [];
    $insert = $pdo->prepare('INSERT INTO users (name,username,password_hash,office_id,role) VALUES (?,?,?,?,?)');
    foreach ([['eng', 1, 'staff'], ['bud', 3, 'staff'], ['acc', 4, 'staff'], ['tre', 5, 'staff'],
        ['headeng', 1, 'head'], ['headbud', 3, 'head'], ['admin', 4, 'admin']] as [$name, $office, $role]) {
        $username = 'integrity_' . $name . '_' . bin2hex(random_bytes(3));
        $insert->execute(['Integrity ' . $name, $username, password_hash('test-password', PASSWORD_DEFAULT), $office, $role]);
        $actors[$name] = (int)$pdo->lastInsertId();
        [$http, $login] = api('auth-login.php', null, ['username' => $username, 'password' => 'test-password']);
        check($http === 200 && isset($login['token']), "independent $name integrity fixture signs in");
        $tokens[$name] = $login['token'];
    }
    smartflow_test_request_evidence($pdo, $tokens, $actors);
    smartflow_test_file_guards($pdo, $tokens, $actors);
    smartflow_test_deadline_guards($pdo, $tokens, $actors);
}

function smartflow_test_request_evidence(PDO $pdo, array $tokens, array $actors): void
{
    $create = static function(string $category = 'budget') use ($tokens): array {
        [$http, $data] = api('document-requests-create.php', $tokens['eng'], ['request_kind' => 'access',
            'document_category' => $category, 'purpose' => 'Complete request evidence fixture', 'required_by' => date('Y-m-d')]);
        check($http === 201, 'evidence fixture creates a genuinely unreviewed pending ticket');
        return $data['request'];
    };
    $update = static fn(string $who, array $request, string $action, string $notes = ''): array =>
        api('document-requests-update.php', $tokens[$who], ['request_id' => $request['id'], 'action' => $action,
            'expected_status' => $request['status'], 'expected_revision' => $request['revision'], 'review_notes' => $notes]);
    $longReview = str_repeat('Acceptance condition: check the signed supporting papers. ', 30) . 'END-REVIEW';
    $longClose = str_repeat('Closing explanation: all requested work was completed. ', 30) . 'END-CLOSE';
    $pending = $create();
    [$http, $accepted] = $update('bud', $pending, 'approve', $longReview);
    $review = $accepted['request'];
    check($http === 200 && $review['review_notes'] === $longReview && $review['review_notes_kind'] === 'review'
        && $review['reviewed_by'] === $actors['bud'] && $review['reviewed_office_id'] === 3
        && $review['reviewer']['user_id'] === $actors['bud'] && $review['reviewer']['office_code'] === 'BUD',
        'acceptance retains full long notes and recorded reviewer office evidence');
    [$http, $closed] = $update('admin', $review, 'fulfill', $longClose);
    $closed = $closed['request'];
    check($http === 200 && $closed['review_notes'] === $longReview && $closed['reviewed_at'] === $review['reviewed_at']
        && $closed['reviewed_by'] === $actors['bud'] && $closed['fulfilled_notes'] === $longClose
        && $closed['fulfilled_by'] === $actors['admin'] && $closed['fulfiller']['office_code'] === 'ACC'
        && $closed['review_notes_kind'] === 'review' && $closed['revision'] !== $review['revision'],
        'closing preserves the original review and separately stores full outcome notes actor time and revision');
    [$http, $listed] = api('document-requests-list.php?view=outbox&id=' . $closed['id'], $tokens['eng']);
    check($http === 200 && $listed['requests'][0] === $closed,
        'scoped exact listing returns the same complete decision evidence as the mutation response');
    $pdo->prepare('UPDATE users SET office_id=2 WHERE id IN (?,?)')->execute([$actors['bud'], $actors['admin']]);
    try {
        [$http, $movedActors] = api('document-requests-list.php?view=outbox&id=' . $closed['id'], $tokens['eng']);
        check($http === 200 && $movedActors['requests'][0]['reviewer']['office_code'] === 'BUD'
            && $movedActors['requests'][0]['fulfiller']['office_code'] === 'ACC',
            'review and completion offices remain historical snapshots after actor account moves');
    } finally {
        $pdo->prepare('UPDATE users SET office_id=3 WHERE id=?')->execute([$actors['bud']]);
        $pdo->prepare('UPDATE users SET office_id=4 WHERE id=?')->execute([$actors['admin']]);
    }
    $pending = $create(); [$http, $accepted] = $update('bud', $pending, 'approve', $longReview);
    $review = $accepted['request'];
    [$http, $cancelled] = $update('eng', $review, 'cancel', $longClose);
    $cancelled = $cancelled['request'];
    check($http === 200 && $cancelled['review_notes'] === $longReview && $cancelled['reviewed_at'] === $review['reviewed_at']
        && $cancelled['reviewed_by'] === $actors['bud'] && $cancelled['cancelled_notes'] === $longClose
        && $cancelled['cancelled_by'] === $actors['eng'] && $cancelled['canceller']['office_code'] === 'ENG'
        && $cancelled['cancelled_at'] !== null && $cancelled['review_notes_kind'] === 'review',
        'cancellation retains long acceptance notes reviewer and time separately from cancellation evidence');
    [$http, $direct] = $update('bud', $create(), 'fulfill');
    $direct = $direct['request'];
    check($http === 200 && $direct['reviewed_by'] === null && $direct['reviewed_at'] === null
        && $direct['reviewer'] === null && $direct['review_notes'] === null && $direct['fulfilled_notes'] === ''
        && $direct['review_notes_kind'] === 'review',
        'direct pending nonphysical completion stays unreviewed and records explicit empty closing notes');
    [$http, $cancelledPending] = $update('eng', $create(), 'cancel');
    check($http === 200 && $cancelledPending['request']['reviewer'] === null
        && $cancelledPending['request']['reviewed_at'] === null && $cancelledPending['request']['cancelled_notes'] === '',
        'pending cancellation does not invent a review or substitute cancellation text for review notes');
    $dv = $create('disbursement'); [$http, $acceptedDv] = $update('acc', $dv, 'approve', $longReview);
    [$http, $paid] = $update('tre', $acceptedDv['request'], 'fulfill');
    check($http === 200 && $paid['request']['review_notes'] === $longReview
        && $paid['request']['fulfilled_notes'] === 'Payment released at Treasury'
        && $paid['request']['reviewer']['office_code'] === 'ACC' && $paid['request']['fulfiller']['office_code'] === 'TRE',
        'default DV release note stays separate from Accounting review and Treasury actor evidence');
    foreach (['fulfilled', 'cancelled'] as $status) {
        $legacy = $create();
        $pdo->prepare('UPDATE document_requests SET status=?, reviewed_by=?, reviewed_at=NOW(), review_notes=? WHERE id=?')
            ->execute([$status, $actors['bud'], 'Old mixed terminal note', $legacy['id']]);
        [$http, $shown] = api('document-requests-list.php?view=outbox&id=' . $legacy['id'], $tokens['eng']);
        $shown = $shown['requests'][0];
        check($http === 200 && $shown['review_notes_kind'] === 'legacy' && $shown['review_notes'] === 'Old mixed terminal note'
            && $shown['reviewer']['office_id'] === null && $shown['reviewer']['office_code'] === null
            && $shown['fulfilled_notes'] === null && $shown['cancelled_notes'] === null
            && $shown['fulfiller'] === null && $shown['canceller'] === null,
            "$status legacy mixed notes remain marked unknown without guessed offices or outcome actors");
    }
    $pending = $create();
    $pdo->exec("CREATE TRIGGER test_evidence_audit_failure BEFORE INSERT ON audit_logs FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Injected isolated audit failure'");
    try {
        [$http, $accepted] = $update('bud', $pending, 'approve', $longReview);
        [$closedHttp, $durable] = $update('admin', $accepted['request'], 'fulfill', $longClose);
        check($http === 200 && $closedHttp === 200 && $durable['request']['review_notes'] === $longReview
            && $durable['request']['fulfilled_notes'] === $longClose && $durable['request']['reviewer']['office_code'] === 'BUD',
            'request decision evidence persists in the primary transaction even when auxiliary audit inserts fail');
    } finally { $pdo->exec('DROP TRIGGER test_evidence_audit_failure'); }
}

function smartflow_test_file_guards(PDO $pdo, array $tokens, array $actors): void
{
    [$http, $registered] = api('documents-create.php', $tokens['eng'], ['title' => 'Filing guard fixture',
        'type' => 'Others: Filing guard', 'origin_office_id' => 1]);
    check($http === 201, 'filing guard fixture registers at its actual office');
    $id = $registered['document']['id'];
    $latest = static function() use ($pdo, $id): int {
        $stmt = $pdo->prepare('SELECT id FROM movements WHERE document_id=? ORDER BY scanned_at DESC,id DESC LIMIT 1');
        $stmt->execute([$id]); return (int)$stmt->fetchColumn();
    };
    $old = $latest(); $body = ['document_id' => $id, 'expected_movement_id' => $old];
    $missing = $body; unset($missing['expected_movement_id']);
    check(api('documents-file.php', $tokens['eng'], $missing)[0] === 400,
        'filing requires the latest movement that the user reviewed');
    foreach ([null, false, 1.5, 0, -1, 'bad'] as $guard) {
        $invalid = $body; $invalid['expected_movement_id'] = $guard;
        check(api('documents-file.php', $tokens['eng'], $invalid)[0] === 400,
            'filing rejects null boolean fractional zero negative and malformed guards');
    }
    check(api('documents-file.php', null, $body)[0] === 401,
        'filing still requires an authenticated session');
    foreach (['admin', 'headeng'] as $who) {
        check(api('documents-file.php', $tokens[$who], $body)[0] === 403,
            "$who cannot file a physical folder");
    }
    check(api('documents-file.php', $tokens['bud'], $body)[0] === 409,
        'another staff office cannot file a folder that it does not hold');
    foreach ([['eng', 1, 'OUT', 3], ['bud', 3, 'IN', null], ['bud', 3, 'OUT', 1], ['eng', 1, 'IN', null]] as [$who, $office, $status, $destination]) {
        $move = ['document_id' => $id, 'office_id' => $office, 'status' => $status, 'movement_source' => 'system',
            'expected_movement_id' => $latest(), 'receipt_confirmed' => true];
        if ($destination !== null) $move['destination_office_id'] = $destination;
        if ($who === 'bud' && $status === 'OUT') { $move['is_return'] = true; $move['remarks'] = 'Return for the filing guard regression'; }
        check(api('movements-create.php', $tokens[$who], $move)[0] === 200, "filing custody cycle $who $status");
    }
    [$http, $denied] = api('documents-file.php', $tokens['eng'], $body);
    check($http === 409 && ($denied['file_error'] ?? '') === 'document_changed'
        && $pdo->query("SELECT filed_at FROM documents WHERE id=" . $pdo->quote($id))->fetchColumn() === null,
        'a stale File action is rejected after a send return and receipt cycle back to the same office');
    $body['expected_movement_id'] = (string)$latest();
    check(api('documents-file.php', $tokens['eng'], $body)[0] === 200,
        'current holding staff can file after review using a validated integer-string guard');
    check(api('documents-file.php', $tokens['eng'], $body)[0] === 409,
        'already filed folders cannot be filed again');
    [$http, $filedView] = api('documents-show.php?id=' . $id, $tokens['headeng']);
    $filer = $filedView['document']['filed_by'] ?? null;
    check($http === 200 && is_array($filer) && !empty($filer['filed_at']) && ($filer['office_code'] ?? '') === 'ENG'
        && !empty($filer['name']) && (int)($filer['user_id'] ?? 0) > 0,
        'a filed folder reports who filed it and when so History can show the final step');
    [$http, $unfiledView] = api('documents-show.php?id=' . $registered['document']['id'], $tokens['eng']);
    [$http2, $fresh] = api('documents-create.php', $tokens['eng'], ['title' => 'Unfiled payload fixture', 'type' => 'Others: Unfiled', 'origin_office_id' => 1]);
    [$http3, $freshView] = api('documents-show.php?id=' . ($fresh['document']['id'] ?? ''), $tokens['eng']);
    check($http === 200 && $http2 === 201 && $http3 === 200 && array_key_exists('filed_by', $freshView['document']) && $freshView['document']['filed_by'] === null,
        'an unfiled folder reports filed_by as null');
    $pdo->prepare('UPDATE documents SET filed_by=NULL WHERE id=?')->execute([$id]);
    [$http, $legacyView] = api('documents-show.php?id=' . $id, $tokens['headeng']);
    check($http === 200 && !empty($legacyView['document']['filed_by']['filed_at']) && $legacyView['document']['filed_by']['name'] === null,
        'a filing without a recorded filer still reports its time with a null name');
    [$http, $dv] = api('documents-create.php', $tokens['eng'], ['title' => 'Fixed-route filing guard',
        'type' => 'Disbursement Voucher', 'origin_office_id' => 1, 'reference_no' => 'ISOLATED', 'payee' => 'Fixture', 'fund_source' => 'Fixture']);
    $stmt = $pdo->prepare('SELECT id FROM movements WHERE document_id=? ORDER BY id DESC LIMIT 1');
    $stmt->execute([$dv['document']['id']]);
    check($http === 201 && api('documents-file.php', $tokens['eng'], ['document_id' => $dv['document']['id'],
        'expected_movement_id' => (int)$stmt->fetchColumn()])[0] === 409,
        'the displayed guard does not grant manual filing of a fixed-route DV');
}

function smartflow_test_deadline_guards(PDO $pdo, array $tokens, array $actors): void
{
    [$http, $registered] = api('documents-create.php', $tokens['bud'], ['title' => 'Deadline guard fixture',
        'type' => 'Others: Deadline guard', 'origin_office_id' => 3]);
    $id = $registered['document']['id'];
    $stmt = $pdo->prepare('SELECT id FROM movements WHERE document_id=? ORDER BY scanned_at DESC,id DESC LIMIT 1');
    $stmt->execute([$id]); $movement = (int)$stmt->fetchColumn();
    $body = ['document_id' => $id, 'due_at' => '2030-01-02', 'expected_movement_id' => $movement, 'expected_due_at' => null];
    foreach (['expected_movement_id', 'expected_due_at'] as $field) {
        $missing = $body; unset($missing[$field]);
        check(api('documents-update-due.php', $tokens['headbud'], $missing)[0] === 400,
            "deadline edits require the displayed $field guard");
    }
    foreach ([false, 1.5, -1, 'bad'] as $guard) {
        $invalid = $body; $invalid['expected_movement_id'] = $guard;
        check(api('documents-update-due.php', $tokens['headbud'], $invalid)[0] === 400,
            'deadline edits reject malformed displayed movement guards');
    }
    foreach (['', '2030-01-02', false] as $guard) {
        $invalid = $body; $invalid['expected_due_at'] = $guard;
        check(api('documents-update-due.php', $tokens['headbud'], $invalid)[0] === 400,
            'deadline edits require raw nullable saved datetime rather than guessed or normalized values');
    }
    check(api('documents-update-due.php', $tokens['bud'], $body)[0] === 403
        && api('documents-update-due.php', $tokens['headeng'], $body)[0] === 403,
        'deadline guards preserve head and own-latest-office authority');
    [$http, $set] = api('documents-update-due.php', $tokens['headbud'], $body);
    check($http === 200 && $set['document']['manual_due_at'] === '2030-01-02 23:59:59',
        'current office head can save a guarded date-only deadline through the end of its day');
    [$http, $shown] = api('documents-show.php?id=' . $id, $tokens['headbud']);
    [$queueHttp, $queue] = api('office-documents.php?id=' . $id, $tokens['headbud']);
    check($http === 200 && $queueHttp === 200 && $shown['document']['manual_due_at'] === '2030-01-02 23:59:59'
        && $queue['document']['manual_due_at'] === $shown['document']['manual_due_at'],
        'direct and office details expose the authoritative raw manual deadline for later guards');
    $staleDue = $body; $staleDue['due_at'] = '2030-01-03';
    [$http, $denied] = api('documents-update-due.php', $tokens['admin'], $staleDue);
    check($http === 409 && ($denied['deadline_error'] ?? '') === 'document_changed',
        'even an admin cannot overwrite a deadline changed since the displayed nullable value');
    $body['expected_due_at'] = '2030-01-02 23:59:59'; $body['due_at'] = null;
    [$http, $cleared] = api('documents-update-due.php', $tokens['admin'], $body);
    check($http === 200 && $cleared['document']['manual_due_at'] === null,
        'admin retains guarded global deadline clearing without storing the calculated fallback');
    check(api('movements-create.php', $tokens['bud'], ['document_id' => $id, 'office_id' => 3, 'status' => 'OUT',
        'destination_office_id' => 1, 'movement_source' => 'system', 'expected_movement_id' => $movement])[0] === 200,
        'deadline race fixture records a real OUT addressed to Engineering');
    $stmt->execute([$id]); $outId = (int)$stmt->fetchColumn();
    $body['expected_movement_id'] = (string)$outId; $body['expected_due_at'] = null; $body['due_at'] = '2030-01-04';
    [$http, $set] = api('documents-update-due.php', $tokens['headbud'], $body);
    check($http === 200, 'sending-office head retains the existing latest-acting-office policy while OUT is unreceived');
    $body['expected_due_at'] = $set['document']['manual_due_at']; $body['due_at'] = '2030-01-05';
    // Hold the custody lock, then start the real deadline endpoint before a concurrent receipt commits.
    $pdo->beginTransaction();
    $lock = $pdo->prepare('SELECT id FROM documents WHERE id=? FOR UPDATE'); $lock->execute([$id]);
    global $base;
    $curl = curl_init($base . '/documents-update-due.php');
    curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10, CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Authorization: Bearer ' . $tokens['headbud']],
        CURLOPT_POSTFIELDS => json_encode($body, JSON_THROW_ON_ERROR)]);
    $multi = curl_multi_init(); curl_multi_add_handle($multi, $curl);
    try {
        $until = microtime(true) + .35;
        do { curl_multi_exec($multi, $running); curl_multi_select($multi, .05); } while ($running && microtime(true) < $until);
        check($running === 1, 'deadline writer waits for the shared custody document lock');
        $pdo->prepare("INSERT INTO movements (document_id,office_id,status,user_id,remarks) VALUES (?,1,'IN',?,'Concurrent isolated receipt')")
            ->execute([$id, $actors['eng']]);
        $pdo->commit();
        do { curl_multi_exec($multi, $running); if ($running) curl_multi_select($multi, .05); } while ($running);
        $response = json_decode(curl_multi_getcontent($curl), true, 512, JSON_THROW_ON_ERROR);
        $http = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        check($http === 403 && $response['success'] === false,
            'after the concurrent receipt commits the old office head cannot change the now-foreign deadline');
    } finally {
        if ($pdo->inTransaction()) $pdo->rollBack();
        curl_multi_remove_handle($multi, $curl); curl_close($curl); curl_multi_close($multi);
    }
    $stmt->execute([$id]); $inId = (int)$stmt->fetchColumn();
    $saved = $pdo->prepare('SELECT due_at FROM documents WHERE id=?'); $saved->execute([$id]);
    check($saved->fetchColumn() === $body['expected_due_at'], 'the rejected old-head race preserves the authoritative saved deadline');
    $body['expected_movement_id'] = $outId;
    check(api('documents-update-due.php', $tokens['admin'], $body)[0] === 409,
        'admin deadline edits also reject stale movement IDs after receipt');
    $body['expected_movement_id'] = $inId;
    check(api('documents-update-due.php', $tokens['headeng'], $body)[0] === 200,
        'the new holding-office head can change the deadline after reviewing the new receipt');
    $legacyId = 'DOC-1870-' . bin2hex(random_bytes(3));
    $pdo->prepare('INSERT INTO documents (id,title,type,origin_office_id,created_by) VALUES (?,"Legacy deadline fixture","Others: Deadline",1,?)')->execute([$legacyId, $actors['eng']]);
    $legacy = ['document_id' => $legacyId, 'expected_movement_id' => 0, 'expected_due_at' => null, 'due_at' => '2030-01-02'];
    check(api('documents-update-due.php', $tokens['headeng'], $legacy)[0] === 403,
        'a legacy folder with no latest office grants no guessed head deadline authority');
    [$http, $set] = api('documents-update-due.php', $tokens['admin'], $legacy);
    check($http === 200 && $set['document']['manual_due_at'] === '2030-01-02 23:59:59',
        'admin can guard an explicitly reviewed legacy no-movement deadline with zero');
}
