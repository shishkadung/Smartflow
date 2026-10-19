<?php
/** Regression checks against a disposable database; the SmartFlow database is never selected.
 * Run: C:\xampp\php\php.exe scripts\test-request-linking.php
 * Optional TEST_DB_HOST, TEST_DB_USER, TEST_DB_PASS configure the local test connection.
 */
declare(strict_types=1);

require_once __DIR__ . '/../backend/backend/api/document-requests-helper.php';
require_once __DIR__ . '/../backend/backend/api/thresholds-helper.php';
date_default_timezone_set('Asia/Manila');

$checks = 0;
function check(bool $condition, string $message): void {
    global $checks;
    if (!$condition) throw new RuntimeException($message);
    $checks++;
    echo "PASS $message\n";
}
$today = date('Y-m-d');
$yesterday = date('Y-m-d', strtotime('yesterday'));
foreach (['pending', 'approved'] as $status) {
    check(smartflow_request_is_overdue($yesterday, $status), "$status remains overdue until completed");
    check(!smartflow_request_is_overdue($today, $status), "$status is due through the end of today");
}
foreach (['fulfilled', 'rejected', 'cancelled'] as $status) {
    check(!smartflow_request_is_overdue($yesterday, $status), "$status stops request overdue");
}
check(smartflow_parse_due_at_input('2026-10-14') === '2026-10-14 23:59:59', 'calendar date means end of due day');
check(smartflow_parse_due_at_input('2026-10-14T14:30') === '2026-10-14 14:30:00', 'explicit deadline time is preserved');
check(smartflow_parse_due_at_input('2026-02-30') === null, 'impossible date is rejected');

$host = getenv('TEST_DB_HOST') ?: '127.0.0.1';
$dbUser = getenv('TEST_DB_USER') ?: 'root';
$dbPass = getenv('TEST_DB_PASS') ?: '';
$testDatabase = 'smartflow_request_test_' . bin2hex(random_bytes(6));
$pdo = new PDO("mysql:host=$host;charset=utf8mb4", $dbUser, $dbPass,
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);
$created = false;
$server = null;
$serverLog = tempnam(sys_get_temp_dir(), 'sf-request-test-');
try {
    $pdo->exec("CREATE DATABASE `$testDatabase` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $created = true;
    $pdo->exec("USE `$testDatabase`");
    $schema = (string)file_get_contents(__DIR__ . '/../backend/backend/api-schema.sql');
    if (preg_match('/^\s*(?:USE\s|(?:CREATE|DROP)\s+DATABASE\s)/im', $schema)) {
        throw new RuntimeException('The test schema must not select or modify another database');
    }
    $pdo->exec($schema);
    $pdo->exec("SET time_zone = '+08:00'");
    $insertUser = $pdo->prepare('INSERT INTO users (id, name, username, password_hash, office_id, role) VALUES (?, ?, ?, ?, ?, ?)');
    foreach ([[1, 'eng', 1, 'staff'], [2, 'bud', 3, 'staff'], [3, 'acc', 4, 'staff'],
        [4, 'tre', 5, 'staff'], [5, 'admin', 4, 'admin'], [6, 'head', 3, 'head'], [7, 'audit', 3, 'auditor'],
        [8, 'may', 6, 'staff'], [9, 'hr', 2, 'staff']] as $fixture) {
        [$id, $name, $office, $role] = $fixture;
        $insertUser->execute([$id, $name, $name, password_hash('test-password', PASSWORD_DEFAULT), $office, $role]);
    }
    $socket = stream_socket_server('tcp://127.0.0.1:0', $socketError, $socketMessage);
    if (!$socket) throw new RuntimeException($socketMessage);
    $address = stream_socket_get_name($socket, false);
    fclose($socket);
    // Local stand-in for the mail provider: addresses containing "reject" get HTTP 404, others HTTP 202.
    // Nothing leaves this machine and no real token is used.
    $mailStubFile = tempnam(sys_get_temp_dir(), 'sf-mail-stub-');
    file_put_contents($mailStubFile, '<?php $b = json_decode(file_get_contents("php://input"), true) ?: [];'
        . '$to = $b["to"][0]["email"] ?? ""; header("Content-Type: application/json");'
        . 'if (str_contains($to, "reject")) { http_response_code(404); echo "{\"errors\":[\"not found\"]}"; return; }'
        . 'http_response_code(202); echo "{\"success\":true}";');
    $mailSocket = stream_socket_server('tcp://127.0.0.1:0', $mailErrno, $mailError);
    if (!$mailSocket) throw new RuntimeException($mailError);
    $mailAddress = stream_socket_get_name($mailSocket, false);
    fclose($mailSocket);
    $mailStub = proc_open([PHP_BINARY, '-S', $mailAddress, $mailStubFile], [0 => ['pipe', 'r'], 1 => ['file', $serverLog, 'a'], 2 => ['file', $serverLog, 'a']], $mailPipes);
    if (!is_resource($mailStub)) throw new RuntimeException('Mail stub could not start');
    fclose($mailPipes[0]);
    // Loopback stand-in for Gmail's SMTP server; the harness-only SMTP cases point extra API servers at it.
    $smtpLog = tempnam(sys_get_temp_dir(), 'sf-smtp-log-');
    $smtpSocket = stream_socket_server('tcp://127.0.0.1:0', $smtpErrno, $smtpError);
    if (!$smtpSocket) throw new RuntimeException($smtpError);
    $smtpPort = (int)substr(stream_socket_get_name($smtpSocket, false), strrpos(stream_socket_get_name($smtpSocket, false), ':') + 1);
    fclose($smtpSocket);
    $smtpStub = proc_open([PHP_BINARY, __DIR__ . '/smtp-stub.php', (string)$smtpPort, $smtpLog, 'smtp-user@synthetic.test', 'synthetic-app-password'],
        [0 => ['pipe', 'r'], 1 => ['file', $serverLog, 'a'], 2 => ['file', $serverLog, 'a']], $smtpPipes);
    if (!is_resource($smtpStub)) throw new RuntimeException('SMTP stub could not start');
    fclose($smtpPipes[0]);
    $environment = array_merge(getenv(), ['DB_HOST' => $host, 'DB_NAME' => $testDatabase,
        'DB_USER' => $dbUser, 'DB_PASS' => $dbPass, 'APP_ENV' => 'development', 'APP_TIMEZONE' => 'Asia/Manila',
        'ALLOW_DEV_TOOLS' => 'true', 'MAILTRAP_API_TOKEN' => 'synthetic-mail-token-never-real',
        'MAILTRAP_API_URL' => "http://$mailAddress/api/send/12345", 'MAIL_FROM_ADDRESS' => 'sender@verified.example',
        'QR_SIGNING_SECRET' => bin2hex(random_bytes(32))]);
    $server = proc_open([PHP_BINARY, '-d', 'variables_order=EGPCS', '-S', $address, '-t', dirname(__DIR__)],
        [0 => ['pipe', 'r'], 1 => ['file', $serverLog, 'a'], 2 => ['file', $serverLog, 'a']], $pipes, dirname(__DIR__), $environment);
    if (!is_resource($server)) throw new RuntimeException('Test API server could not start');
    fclose($pipes[0]);
    $base = "http://$address/backend/backend/api";
    for ($attempt = 0; $attempt < 40; $attempt++) {
        $probe = @fsockopen('127.0.0.1', (int)substr($address, strrpos($address, ':') + 1), $errno, $error, 0.1);
        if ($probe) { fclose($probe); break; }
        usleep(50000);
    }
    function api(string $path, ?string $token = null, ?array $body = null): array {
        global $base;
        $curl = curl_init("$base/$path");
        $headers = ['Content-Type: application/json'];
        if ($token !== null) $headers[] = "Authorization: Bearer $token";
        curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10, CURLOPT_HTTPHEADER => $headers]);
        if ($body !== null) curl_setopt_array($curl, [CURLOPT_POST => true, CURLOPT_POSTFIELDS => json_encode($body, JSON_THROW_ON_ERROR)]);
        $response = curl_exec($curl);
        if ($response === false) throw new RuntimeException(curl_error($curl));
        $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
        return [$status, json_decode($response, true, 512, JSON_THROW_ON_ERROR)];
    }
    $tokens = [];
    foreach (['eng', 'bud', 'acc', 'tre', 'admin', 'head', 'audit', 'may', 'hr'] as $name) {
        [$http, $login] = api('auth-login.php', null, ['username' => $name, 'password' => 'test-password']);
        check($http === 200 && isset($login['token']), "$name fixture login (HTTP $http)");
        $tokens[$name] = $login['token'];
    }
    function requestFixture(int $handler = 3, string $category = 'budget', string $status = 'approved', ?string $due = null): int {
        global $pdo, $yesterday;
        $insert = $pdo->prepare('INSERT INTO document_requests (request_code, request_kind, document_category, requested_by,
            requester_office_id, requester_role, handler_office_id, purpose, required_by, status, reviewed_by, reviewed_at, review_notes)
            VALUES (?, "access", ?, 1, 1, "staff", ?, "Test request", ?, ?, 2, NOW(), "Original acceptance")');
        $insert->execute(['TEST-' . bin2hex(random_bytes(5)), $category, $handler, $due ?? $yesterday, $status]);
        return (int)$pdo->lastInsertId();
    }
    function register(string $who, int $office, string $type, ?int $request = null): array {
        global $tokens;
        $body = ['title' => 'Test physical folder', 'type' => $type, 'origin_office_id' => $office,
            'reference_no' => bin2hex(random_bytes(5)), 'payee' => 'Test payee', 'fund_source' => 'Test fund'];
        if ($office === 4 && $type === 'Disbursement Voucher') $body['received_from_office_id'] = 1;
        if ($request !== null) $body['request_id'] = $request;
        return api('documents-create.php', $tokens[$who], $body);
    }
    function linkRequest(string $who, int $request, string $document): array {
        global $tokens;
        return api('document-requests-update.php', $tokens[$who],
            ['request_id' => $request, 'action' => 'link', 'related_document_id' => $document]);
    }
    $budgetRequest = requestFixture();
    [$http, $registered] = register('bud', 3, 'Approved Budget', $budgetRequest);
    check($http === 201 && $registered['document']['initial_in_recorded'], 'registration creates folder and initial custody');
    $budgetDoc = $registered['document']['id'];
    $row = $pdo->query("SELECT * FROM document_requests WHERE id = $budgetRequest")->fetch();
    check($row['related_document_id'] === $budgetDoc && $row['status'] === 'approved'
        && $row['review_notes'] === 'Original acceptance' && (int)$row['reviewed_by'] === 2, 'atomic link preserves approval and reviewer');
    check(linkRequest('bud', $budgetRequest, $budgetDoc)[0] === 200, 'same folder link is idempotent');
    [$http, $second] = register('bud', 3, 'Approved Budget');
    $secondDoc = $second['document']['id'];
    check(linkRequest('bud', $budgetRequest, $secondDoc)[0] === 409, 'different linked folder cannot overwrite existing evidence');
    foreach (['eng', 'audit'] as $who) {
        check(linkRequest($who, requestFixture(), $budgetDoc)[0] === 403, "$who cannot link handler request");
    }
    foreach (['head', 'admin'] as $who) {
        check(linkRequest($who, requestFixture(), $budgetDoc)[0] === 200, "$who retains existing handler request authority");
    }
    check(linkRequest('bud', requestFixture(status: 'pending'), $budgetDoc)[0] === 409, 'pending request cannot be linked');
    check(linkRequest('bud', requestFixture(), 'DOC-1900-999999')[0] === 404, 'missing folder cannot be linked');
    [$http, $dv] = register('eng', 1, 'Disbursement Voucher');
    $dvDoc = $dv['document']['id'];
    check(linkRequest('bud', requestFixture(), $dvDoc)[0] === 400, 'folder category must match request');
    [$http, $outside] = register('acc', 4, 'Approved Budget');
    check(linkRequest('bud', requestFixture(), $outside['document']['id'])[0] === 403, 'unrelated office folder cannot be linked');

    foreach ([[requestFixture(), 'eng', 1, 'Disbursement Voucher', 403],
        [requestFixture(status: 'pending'), 'bud', 3, 'Approved Budget', 409],
        [$budgetRequest, 'bud', 3, 'Approved Budget', 409]] as [$request, $who, $office, $type, $expected]) {
        $before = $pdo->query('SELECT (SELECT COUNT(*) FROM documents) + (SELECT COUNT(*) FROM movements)')->fetchColumn();
        [$http] = register($who, $office, $type, $request);
        check($http === $expected && $before === $pdo->query('SELECT (SELECT COUNT(*) FROM documents) + (SELECT COUNT(*) FROM movements)')->fetchColumn(),
            "failed linked registration ($expected) leaves no folder or custody orphan");
    }
    $failureRequest = requestFixture();
    $before = $pdo->query('SELECT COUNT(*) FROM documents')->fetchColumn();
    $pdo->exec("CREATE TRIGGER test_movement_failure BEFORE INSERT ON movements FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Injected custody failure'");
    [$http] = register('bud', 3, 'Approved Budget', $failureRequest);
    $pdo->exec('DROP TRIGGER test_movement_failure');
    check($http === 500 && $before === $pdo->query('SELECT COUNT(*) FROM documents')->fetchColumn()
        && $pdo->query("SELECT related_document_id FROM document_requests WHERE id = $failureRequest")->fetchColumn() === null,
        'custody failure rolls back document and request together');

    $dvRequest = requestFixture(4, 'disbursement');
    $pdo->prepare('INSERT INTO movements (document_id, office_id, status, user_id) VALUES (?, 4, "IN", 3)')->execute([$dvDoc]);
    check(linkRequest('tre', $dvRequest, $dvDoc)[0] === 403, 'Treasury payment access does not grant Accounting link authority');
    check(linkRequest('acc', $dvRequest, $dvDoc)[0] === 200, 'Accounting may link a DV it handled');
    check(api('document-requests-update.php', $tokens['acc'], ['request_id' => $dvRequest, 'action' => 'fulfill'])[0] === 403,
        'linking a DV does not grant Accounting payment release');
    check(api('document-requests-update.php', $tokens['tre'], ['request_id' => $dvRequest, 'action' => 'fulfill'])[0] === 200,
        'Treasury can still mark payment released');
    check($pdo->query("SELECT related_document_id FROM document_requests WHERE id = $dvRequest")->fetchColumn() === $dvDoc,
        'payment release preserves linked folder');
    check(api('document-requests-update.php', $tokens['bud'], ['request_id' => requestFixture(), 'action' => 'fulfill'])[0] === 200,
        'nonphysical request fulfillment does not require a folder');

    $dueToday = requestFixture(due: $today);
    [$http, $inbox] = api('document-requests-list.php?view=inbox', $tokens['bud']);
    $byId = array_column($inbox['requests'], null, 'id');
    check($byId[$budgetRequest]['is_overdue'] && !$byId[$dueToday]['is_overdue'], 'list keeps approved overdue and treats today as due');
    [$http, $summary] = api('document-requests-summary.php', $tokens['bud']);
    $expected = (int)$pdo->query("SELECT COUNT(*) FROM document_requests WHERE handler_office_id = 3 AND status IN ('pending','approved') AND required_by < CURDATE()")->fetchColumn();
    check($summary['overdue_inbox_count'] === $expected, 'summary overdue agrees with open request list');
    [$http, $summary] = api('document-requests-summary.php', $tokens['eng']);
    $expected = (int)$pdo->query("SELECT COUNT(*) FROM document_requests WHERE requested_by = 1 AND status IN ('pending','approved') AND required_by < CURDATE()")->fetchColumn();
    check($summary['overdue_outbox_count'] === $expected, 'requester overdue count includes approved open requests');

    // Municipal oversight uses the same fixtures and HTTP API, without opening cross-office writes.
    $insertFolder = $pdo->prepare('INSERT INTO documents (id, title, type, origin_office_id, created_by, due_at, filed_at)
        VALUES (?, ?, ?, ?, 1, ?, ?)');
    $insertMovement = $pdo->prepare('INSERT INTO movements (document_id, office_id, status, user_id, destination_office_id, scanned_at)
        VALUES (?, ?, ?, 1, ?, DATE_SUB(NOW(), INTERVAL 5 DAY))');
    foreach ([
        ['DOC-1900-000001', 'Overdue Engineering folder', 'Others: Test', 1, null, null, 'IN', null],
        ['DOC-1900-000002', 'Engineering transit threshold', 'Disbursement Voucher', 1, null, null, 'OUT', 3],
        ['DOC-1900-000003', 'Treasury manual deadline', 'Others: Test', 5, "$yesterday 23:59:59", null, 'OUT', 4],
        ['DOC-1900-000004', 'Budget filed folder', 'Others: Test', 3, null, "$yesterday 10:00:00", 'IN', null],
    ] as [$id, $title, $type, $office, $due, $filed, $status, $destination]) {
        $insertFolder->execute([$id, $title, $type, $office, $due, $filed]);
        $insertMovement->execute([$id, $office, $status, $destination]);
    }
    foreach (['eng', 'bud', 'head', 'audit'] as $who) {
        check(api('office-documents.php?scope=municipal&limit=1&tray=in_office', $tokens[$who])[0] === 403,
            "$who cannot query municipal documents");
    }
    check(api('office-documents.php?scope=unknown', $tokens['admin'])[0] === 400, 'invalid municipal scope is rejected');
    check(api('office-documents.php?scope=municipal&current_office_id=-1', $tokens['admin'])[0] === 400,
        'negative municipal office filter is rejected');
    check(api('office-documents.php?current_office_id=1', $tokens['admin'])[0] === 400,
        'current office filter cannot widen default office scope');
    [$http, $municipal] = api('office-documents.php?scope=municipal&limit=1&tray=in_office', $tokens['admin']);
    check($http === 200 && $municipal['read_only'] && $municipal['scope'] === 'municipal', 'admin municipal list is marked read only');
    check(count($municipal['documents']) === 1 && $municipal['total'] === 5 && $municipal['has_more']
        && $municipal['tray_counts'] === ['incoming' => 0, 'in_office' => 5, 'forwarded' => 2, 'completed' => 1],
        'municipal pagination and tray counts agree before page limits');
    check($municipal['overdue_count'] === 2, 'municipal overdue includes IN and manual OUT, excludes threshold-only OUT');
    [$http, $filtered] = api('office-documents.php?scope=municipal&current_office_id=1&limit=1&tray=in_office', $tokens['admin']);
    check($http === 200 && $filtered['total'] === 1 && !$filtered['has_more'] && $filtered['overdue_count'] === 1
        && $filtered['tray_counts'] === ['incoming' => 0, 'in_office' => 1, 'forwarded' => 1, 'completed' => 0]
        && $filtered['documents'][0]['id'] === 'DOC-1900-000001', 'municipal office filter applies to rows and counts before pagination');
    [$http, $searched] = api('office-documents.php?scope=municipal&limit=1&tray=forwarded&search=DOC-1900-000002', $tokens['admin']);
    check($http === 200 && $searched['total'] === 1 && $searched['documents'][0]['id'] === 'DOC-1900-000002'
        && !$searched['documents'][0]['is_overdue'], 'municipal search and page aliases preserve transit overdue rules');
    [$http, $overdue] = api('office-documents.php?scope=municipal&limit=10&overdue=1', $tokens['admin']);
    $overdueIds = array_column($overdue['documents'], 'id'); sort($overdueIds);
    check($http === 200 && $overdue['total'] === 2 && $overdueIds === ['DOC-1900-000001', 'DOC-1900-000003'],
        'municipal overdue filter returns exactly the dashboard overdue documents');
    [$http, $detail] = api('office-documents.php?scope=municipal&id=DOC-1900-000001', $tokens['admin']);
    check($http === 200 && $detail['read_only'] && !$detail['document']['can_file']
        && !$detail['document']['can_return_to_accounting'] && $detail['document']['visited_office_codes'] === ['ENG'],
        'municipal detail exposes journey with operational controls disabled');
    [$http, $defaultQueue] = api('office-documents.php?limit=10&tray=incoming', $tokens['bud']);
    check($http === 200 && !$defaultQueue['read_only'] && $defaultQueue['scope'] === 'office'
        && $defaultQueue['total'] === 1 && $defaultQueue['documents'][0]['id'] === 'DOC-1900-000002',
        'ordinary office queue still shows only assigned incoming documents');
    $before = $pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn();
    [$http] = api('movements-create.php', $tokens['admin'], ['document_id' => 'DOC-1900-000001', 'office_id' => 1,
        'status' => 'OUT', 'destination_office_id' => 3, 'movement_source' => 'system',
        'expected_movement_id' => $detail['document']['last_movement_id']]);
    check($http === 403 && $before === $pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn(),
        'municipal read access does not allow admin to move another office folder');

    $filedOthers = 'DOC-1900-000005';
    $completedDv = 'DOC-1900-000006';
    $insertFolder->execute([$filedOthers, 'Treasury filed Others', 'Others: Test', 5, null, "$yesterday 10:00:00"]);
    $insertMovement->execute([$filedOthers, 5, 'IN', null]);
    $insertFolder->execute([$completedDv, 'Treasury completed DV', 'Disbursement Voucher', 5, null, null]);
    $insertMovement->execute([$completedDv, 6, 'IN', null]);
    $insertMovement->execute([$completedDv, 5, 'IN', null]);
    [$http, $treasury] = api('office-documents.php?limit=10&tray=completed', $tokens['tre']);
    $treasuryById = array_column($treasury['documents'], null, 'id');
    check($http === 200 && !$treasuryById[$filedOthers]['can_return_to_accounting'],
        'Treasury list does not offer a return for filed Others');
    check($treasuryById[$completedDv]['can_return_to_accounting'], 'Treasury list retains the optional return for a completed DV');
    foreach (['office-documents.php', 'documents-show.php'] as $endpoint) {
        [$http, $filedDetail] = api("$endpoint?id=$filedOthers", $tokens['tre']);
        check($http === 200 && !$filedDetail['document']['can_return_to_accounting'], "$endpoint rejects return for filed Others detail");
        [$http, $dvDetail] = api("$endpoint?id=$completedDv", $tokens['tre']);
        check($http === 200 && $dvDetail['document']['can_return_to_accounting'], "$endpoint retains completed DV return");
    }
    [$http, $municipalDv] = api("office-documents.php?scope=municipal&id=$completedDv", $tokens['admin']);
    check($http === 200 && !$municipalDv['document']['can_return_to_accounting'], 'municipal DV detail remains read only');
    $pdo->prepare("UPDATE movements SET status = 'OUT', destination_office_id = 4 WHERE document_id = ? AND office_id = 5")->execute([$completedDv]);
    foreach (['office-documents.php', 'documents-show.php'] as $endpoint) {
        [$http, $inTransit] = api("$endpoint?id=$completedDv", $tokens['tre']);
        check($http === 200 && !$inTransit['document']['can_return_to_accounting'], "$endpoint requires current IN for a DV return");
    }
    $pdo->prepare("UPDATE movements SET status = 'IN', destination_office_id = NULL WHERE document_id = ? AND office_id = 5")->execute([$completedDv]);
    $pdo->prepare('UPDATE documents SET filed_at = NOW() WHERE id = ?')->execute([$completedDv]);
    foreach (['office-documents.php', 'documents-show.php'] as $endpoint) {
        [$http, $filedDv] = api("$endpoint?id=$completedDv", $tokens['tre']);
        check($http === 200 && !$filedDv['document']['can_return_to_accounting'], "$endpoint never offers a return for an explicitly filed record");
    }

    // Exercise real registration, inventory receipts, correction, and the whole DV route over HTTP.
    [$http, $workflowRegistration] = api('documents-create.php', $tokens['eng'], [
        'title' => 'Integrated custody workflow', 'type' => 'Disbursement Voucher', 'origin_office_id' => 1,
        'reference_no' => 'WORKFLOW-' . bin2hex(random_bytes(5)), 'payee' => 'Workflow payee', 'fund_source' => 'Test fund',
        'folder_inventory' => ['count_confirmed' => true, 'items' => [
            ['pages' => 2], ['name' => 'ObR attachment', 'pages' => 1, 'required' => true],
        ]],
    ]);
    check($http === 201 && $workflowRegistration['document']['initial_in_recorded']
        && $workflowRegistration['document']['contents_status'] === 'complete', 'workflow registers an actual counted DV and initial Engineering custody');
    $workflowId = $workflowRegistration['document']['id'];
    $fullReceipt = ['confirmed' => true, 'items' => [['id' => 'main', 'pages' => 2], ['id' => 'attachment-1', 'pages' => 1]]];
    function workflowSnapshot(): array {
        global $tokens, $workflowId;
        [$http, $data] = api("office-documents.php?scope=municipal&id=$workflowId", $tokens['admin']);
        if ($http !== 200) throw new RuntimeException('Workflow custody snapshot failed: ' . ($data['message'] ?? $http));
        return $data['document'];
    }
    function workflowMove(string $who, int $office, string $status, ?int $destination = null, array $extra = []): array {
        global $tokens, $workflowId, $fullReceipt;
        $current = workflowSnapshot();
        $body = ['document_id' => $workflowId, 'office_id' => $office, 'status' => $status,
            'movement_source' => 'system', 'expected_movement_id' => $current['last_movement_id']];
        if ($destination !== null) $body['destination_office_id'] = $destination;
        if ($status === 'IN') $body += ['receipt_confirmed' => true, 'contents_receipt' => $fullReceipt];
        $body = array_merge($body, $extra);
        [$http, $data] = api('movements-create.php', $tokens[$who], $body);
        return [$http, $data, $body];
    }
    function workflowTray(string $who, string $tray, int $expected): void {
        global $tokens, $workflowId;
        [$http, $data] = api("office-documents.php?limit=100&tray=$tray&search=$workflowId", $tokens[$who]);
        check($http === 200 && $data['total'] === $expected && count($data['documents']) === $expected,
            "workflow $who $tray tray and filtered count = $expected");
    }
    workflowTray('eng', 'in_office', 1);
    workflowTray('bud', 'incoming', 0);
    [$http, $sent, $sendPayload] = workflowMove('eng', 1, 'OUT', 3);
    check($http === 200 && $sent['destination_office_code'] === 'BUD', 'workflow Engineering forwards to Budget');
    workflowTray('eng', 'forwarded', 1);
    workflowTray('bud', 'incoming', 1);
    $before = $pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn();
    [$http, $duplicate] = api('movements-create.php', $tokens['eng'], $sendPayload);
    check($http === 409 && $before === $pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn(),
        'workflow repeated handoff is rejected without recording a duplicate');
    [$http, $wrongReceiver] = workflowMove('hr', 2, 'IN');
    check($http === 409 && ($wrongReceiver['scan_error'] ?? '') === 'wrong_receiver'
        && $before === $pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn(), 'workflow wrong office cannot receive a folder sent to Budget');
    $incompleteReceipt = ['confirmed' => true, 'items' => [['id' => 'main', 'pages' => 2], ['id' => 'attachment-1', 'pages' => 0]],
        'reason' => 'Missing ObR attachment'];
    [$http, $received] = workflowMove('bud', 3, 'IN', extra: ['contents_receipt' => $incompleteReceipt]);
    check($http === 200 && $received['contents_receipt']['status'] === 'incomplete', 'workflow Budget records the actual incomplete receipt');
    workflowTray('bud', 'incoming', 0);
    workflowTray('bud', 'in_office', 1);
    [$http] = workflowMove('bud', 3, 'OUT', 1, ['is_return' => true]);
    check($http === 400, 'workflow correction return requires a reason');
    [$http, $returned] = workflowMove('bud', 3, 'OUT', 1, ['is_return' => true, 'remarks' => 'Missing ObR attachment']);
    check($http === 200 && $returned['is_return'], 'workflow Budget returns to the actual prior Engineering holder');
    workflowTray('eng', 'incoming', 1);
    [$http, $corrected] = workflowMove('eng', 1, 'IN');
    check($http === 200 && $corrected['contents_receipt']['status'] === 'complete', 'workflow Engineering receives and records corrected contents');
    [$http, $history] = api("documents-movements.php?id=$workflowId", $tokens['admin']);
    $returnNotes = array_filter($history['movements'], static fn(array $step): bool => str_contains((string)$step['remarks'],
        'Returned to Engineering Office (ENG): Missing ObR attachment'));
    check($http === 200 && count($returnNotes) === 1, 'workflow correction reason remains in custody history');

    foreach ([['eng', 1, 'OUT', 3], ['bud', 3, 'IN', null], ['bud', 3, 'OUT', 4], ['acc', 4, 'IN', null],
        ['acc', 4, 'OUT', 5], ['tre', 5, 'IN', null], ['tre', 5, 'OUT', 6], ['may', 6, 'IN', null],
        ['may', 6, 'OUT', 5], ['tre', 5, 'IN', null]] as [$who, $office, $status, $destination]) {
        [$http, $moved] = workflowMove($who, $office, $status, $destination);
        check($http === 200, "workflow $who $status" . ($destination === null ? '' : " to office $destination")
            . ($http === 200 ? '' : ': ' . ($moved['message'] ?? $http)));
        if ($who === 'tre' && $status === 'IN' && $destination === null) {
            $snapshot = workflowSnapshot();
            if (in_array('MAY', $snapshot['visited_office_codes'], true)) {
                check($snapshot['trail_complete'] && !$snapshot['is_overdue'], 'workflow completes at Treasury after Mayor receipt');
            } else check(!$snapshot['trail_complete'], 'workflow first Treasury receipt is still active');
        }
    }
    workflowTray('tre', 'in_office', 0);
    workflowTray('tre', 'completed', 1);
    [$http, $finalTreasury] = api("office-documents.php?id=$workflowId", $tokens['tre']);
    check($http === 200 && $finalTreasury['document']['can_return_to_accounting']
        && $finalTreasury['document']['qr_payload'] === $workflowRegistration['document']['qr_payload'],
        'workflow completed DV can return to Accounting and retains its original QR');
    check((int)$pdo->query("SELECT COUNT(*) FROM movements WHERE document_id = '$workflowId'")->fetchColumn() === 15,
        'workflow has exactly one custody record for every successful step');
    [$http] = workflowMove('tre', 5, 'OUT', 6);
    check($http === 409, 'workflow completed DV cannot reopen to an unrelated destination');
    [$http] = workflowMove('tre', 5, 'OUT', 4);
    check($http === 200, 'workflow completed DV may return to Accounting');
    workflowTray('acc', 'incoming', 1);
    [$http, $accountingReceipt] = workflowMove('acc', 4, 'IN');
    check($http === 200 && $accountingReceipt['contents_receipt']['status'] === 'complete', 'workflow Accounting confirms final physical receipt');
    workflowTray('acc', 'completed', 1);
    [$http, $finalAccounting] = api("office-documents.php?id=$workflowId", $tokens['acc']);
    check($http === 200 && $finalAccounting['document']['trail_complete'] && !$finalAccounting['document']['can_return_to_accounting']
        && (int)$pdo->query("SELECT COUNT(*) FROM movements WHERE document_id = '$workflowId'")->fetchColumn() === 17,
        'workflow final Accounting custody is complete with exactly 17 successful movements');

    // Completed folders stop active overdue tracking without erasing their processing time.
    foreach ([96, 12] as $hoursToFile) {
        $receivedAt = date('Y-m-d H:i:s', time() - $hoursToFile * 3600);
        $receiptMonth = substr($receivedAt, 0, 7);
        [$http, $beforeFiling] = api("head-analytics.php?office_id=2&month=$receiptMonth", $tokens['admin']);
        check($http === 200, "filing Analytics baseline for $hoursToFile hours is available");
        [$http, $registration] = register('hr', 2, 'Others: Filing report sample');
        check($http === 201, "report fixture registers a folder to file after $hoursToFile hours");
        $fileId = $registration['document']['id'];
        $pdo->prepare('UPDATE movements SET scanned_at = ? WHERE document_id = ?')->execute([$receivedAt, $fileId]);
        $movementId = (int)$pdo->query('SELECT MAX(id) FROM movements WHERE document_id = ' . $pdo->quote($fileId))->fetchColumn();
        [$http] = api('documents-file.php', $tokens['hr'], ['document_id' => $fileId, 'expected_movement_id' => $movementId]);
        check($http === 200, "real filing succeeds after $hoursToFile hours");
        [$http, $fileAnalytics] = api("head-analytics.php?office_id=2&month=$receiptMonth", $tokens['admin']);
        $wasLate = $hoursToFile > 48;
        check($http === 200 && $fileAnalytics['stats']['processed'] === $beforeFiling['stats']['processed'] + 1
            && $fileAnalytics['stats']['delayed_count'] === $beforeFiling['stats']['delayed_count'] + (int)$wasLate
            && $fileAnalytics['stats']['on_time_count'] === $beforeFiling['stats']['on_time_count'] + (int)!$wasLate
            && $fileAnalytics['stats']['unforwarded_count'] === $beforeFiling['stats']['unforwarded_count'],
            "Analytics retains actual $hoursToFile-hour filing classification");
        $slowById = array_column($fileAnalytics['slow_documents'], null, 'document_id');
        check($wasLate ? ($slowById[$fileId]['hours'] ?? 0) === $hoursToFile : !isset($slowById[$fileId]),
            "slow documents agree with $hoursToFile-hour filing duration");
        [$http, $fileDetail] = api('documents-show.php?id=' . $fileId, $tokens['hr']);
        check($http === 200 && $fileDetail['document']['trail_complete'] && !$fileDetail['document']['is_overdue'],
            "filed $hoursToFile-hour folder detail is complete without active overdue");
        [$http, $fileReport] = api("reports-office-documents.php?office_id=2&month=$receiptMonth", $tokens['admin']);
        $reportById = array_column($fileReport['documents'] ?? [], null, 'document_id');
        $reported = $reportById[$fileId] ?? [];
        check($http === 200 && ($reported['trail_complete'] ?? false) && !$reported['is_overdue']
            && $reported['due_at'] === '' && $reported['hours_until_due'] === 0
            && $reported['current_status'] === 'IN' && $reported['movement_count'] === 1
            && $reported['last_at_office'] === $receivedAt,
            "office report retains period evidence and suppresses completed $hoursToFile-hour folder overdue");
    }

    // Legacy unmatched earlier receipts must not be closed by a later filing.
    $earlierIn = date('Y-m-d H:i:s', time() - 36 * 3600);
    $finalIn = date('Y-m-d H:i:s', time() - 12 * 3600);
    $earlierMonth = substr($earlierIn, 0, 7);
    [$http, $beforeUnmatched] = api("head-analytics.php?office_id=2&month=$earlierMonth", $tokens['admin']);
    [$http, $unmatchedRegistration] = register('hr', 2, 'Others: Legacy unmatched visit');
    check($http === 201, 'unmatched-visit report fixture registers');
    $unmatchedId = $unmatchedRegistration['document']['id'];
    $pdo->prepare('UPDATE movements SET scanned_at = ? WHERE document_id = ?')->execute([$earlierIn, $unmatchedId]);
    $timedMovement = $pdo->prepare('INSERT INTO movements (document_id, office_id, status, user_id, scanned_at) VALUES (?, ?, ?, 9, ?)');
    $timedMovement->execute([$unmatchedId, 2, 'IN', $finalIn]);
    [$http] = api('documents-file.php', $tokens['hr'], ['document_id' => $unmatchedId, 'expected_movement_id' => (int)$pdo->lastInsertId()]);
    check($http === 200, 'latest receipt can be filed with an unmatched legacy earlier visit');
    [$http, $unmatchedAnalytics] = api("head-analytics.php?office_id=2&month=$earlierMonth", $tokens['admin']);
    check($http === 200 && $unmatchedAnalytics['stats']['processed'] === $beforeUnmatched['stats']['processed'] + 1
        && $unmatchedAnalytics['stats']['unforwarded_count'] === $beforeUnmatched['stats']['unforwarded_count'] + 1
        && $unmatchedAnalytics['stats']['on_time_count'] === $beforeUnmatched['stats']['on_time_count']
        && $unmatchedAnalytics['stats']['delayed_count'] === $beforeUnmatched['stats']['delayed_count'],
        'filing closes only the final visit and preserves earlier unmatched evidence');

    // Fixed routes still complete at the terminal receipt; earlier slow visits remain slow.
    foreach ([
        ['DOC-2001-000001', 'Disbursement Voucher', 5, [[6, 'IN', '01 00:00:00'], [6, 'OUT', '01 01:00:00'], [5, 'IN', '01 02:00:00']]],
        ['DOC-2001-000002', 'Approved Budget', 4, [[3, 'IN', '01 00:00:00'], [3, 'OUT', '01 01:00:00'], [4, 'IN', '01 02:00:00']]],
        ['DOC-2001-000003', 'Disbursement Voucher', 5, [[5, 'IN', '01 00:00:00'], [5, 'OUT', '05 00:00:00'],
            [6, 'IN', '05 01:00:00'], [6, 'OUT', '05 02:00:00'], [5, 'IN', '05 03:00:00']]],
    ] as [$routeId, $routeType, $routeOffice, $routeMovements]) {
        $insertFolder->execute([$routeId, 'Automatic completion report sample', $routeType, $routeOffice, '2001-02-01 00:00:00', null]);
        foreach ($routeMovements as [$office, $status, $at]) $timedMovement->execute([$routeId, $office, $status, '2001-02-' . $at]);
        [$http, $routeReport] = api("reports-office-documents.php?office_id=$routeOffice&month=2001-02", $tokens['admin']);
        $routeById = array_column($routeReport['documents'] ?? [], null, 'document_id');
        $reported = $routeById[$routeId] ?? [];
        check($http === 200 && ($reported['trail_complete'] ?? false) && !$reported['is_overdue']
            && $reported['due_at'] === '' && $reported['current_status'] === 'IN'
            && $reported['movement_count'] === ($routeId === 'DOC-2001-000003' ? 3 : 1),
            "$routeId report retains automatic completion and historical office movements");
    }
    [$http, $treasuryAnalytics] = api('head-analytics.php?office_id=5&month=2001-02', $tokens['admin']);
    $treasurySlow = array_column($treasuryAnalytics['slow_documents'] ?? [], null, 'document_id');
    check($http === 200 && $treasuryAnalytics['stats']['processed'] === 2 && $treasuryAnalytics['stats']['on_time_count'] === 1
        && $treasuryAnalytics['stats']['delayed_count'] === 1 && $treasuryAnalytics['stats']['unforwarded_count'] === 0
        && ($treasurySlow['DOC-2001-000003']['hours'] ?? 0) === 96 && !isset($treasurySlow['DOC-2001-000001']),
        'DV terminal receipt completes immediately while preserving an earlier 96-hour visit');
    [$http, $budgetAnalytics] = api('head-analytics.php?office_id=4&month=2001-02', $tokens['admin']);
    check($http === 200 && $budgetAnalytics['stats']['processed'] === 1 && $budgetAnalytics['stats']['on_time_count'] === 1
        && $budgetAnalytics['stats']['delayed_count'] === 0 && $budgetAnalytics['stats']['unforwarded_count'] === 0,
        'Approved Budget terminal Accounting receipt remains on time without explicit filing');

    require_once __DIR__ . '/request-consistency-cases.php';
    smartflow_test_request_consistency($pdo, $tokens);
    require_once __DIR__ . '/system-gap-cases.php';
    smartflow_test_system_gaps($pdo, $tokens);
    require_once __DIR__ . '/destination-correction-cases.php';
    smartflow_test_destination_corrections($pdo, $tokens);
    require_once __DIR__ . '/auth-security-cases.php';
    smartflow_test_auth_security($pdo, $tokens);
    require_once __DIR__ . '/clarity-cases.php';
    smartflow_test_clarity($pdo, $tokens);
    require_once __DIR__ . '/scan-guard-cases.php';
    smartflow_test_scan_guards($pdo, $tokens);
    require_once __DIR__ . '/followup-integrity-cases.php';
    smartflow_test_followup_integrity($pdo);
    require_once __DIR__ . '/final-flow-cases.php';
    smartflow_test_final_flow($pdo);
    require_once __DIR__ . '/dev-security-cases.php';
    smartflow_test_dev_security($pdo);
    require_once __DIR__ . '/threshold-continuation-cases.php';
    smartflow_test_threshold_continuation($pdo, $tokens);
    require_once __DIR__ . '/recovery-continuation-cases.php';
    smartflow_test_recovery_continuation($pdo);
    require_once __DIR__ . '/email-channel-cases.php';
    smartflow_test_email_channel($pdo, $tokens);
    require_once __DIR__ . '/smtp-channel-cases.php';
    smartflow_test_smtp_channel($pdo, $tokens);
    require_once __DIR__ . '/admin-reset-cases.php';
    smartflow_test_admin_reset($pdo, $tokens);
    require_once __DIR__ . '/admin-email-cases.php';
    smartflow_test_admin_email($pdo, $tokens);
    echo "$checks checks passed in disposable database $testDatabase\n";
} finally {
    if (is_resource($server)) { proc_terminate($server); proc_close($server); }
    if (isset($smtpStub) && is_resource($smtpStub)) { proc_terminate($smtpStub); proc_close($smtpStub); }
    if (isset($smtpLog) && is_file($smtpLog)) unlink($smtpLog);
    if (isset($mailStub) && is_resource($mailStub)) { proc_terminate($mailStub); proc_close($mailStub); }
    if (isset($mailStubFile) && is_file($mailStubFile)) unlink($mailStubFile);
    if ($created && preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', $testDatabase)) {
        $pdo->exec("DROP DATABASE `$testDatabase`");
    }
    if (is_file($serverLog)) unlink($serverLog);
}
