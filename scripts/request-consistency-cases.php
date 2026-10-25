<?php
/** Additional API regressions; call only from the disposable test-request-linking harness. */
function smartflow_test_request_consistency(PDO $pdo, array $tokens): void
{
    $database = (string)$pdo->query('SELECT DATABASE()')->fetchColumn();
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/', $database)) {
        throw new RuntimeException('Request consistency cases require the disposable harness database');
    }
    $snapshot = static function (int $id) use ($pdo): array {
        $stmt = $pdo->prepare('SELECT * FROM document_requests WHERE id = ?');
        $stmt->execute([$id]);
        return $stmt->fetch();
    };
    $update = static function (string $actor, int $id, string $action, array $extra = []) use ($tokens): array {
        return api('document-requests-update.php', $tokens[$actor], array_merge([
            'request_id' => $id, 'action' => $action,
        ], $extra));
    };

    $request = requestFixture(status: 'pending');
    $original = $snapshot($request);
    [$http, $accepted] = $update('bud', $request, 'approve', [
        'expected_status' => 'pending', 'expected_revision' => smartflow_request_revision($original),
        'review_notes' => 'Accepted after checking the full purpose',
    ]);
    check($http === 200 && preg_match('/^[a-f0-9]{64}$/', $accepted['request']['revision']),
        'request decisions return an opaque revision for stale-view protection');
    [$http, $stale] = $update('eng', $request, 'cancel', ['expected_status' => 'pending']);
    check($http === 409 && ($stale['request_error'] ?? '') === 'request_conflict'
        && $snapshot($request)['status'] === 'approved',
        'cancellation from an outdated pending view cannot overwrite acceptance');
    check($snapshot($request)['review_notes'] === 'Accepted after checking the full purpose',
        'a stale request decision preserves the newer reviewer note');
    check($update('bud', $request, 'reject', ['review_notes' => 'Late decline'])[0] === 409,
        'legacy decline cannot overwrite an already accepted request');
    check($update('eng', $request, 'cancel', [
        'expected_status' => 'approved', 'expected_revision' => $accepted['request']['revision'],
    ])[0] === 200, 'a requester can cancel acceptance after reviewing the current state');
    check($update('bud', $request, 'fulfill')[0] === 409
        && $snapshot($request)['status'] === 'cancelled', 'legacy completion cannot overwrite cancellation');

    $declined = requestFixture(status: 'pending');
    check($update('bud', $declined, 'reject', ['review_notes' => 'Signed supporting papers are missing'])[0] === 200
        && $update('bud', $declined, 'approve')[0] === 409
        && $snapshot($declined)['review_notes'] === 'Signed supporting papers are missing',
        'a later acceptance cannot erase a recorded decline and its reason');
    check($update('bud', $declined, 'approve', ['expected_revision' => 'bad-revision'])[0] === 400,
        'malformed request revision guards are rejected');

    [$http, $budget] = register('bud', 3, 'Approved Budget');
    check($http === 201, 'request consistency budget evidence fixture registers');
    $budgetId = $budget['document']['id'];
    [$http, $other] = register('bud', 3, 'Others: Request consistency');
    check($http === 201, 'request consistency other-category evidence fixture registers');
    $otherId = $other['document']['id'];
    [$http, $outside] = register('acc', 4, 'Approved Budget');
    check($http === 201, 'request consistency unrelated-office evidence fixture registers');

    $wrongCategory = requestFixture();
    [$http, $response] = $update('bud', $wrongCategory, 'fulfill', ['related_document_id' => $otherId]);
    check($http === 400
        && $snapshot($wrongCategory)['status'] === 'approved'
        && $snapshot($wrongCategory)['related_document_id'] === null,
        'closing cannot introduce a category-incompatible folder link' . ($http === 400 ? '' : " (HTTP $http: " . ($response['message'] ?? 'no message') . ')'));
    $wrongHistory = requestFixture();
    check($update('bud', $wrongHistory, 'fulfill', ['related_document_id' => $outside['document']['id']])[0] === 403
        && $snapshot($wrongHistory)['status'] === 'approved',
        'closing cannot link a folder the handler has never registered or handled');
    $pendingLink = requestFixture(status: 'pending');
    check($update('bud', $pendingLink, 'fulfill', ['related_document_id' => $budgetId])[0] === 409
        && $snapshot($pendingLink)['related_document_id'] === null,
        'pending completion cannot bypass acceptance required for a new physical-folder link');
    check($update('bud', $pendingLink, 'fulfill')[0] === 200,
        'pending nonphysical request completion remains supported without a folder');

    $linked = requestFixture();
    $beforeLink = smartflow_request_revision($snapshot($linked));
    check(linkRequest('bud', $linked, $budgetId)[0] === 200, 'accepted request links compatible handler evidence');
    check($update('bud', $linked, 'fulfill', ['expected_status' => 'approved', 'expected_revision' => $beforeLink])[0] === 409
        && $snapshot($linked)['status'] === 'approved',
        'revision protection detects a new link even when the accepted status stays unchanged');
    check($update('bud', $linked, 'fulfill', ['related_document_id' => $otherId])[0] === 409
        && $snapshot($linked)['related_document_id'] === $budgetId,
        'closing cannot replace existing folder evidence');

    [$http, $dv] = register('acc', 4, 'Disbursement Voucher');
    check($http === 201, 'request consistency DV evidence fixture registers');
    $dvId = $dv['document']['id'];
    $dvRequest = requestFixture(handler: 4, category: 'disbursement');
    $movementsBefore = (int)$pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn();
    check($update('tre', $dvRequest, 'fulfill', ['related_document_id' => $dvId])[0] === 403
        && $snapshot($dvRequest)['status'] === 'approved',
        'Treasury cannot introduce Accounting folder evidence through payment release');
    check(linkRequest('acc', $dvRequest, $dvId)[0] === 200, 'Accounting links the accepted DV evidence');
    [$http, $closed] = $update('tre', $dvRequest, 'fulfill', [
        'related_document_id' => $dvId, 'expected_status' => 'approved',
        'expected_revision' => smartflow_request_revision($snapshot($dvRequest)),
        'review_notes' => 'Payment release recorded by Treasury',
    ]);
    check($http === 200 && $closed['request']['related_document_id'] === $dvId,
        'Treasury can release an accepted DV with the existing validated Accounting link');
    $closedRow = $snapshot($dvRequest);
    check((int)$closedRow['reviewed_by'] === 2 && (int)$closedRow['fulfilled_by'] === 4
        && (int)$closedRow['fulfilled_office_id'] === 5,
        'request closure preserves the reviewer and separately records closer and historical office');
    check($closedRow['review_notes'] === 'Original acceptance' && $closedRow['fulfilled_notes'] === 'Payment release recorded by Treasury'
        && (int)$pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn() === $movementsBefore,
        'closing retains full notes without inventing physical custody movements');
    check($update('eng', $dvRequest, 'cancel')[0] === 409
        && $snapshot($dvRequest)['status'] === 'fulfilled', 'closed requests cannot be overwritten by later cancellation');

    $adminDv = requestFixture(handler: 4, category: 'disbursement');
    check($update('admin', $adminDv, 'fulfill', ['related_document_id' => $dvId])[0] === 200
        && (int)$snapshot($adminDv)['fulfilled_by'] === 5,
        'admin DV completion retains compatible-folder checks and separate closer evidence');
    $invalidExisting = requestFixture();
    $pdo->prepare('UPDATE document_requests SET related_document_id = ? WHERE id = ?')->execute([$otherId, $invalidExisting]);
    check($update('bud', $invalidExisting, 'fulfill')[0] === 400
        && $snapshot($invalidExisting)['status'] === 'approved',
        'completion rejects incompatible legacy links rather than endorsing them');
}
