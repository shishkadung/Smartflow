<?php
/**
 * Focused office-to-office technical rehearsal using unchanged copied endpoints.
 * Set TEST_DB_HOST explicitly, then run: C:\xampp\php\php.exe scripts\test-office-pilot.php
 * TEST_DB_USER / TEST_DB_PASS are optional fixture connection settings.
 * The shared fixture creates and drops only its own generated disposable schema;
 * no operational configuration, records, sessions, QR keys or uploads are copied.
 * This is API evidence, not protected-device, camera, hosting or municipal UAT.
 */
declare(strict_types=1);

require __DIR__ . '/stabilization-test-helper.php';
date_default_timezone_set('Asia/Manila');

final class SmartflowOfficePilot
{
    private array $offices = [];
    private array $tokens = [];
    private array $actors = [];

    public function __construct(private SmartflowStabilizationFixture $fixture) {}

    private function check(bool $passed, string $message): void
    {
        $this->fixture->check($passed, $message);
    }

    private function api(string $path, ?string $actor = null, ?array $body = null, int $expected = 200): array
    {
        [$status, $result] = $this->fixture->call($path, $actor === null ? null : $this->tokens[$actor], $body);
        if ($status !== $expected || !is_array($result) || ($result['success'] ?? false) !== ($expected < 400)) {
            // Do not dump authentication responses or endpoint logs on failure.
            throw new RuntimeException("Pilot endpoint $path returned HTTP $status; expected $expected");
        }
        return $result;
    }

    private function document(string $id, string $actor): array
    {
        $result = $this->api('documents-show.php?id=' . rawurlencode($id), $actor);
        $document = $result['document'] ?? [];
        if (($document['id'] ?? null) !== $id || (int)($document['last_movement_id'] ?? 0) <= 0) {
            throw new RuntimeException('Pilot detail did not return the exact folder and a positive reviewed movement');
        }
        return $document;
    }

    private function ticket(int $id, string $actor, string $view): array
    {
        $result = $this->api('document-requests-list.php?' . http_build_query(['view' => $view, 'id' => $id]), $actor);
        $requests = $result['requests'] ?? [];
        if (count($requests) !== 1 || ($requests[0]['id'] ?? null) !== $id
            || !preg_match('/^[a-f0-9]{64}$/D', (string)($requests[0]['revision'] ?? ''))) {
            throw new RuntimeException('Pilot exact-ticket read did not return its scoped request and revision');
        }
        return $requests[0];
    }

    private function movementCount(string $id): int
    {
        $query = $this->fixture->db->prepare('SELECT COUNT(*) FROM movements WHERE document_id=?');
        $query->execute([$id]);
        return (int)$query->fetchColumn();
    }

    /** Business state excludes audit/session records legitimately touched by reads and denials. */
    private function businessState(): string
    {
        $tables = [
            'SELECT id,title,type,origin_office_id,filed_at FROM documents ORDER BY id',
            'SELECT id,document_id,office_id,destination_office_id,status,user_id,remarks,contents_receipt,is_return FROM movements ORDER BY id',
            'SELECT id,status,related_document_id,reviewed_by,reviewed_at,review_notes,fulfilled_by,fulfilled_at,fulfilled_notes,cancelled_by,cancelled_at,cancelled_notes FROM document_requests ORDER BY id',
        ];
        $rows = [];
        foreach ($tables as $sql) $rows[] = $this->fixture->db->query($sql)->fetchAll();
        return hash('sha256', json_encode($rows, JSON_THROW_ON_ERROR));
    }

    private function inventory(): array
    {
        return ['count_confirmed' => true, 'items' => [
            ['pages' => 2], ['name' => 'Synthetic supporting sheet', 'pages' => 3, 'required' => true],
        ]];
    }

    private function receipt(array $inventory): array
    {
        return ['confirmed' => true, 'items' => array_map(
            static fn(array $item): array => ['id' => $item['id'], 'pages' => $item['pages']], $inventory['items']), 'reason' => ''];
    }

    private function createRequest(array $body): array
    {
        $body += ['operation_id' => bin2hex(random_bytes(16)), 'required_by' => date('Y-m-d')];
        $before = (int)$this->fixture->db->query('SELECT COUNT(*) FROM movements')->fetchColumn();
        $created = $this->api('document-requests-create.php', 'eng', $body, 201);
        $request = $created['request'];
        $recovered = $this->api('creation-requests.php?' . http_build_query([
            'kind' => 'request', 'operation_id' => $body['operation_id'],
        ]), 'eng');
        $replayed = $this->api('document-requests-create.php', 'eng', $body, 201);
        $this->check($request['status'] === 'pending' && !$request['is_overdue']
            && $request['purpose'] === $body['purpose'] && $request['required_by'] === $body['required_by']
            && $recovered['state'] === 'recorded' && $recovered['result'] === $created && $replayed === $created
            && (int)$this->fixture->db->query('SELECT COUNT(*) FROM movements')->fetchColumn() === $before,
            'request creation, recovery and same-operation replay preserve full purpose, due day and custody');
        return $request;
    }

    private function register(string $actor, string $type, ?int $requestId = null): array
    {
        $body = ['operation_id' => bin2hex(random_bytes(16)), 'title' => 'Synthetic office pilot ' . $type,
            'type' => $type, 'origin_office_id' => $this->offices[strtoupper($actor)],
            'folder_inventory' => $this->inventory(), 'description' => 'Synthetic technical rehearsal; no operational transaction.'];
        if ($type === 'Disbursement Voucher') $body += [
            'reference_no' => 'SYNTHETIC-PILOT-DV', 'payee' => 'Synthetic pilot payee', 'fund_source' => 'Synthetic pilot fund',
        ];
        if ($requestId !== null) $body['request_id'] = $requestId;
        $before = (int)$this->fixture->db->query('SELECT COUNT(*) FROM documents')->fetchColumn();
        $created = $this->api('documents-create.php', $actor, $body, 201);
        $id = $created['document']['id'];
        $recovered = $this->api('creation-requests.php?' . http_build_query([
            'kind' => 'document', 'operation_id' => $body['operation_id'],
        ]), $actor);
        $replayed = $this->api('documents-create.php', $actor, $body, 201);
        $this->check($created['document']['initial_in_recorded'] === true && $this->movementCount($id) === 1
            && (int)$this->fixture->db->query('SELECT COUNT(*) FROM documents')->fetchColumn() === $before + 1
            && $recovered['state'] === 'recorded' && $recovered['result'] === $created && $replayed === $created,
            "$actor registration and recovery create exactly one holder-office folder and initial IN");
        $detail = $this->document($id, $actor);
        $this->check($detail['current_status'] === 'IN' && $detail['current_office_code'] === strtoupper($actor)
            && $detail['folder_inventory']['total_pages'] === 5 && $detail['contents_status'] === 'complete',
            "$actor registration retains the counted main document and named attachment");
        $state = $this->businessState();
        $verified = $this->api('qr-verify.php', $actor, ['qr' => $created['document']['qr_payload']]);
        $this->document($id, $actor);
        $this->api('documents-movements.php?id=' . rawurlencode($id), $actor);
        $this->check($verified['document_id'] === $id && $this->businessState() === $state,
            'QR verification, exact-ID detail and history lookup leave custody and request state unchanged');
        return $detail;
    }

    private function decide(string $actor, array $reviewed, string $action, string $notes = '', ?string $document = null): array
    {
        $before = (int)$this->fixture->db->query('SELECT COUNT(*) FROM movements')->fetchColumn();
        $body = ['request_id' => $reviewed['id'], 'action' => $action, 'expected_status' => $reviewed['status'],
            'expected_revision' => $reviewed['revision'], 'review_notes' => $notes];
        if ($document !== null) $body['related_document_id'] = $document;
        $result = $this->api('document-requests-update.php', $actor, $body);
        $this->check((int)$this->fixture->db->query('SELECT COUNT(*) FROM movements')->fetchColumn() === $before,
            "$actor request $action uses the reviewed status/revision and adds no physical movement");
        return $result['request'];
    }

    private function move(string $actor, string $id, string $status, ?string $destination = null, bool $replay = false): array
    {
        $reviewed = $this->document($id, $actor);
        $before = $this->movementCount($id);
        $body = ['request_id' => bin2hex(random_bytes(16)), 'document_id' => $id,
            'office_id' => $this->offices[strtoupper($actor)], 'status' => $status,
            'movement_source' => 'system', 'expected_movement_id' => $reviewed['last_movement_id']];
        if ($destination !== null) $body['destination_office_id'] = $this->offices[$destination];
        if ($status === 'IN') $body += ['receipt_confirmed' => true, 'contents_receipt' => $this->receipt($reviewed['folder_inventory'])];
        $saved = $this->api('movements-create.php', $actor, $body);
        $current = $this->document($id, $actor);
        $this->check($this->movementCount($id) === $before + 1 && $saved['movement_id'] === $current['last_movement_id']
            && $current['current_status'] === $status && $current['current_office_code'] === strtoupper($actor)
            && ($destination === null || $current['destination_office_code'] === $destination),
            "$actor $status records one movement from the displayed custody to the selected destination");
        if ($status === 'IN') $this->check($current['current_contents_receipt']['confirmed'] === true
            && $current['current_contents_receipt']['total_pages'] === 5 && $current['contents_status'] === 'complete',
            "$actor receipt preserves the actual five-page contents evidence");
        if ($replay) {
            $outcome = $this->api('movement-requests.php?request_id=' . $body['request_id'], $actor);
            $again = $this->api('movements-create.php', $actor, $body);
            $this->check($outcome['state'] === 'recorded' && $outcome['result'] === $saved && $again === $saved
                && $this->movementCount($id) === $before + 1,
                'movement recovery and exact same-operation replay retain the saved result without a second handoff');
        }
        return $current;
    }

    private function history(string $id, array $expected): void
    {
        $result = $this->api('documents-movements.php?id=' . rawurlencode($id), 'eng');
        $rows = $result['movements'];
        $actual = array_map(static fn(array $row): array => [$row['office_code'], $row['status'], $row['destination_office_code']], $rows);
        $this->check($actual === $expected, 'full chronological history contains exactly the intended office IN/OUT sequence');
        $lastId = 0;
        $valid = true;
        foreach ($rows as $index => $row) {
            $valid = $valid && $row['id'] > $lastId && $row['is_current'] === ($index === count($rows) - 1);
            if ($index > 0 && $row['status'] === 'IN') {
                $receipt = $row['contents_receipt'];
                $valid = $valid && $receipt['confirmed'] === true && $receipt['total_pages'] === 5
                    && array_column($receipt['items'], 'pages') === [2, 3];
            }
            $lastId = $row['id'];
        }
        $this->check($valid, 'history retains every receipt count, original event order and exactly one current movement');
    }

    private function roleDenials(string $id): void
    {
        $reviewed = $this->document($id, 'hr');
        foreach (['head', 'admin'] as $actor) {
            $before = $this->businessState();
            $this->api('documents-create.php', $actor, ['operation_id' => bin2hex(random_bytes(16)),
                'title' => 'Synthetic forbidden registration', 'type' => 'Others: Forbidden pilot',
                'origin_office_id' => $this->offices[$actor === 'head' ? 'ENG' : 'ACC']], 403);
            $this->api('movements-create.php', $actor, ['request_id' => bin2hex(random_bytes(16)), 'document_id' => $id,
                'office_id' => $this->offices[$actor === 'head' ? 'ENG' : 'ACC'], 'status' => 'OUT',
                'destination_office_id' => $this->offices['HR'], 'movement_source' => 'system',
                'expected_movement_id' => $reviewed['last_movement_id']], 403);
            $this->api('documents-file.php', $actor, ['document_id' => $id,
                'expected_movement_id' => $reviewed['last_movement_id']], 403);
            $detail = $this->document($id, $actor);
            $this->check($detail['can_file'] === false && $this->businessState() === $before,
                "$actor retains monitoring lookup while registration, handoff and filing are denied without business mutation");
        }
    }

    private function ordinary(): void
    {
        $pending = $this->createRequest(['request_kind' => 'pull', 'target_office_id' => $this->offices['HR'],
            'document_category' => 'general', 'purpose' => "Synthetic pilot: ENG needs the HR correspondence packet.\nRetain this full purpose through closure."]);
        $this->check($pending['handler_office']['office_code'] === 'HR' && $pending['document_category'] === 'general',
            'From office HR creates a general request handled by HR');
        $accepted = $this->decide('hr', $this->ticket($pending['id'], 'hr', 'inbox'), 'approve', 'Synthetic HR acceptance; separate from receipt.');
        $this->check($accepted['status'] === 'approved' && $accepted['reviewed_by'] === $this->actors['hr'],
            'HR accepts the request without registering or receiving a folder');
        $document = $this->register('hr', 'Others: Pilot correspondence', $accepted['id']);
        $id = $document['id'];
        $linked = $this->ticket($pending['id'], 'eng', 'outbox');
        $this->check($linked['status'] === 'approved' && $linked['related_document_id'] === $id
            && $linked['review_notes'] === $accepted['review_notes'] && $document['can_file'] === true
            && $document['trail_complete'] === false && $document['suggested_forward'] === null,
            'holder registration links the exact accepted request atomically while Others awaits explicit filing');
        $this->roleDenials($id);

        $before = $this->businessState();
        $stale = $this->api('document-requests-update.php', 'hr', ['request_id' => $pending['id'], 'action' => 'fulfill',
            'expected_status' => $pending['status'], 'expected_revision' => $pending['revision']], 409);
        $this->check(($stale['request_error'] ?? '') === 'request_conflict' && $this->businessState() === $before,
            'a stale pending-ticket confirmation cannot overwrite the accepted linked request');

        $cancelledId = bin2hex(random_bytes(16));
        $cancelledBody = ['request_id' => $cancelledId, 'document_id' => $id, 'office_id' => $this->offices['HR'],
            'status' => 'OUT', 'destination_office_id' => $this->offices['ENG'], 'movement_source' => 'system',
            'expected_movement_id' => $document['last_movement_id']];
        $cancelled = $this->api('movement-requests.php', 'hr', ['request_id' => $cancelledId, 'document_id' => $id, 'action' => 'cancel']);
        $this->api('movements-create.php', 'hr', $cancelledBody, 409);
        $this->check($cancelled['state'] === 'cancelled' && $this->businessState() === $before,
            'cancelling an undispatched movement prevents its late arrival from changing custody');

        $out = $this->move('hr', $id, 'OUT', 'ENG', true);
        $before = $this->businessState();
        $staleMovementId = bin2hex(random_bytes(16));
        $staleMovement = $this->api('movements-create.php', 'hr', ['request_id' => $staleMovementId,
            'document_id' => $id, 'office_id' => $this->offices['HR'], 'status' => 'OUT',
            'destination_office_id' => $this->offices['ENG'], 'movement_source' => 'system',
            'expected_movement_id' => $document['last_movement_id']], 409);
        $staleOutcome = $this->api('movement-requests.php?request_id=' . $staleMovementId, 'hr');
        $this->check(($staleMovement['scan_error'] ?? '') === 'document_changed'
            && $staleOutcome['state'] === 'unknown' && $staleOutcome['result'] === null
            && $this->businessState() === $before,
            'stale handoff review is rejected without a movement or false recorded recovery outcome');
        $wrong = $this->api('movements-create.php', 'bud', ['request_id' => bin2hex(random_bytes(16)),
            'document_id' => $id, 'office_id' => $this->offices['BUD'], 'status' => 'IN',
            'movement_source' => 'system', 'receipt_confirmed' => true, 'expected_movement_id' => $out['last_movement_id'],
            'contents_receipt' => $this->receipt($out['folder_inventory'])], 409);
        $unconfirmed = $this->api('movements-create.php', 'eng', ['request_id' => bin2hex(random_bytes(16)),
            'document_id' => $id, 'office_id' => $this->offices['ENG'], 'status' => 'IN',
            'movement_source' => 'system', 'receipt_confirmed' => false, 'expected_movement_id' => $out['last_movement_id'],
            'contents_receipt' => $this->receipt($out['folder_inventory'])], 400);
        $this->check(($wrong['scan_error'] ?? '') === 'wrong_receiver'
            && ($unconfirmed['scan_error'] ?? '') === 'confirmation_required' && $this->businessState() === $before,
            'wrong receiver and missing physical confirmation preserve the addressed incoming transfer');
        $received = $this->move('eng', $id, 'IN', replay: true);

        $before = $this->businessState();
        $stale = $this->api('documents-file.php', 'eng', ['document_id' => $id,
            'expected_movement_id' => $document['last_movement_id']], 409);
        $this->check(($stale['file_error'] ?? '') === 'document_changed' && $this->businessState() === $before,
            'filing rejects an old reviewed movement even when the caller now holds the folder');
        $this->api('documents-file.php', 'eng', ['document_id' => $id, 'expected_movement_id' => $received['last_movement_id']]);
        $filed = $this->document($id, 'eng');
        $requestAfterFiling = $this->ticket($pending['id'], 'hr', 'inbox');
        $this->check($filed['trail_complete'] === true && $filed['can_file'] === false && !$filed['is_overdue']
            && $requestAfterFiling['status'] === 'approved' && $this->movementCount($id) === 3,
            'ENG explicitly files Others while the linked request remains Accepted with three custody events');
        $closed = $this->decide('hr', $requestAfterFiling, 'fulfill', 'Synthetic HR outcome: requested packet received by ENG.');
        $this->check($closed['status'] === 'fulfilled' && $closed['related_document_id'] === $id
            && $closed['review_notes'] === $accepted['review_notes'] && $closed['reviewed_by'] === $this->actors['hr']
            && $closed['fulfilled_notes'] === 'Synthetic HR outcome: requested packet received by ENG.'
            && $closed['fulfilled_by'] === $this->actors['hr'] && $closed['fulfilled_office_id'] === $this->offices['HR']
            && $closed['reviewed_at'] !== null && $closed['fulfilled_at'] !== null,
            'HR closes the request separately and retains full acceptance and outcome attribution');
        $this->history($id, [['HR', 'IN', null], ['HR', 'OUT', 'ENG'], ['ENG', 'IN', null]]);
    }

    private function dv(): void
    {
        $document = $this->register('eng', 'Disbursement Voucher');
        $id = $document['id'];
        $pending = $this->createRequest(['request_kind' => 'access', 'document_category' => 'disbursement',
            'purpose' => "Synthetic DV pilot: process the physical folder and record release separately.\nThis is not a real payment."]);
        $this->check($pending['handler_office']['office_code'] === 'ACC' && $document['can_file'] === false,
            'DV request routes to Accounting and DV has no explicit Others filing authority');
        $before = $this->businessState();
        $this->api('document-requests-update.php', 'tre', ['request_id' => $pending['id'], 'action' => 'fulfill',
            'expected_status' => $pending['status'], 'expected_revision' => $pending['revision']], 409);
        $this->check($this->businessState() === $before, 'Treasury cannot record payment release before Accounting accepts');
        $accepted = $this->decide('acc', $this->ticket($pending['id'], 'acc', 'inbox'), 'approve', 'Synthetic Accounting acceptance, not financial approval.');
        $before = $this->businessState();
        $this->api('document-requests-update.php', 'acc', ['request_id' => $accepted['id'], 'action' => 'link',
            'related_document_id' => $id, 'expected_status' => $accepted['status'], 'expected_revision' => $accepted['revision']], 403);
        $this->check($this->businessState() === $before, 'Accounting cannot link a DV before origin or actual handling evidence exists');

        $this->move('eng', $id, 'OUT', 'BUD');
        $this->move('bud', $id, 'IN');
        $this->move('bud', $id, 'OUT', 'ACC');
        $this->move('acc', $id, 'IN');
        $linked = $this->decide('acc', $this->ticket($pending['id'], 'acc', 'inbox'), 'link', document: $id);
        $this->check($linked['status'] === 'approved' && $linked['related_document_id'] === $id
            && $linked['review_notes'] === $accepted['review_notes'],
            'Accounting links the exact DV after its confirmed receipt without closing the ticket');
        $before = $this->businessState();
        $this->api('document-requests-update.php', 'acc', ['request_id' => $linked['id'], 'action' => 'fulfill',
            'expected_status' => $linked['status'], 'expected_revision' => $linked['revision']], 403);
        $this->api('documents-file.php', 'acc', ['document_id' => $id,
            'expected_movement_id' => $this->document($id, 'acc')['last_movement_id']], 409);
        $this->check($this->businessState() === $before,
            'Accounting receipt/linking grants neither Treasury payment-release authority nor explicit DV filing');

        $this->move('acc', $id, 'OUT', 'TRE');
        $firstTreasury = $this->move('tre', $id, 'IN');
        $this->check($firstTreasury['trail_complete'] === false,
            'first Treasury receipt remains active before the Mayor has received the DV');
        $this->move('tre', $id, 'OUT', 'MAY');
        $this->move('may', $id, 'IN');
        $this->move('may', $id, 'OUT', 'TRE');
        $finalTreasury = $this->move('tre', $id, 'IN', replay: true);
        $awaitingRelease = $this->ticket($pending['id'], 'tre', 'inbox');
        $this->check($finalTreasury['trail_complete'] === true && $finalTreasury['can_file'] === false
            && $finalTreasury['can_return_to_accounting'] === true && !$finalTreasury['is_overdue']
            && $awaitingRelease['status'] === 'approved' && $this->movementCount($id) === 11,
            'second Treasury receipt completes the eleven-event physical trail while payment ticket stays Accepted');
        $expected = [['ENG', 'IN', null], ['ENG', 'OUT', 'BUD'], ['BUD', 'IN', null], ['BUD', 'OUT', 'ACC'],
            ['ACC', 'IN', null], ['ACC', 'OUT', 'TRE'], ['TRE', 'IN', null], ['TRE', 'OUT', 'MAY'],
            ['MAY', 'IN', null], ['MAY', 'OUT', 'TRE'], ['TRE', 'IN', null]];
        $this->history($id, $expected);
        $before = $this->businessState();
        $denied = $this->api('movements-create.php', 'tre', ['request_id' => bin2hex(random_bytes(16)),
            'document_id' => $id, 'office_id' => $this->offices['TRE'], 'status' => 'OUT',
            'destination_office_id' => $this->offices['HR'], 'movement_source' => 'system',
            'expected_movement_id' => $finalTreasury['last_movement_id']], 409);
        $this->check(($denied['scan_error'] ?? '') === 'route_finished' && $this->businessState() === $before,
            'completed Treasury DV retains the existing optional-Accounting-only forwarding boundary');
        $released = $this->decide('tre', $awaitingRelease, 'fulfill', 'Synthetic payment-release recording only; no funds transferred.');
        $this->check($released['status'] === 'fulfilled' && $released['related_document_id'] === $id
            && $released['reviewed_by'] === $this->actors['acc'] && $released['review_notes'] === $accepted['review_notes']
            && $released['fulfilled_by'] === $this->actors['tre'] && $released['fulfilled_office_id'] === $this->offices['TRE']
            && $released['fulfilled_notes'] === 'Synthetic payment-release recording only; no funds transferred.'
            && $this->movementCount($id) === 11,
            'Treasury payment-release completion preserves separate Accounting review and physical custody');
        $this->check($this->ticket($pending['id'], 'tre', 'inbox')['status'] === 'fulfilled'
            && $this->ticket($pending['id'], 'eng', 'outbox')['status'] === 'fulfilled',
            'recorded Treasury completion remains visible to its closer office and requester');

        $this->move('tre', $id, 'OUT', 'ACC');
        $finalAccounting = $this->move('acc', $id, 'IN');
        $this->check($finalAccounting['trail_complete'] === true && $finalAccounting['can_return_to_accounting'] === false
            && $finalAccounting['can_file'] === false && $this->movementCount($id) === 13
            && $this->ticket($pending['id'], 'eng', 'outbox')['status'] === 'fulfilled',
            'optional final Accounting receipt completes thirteen custody events without another ticket action or File');
        $this->history($id, [...$expected, ['TRE', 'OUT', 'ACC'], ['ACC', 'IN', null]]);
    }

    public function run(): void
    {
        $selected = (string)$this->fixture->db->query('SELECT DATABASE()')->fetchColumn();
        $this->check($selected === $this->fixture->database
            && preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', $selected) === 1,
            'pilot selects only its generated disposable schema');
        foreach ($this->fixture->db->query('SELECT id,code FROM offices')->fetchAll() as $office) {
            $this->offices[strtoupper($office['code'])] = (int)$office['id'];
        }
        foreach (['ENG', 'HR', 'BUD', 'ACC', 'TRE', 'MAY'] as $code) {
            if (!isset($this->offices[$code])) throw new RuntimeException("Required synthetic schema office $code missing");
        }
        $people = [['eng', 'ENG', 'staff'], ['hr', 'HR', 'staff'], ['bud', 'BUD', 'staff'],
            ['acc', 'ACC', 'staff'], ['tre', 'TRE', 'staff'], ['may', 'MAY', 'staff'],
            ['head', 'ENG', 'head'], ['admin', 'ACC', 'admin']];
        foreach ($people as $index => [$name, $code, $role]) {
            $id = $this->actors[$name] = 201 + $index;
            $this->fixture->user($id, 'pilot_' . $name, $this->offices[$code], $role);
        }
        $this->fixture->startServers();
        foreach ($people as [$name]) $this->tokens[$name] = $this->fixture->login('pilot_' . $name);
        $listed = $this->api('offices-list.php');
        $officeMap = [];
        foreach ($listed['offices'] as $office) $officeMap[$office['code']] = $office['id'];
        ksort($officeMap); ksort($this->offices);
        $this->check($officeMap === $this->offices, 'API office codes resolve fixture office IDs without hardcoded office numbers');
        $this->ordinary();
        $this->dv();
        $this->check((int)$this->fixture->db->query('SELECT COUNT(*) FROM documents')->fetchColumn() === 2
            && (int)$this->fixture->db->query('SELECT COUNT(*) FROM movements')->fetchColumn() === 16
            && (int)$this->fixture->db->query("SELECT COUNT(*) FROM document_requests WHERE status='fulfilled'")->fetchColumn() === 2
            && (int)$this->fixture->db->query('SELECT COUNT(*) FROM document_requests')->fetchColumn() === 2,
            'pilot ends with two synthetic folders, sixteen intended custody events and two independently completed tickets');
        $this->fixture->assertCopies();
    }
}

if (trim((string)getenv('TEST_DB_HOST')) === '') {
    throw new RuntimeException('Set TEST_DB_HOST explicitly to the reviewed test server; the fixture creates its own disposable database.');
}
$fixture = new SmartflowStabilizationFixture();
try {
    (new SmartflowOfficePilot($fixture))->run();
} finally {
    $fixture->close();
}
echo "{$fixture->checks} isolated office-pilot checks passed\n";
