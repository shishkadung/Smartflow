<?php
// POST: correct the recorded destination of a latest, still-unreceived OUT. No custody event is inserted.
require __DIR__ . '/config.php';
require_once __DIR__ . '/movements-helper.php';
require_once __DIR__ . '/movement-corrections-helper.php';
require_once __DIR__ . '/movement-requests-helper.php';
require_once __DIR__ . '/routing-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') json_response(['success' => false, 'message' => 'Method not allowed'], 405);
$user = smartflow_require_authenticated_user($pdo, require_user_id());
$body = get_json_body();
$documentId = trim((string)($body['document_id'] ?? ''));
$reject = static function(string $error, string $message, int $http = 409) use ($pdo, $user, $documentId): void {
    smartflow_reject_scan($pdo, 'movement.destination_corrected', $documentId ?: null, $user['id'], $user['office_id'], 'OUT', $error, $message, $http);
};
if ($user['role'] !== 'staff') $reject('role_forbidden', 'Only the sending office staff can correct an unreceived destination.', 403);
$requestId = smartflow_request_id($body['request_id'] ?? null);
$expectedMovement = (int)($body['expected_movement_id'] ?? 0);
$expectedDestination = (int)($body['expected_destination_office_id'] ?? 0);
$expectedCorrection = filter_var($body['expected_correction_id'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 0]]);
$destination = (int)($body['destination_office_id'] ?? 0);
$reason = trim((string)($body['reason'] ?? ''));
if ($documentId === '' || strlen($documentId) > 50 || $expectedMovement <= 0 || $expectedDestination <= 0 || $expectedCorrection === false || $expectedCorrection === null || $destination <= 0) {
    $reject('invalid_request', 'Open the current folder and select a new receiving office before correcting its destination.', 400);
}
if (($body['correction_confirmed'] ?? false) !== true) $reject('confirmation_required', 'Confirm that this corrects a recording mistake and the folder has not been received.', 400);
if (mb_strlen($reason) < 5 || mb_strlen($reason) > 1000) $reject('correction_reason_required', 'Enter the reason for this correction (5–1000 characters).', 400);
smartflow_ensure_movement_corrections($pdo);
smartflow_ensure_movement_requests($pdo);
smartflow_ensure_documents_filed_columns($pdo);

try {
    $pdo->beginTransaction();
    // Server-owned discriminator: a correction can never replay an ordinary movement's result.
    $requestBody = $body;
    $requestBody['_smartflow_operation'] = 'destination_correction';
    smartflow_lock_movement_request($pdo, $requestId, $user['id'], $documentId, $requestBody);
    $stmt = $pdo->prepare('SELECT id, type, filed_at FROM documents WHERE id=? FOR UPDATE');
    $stmt->execute([$documentId]);
    $document = $stmt->fetch();
    $user = smartflow_require_locked_writer($pdo, $user);
    if (!$document) $reject('document_not_found', 'Document not found.', 404);
    if (!empty($document['filed_at'])) $reject('already_filed', 'This folder is filed. Its destination cannot be corrected.');
    $stmt = $pdo->prepare('SELECT * FROM movements WHERE document_id=? ORDER BY scanned_at DESC, id DESC LIMIT 1');
    $stmt->execute([$documentId]);
    $last = $stmt->fetch();
    if (!$last || $last['status'] !== 'OUT' || (int)$last['id'] !== $expectedMovement) $reject('document_changed', 'The folder was received or moved since you opened it. Refresh its current location.');
    if ((int)$last['office_id'] !== $user['office_id']) $reject('wrong_office', 'Only staff assigned to the sending office can correct this destination.', 403);
    $stmt = $pdo->prepare('SELECT COALESCE(MAX(id),0) FROM movement_destination_corrections WHERE movement_id=?');
    $stmt->execute([$last['id']]);
    if ((int)$last['destination_office_id'] !== $expectedDestination || (int)$stmt->fetchColumn() !== $expectedCorrection) $reject('document_changed', 'The destination changed since you opened it. Refresh before making another correction.');
    if ($destination === $user['office_id'] || $destination === $expectedDestination) $reject('same_destination', 'Select a different receiving office, excluding the sending office.', 400);
    $stmt = $pdo->prepare('SELECT id, name, code FROM offices WHERE id=?');
    $stmt->execute([$destination]);
    $destOffice = $stmt->fetch();
    if (!$destOffice) $reject('destination_not_found', 'Destination office not found.', 400);

    $isReturn = $last['is_return'] === null ? str_starts_with((string)$last['remarks'], 'Returned to ') : (bool)$last['is_return'];
    if ($isReturn) {
        $stmt = $pdo->prepare("SELECT 1 FROM movements WHERE document_id=? AND office_id=? AND status='IN' LIMIT 1");
        $stmt->execute([$documentId, $destination]);
        if (!$stmt->fetchColumn()) $reject('return_not_previous_holder', 'A returned folder can only be addressed to an office that already received it.', 400);
    }
    // A completed Treasury DV can only have its optional Accounting return; correction cannot reopen its route.
    $complete = smartflow_sql_trail_complete_known_latest('d', 'previous', 'sender');
    $stmt = $pdo->prepare("SELECT $complete AS complete FROM documents d
        JOIN movements previous ON previous.id=(SELECT p.id FROM movements p WHERE p.document_id=d.id AND p.id<>? ORDER BY p.scanned_at DESC,p.id DESC LIMIT 1)
        JOIN offices sender ON sender.id=previous.office_id WHERE d.id=?");
    $stmt->execute([$last['id'], $documentId]);
    if ((bool)$stmt->fetchColumn() && ($user['office_code'] !== 'TRE' || $destOffice['code'] !== 'ACC')) $reject('route_finished', 'This completed route only permits its optional return from Treasury to Accounting.');

    $stmt = $pdo->prepare('INSERT INTO movement_destination_corrections (movement_id,document_id,previous_destination_office_id,destination_office_id,reason,corrected_by,corrected_by_office_id) VALUES (?,?,?,?,?,?,?)');
    $stmt->execute([$last['id'], $documentId, $expectedDestination, $destination, $reason, $user['id'], $user['office_id']]);
    $correctionId = (int)$pdo->lastInsertId();
    $pdo->prepare('UPDATE movements SET destination_office_id=? WHERE id=?')->execute([$destination, $last['id']]);
    $message = 'Recorded destination corrected to ' . $destOffice['name'] . '. No receipt or new handoff was recorded.';
    $response = ['success' => true, 'message' => $message, 'document_id' => $documentId,
        'movement_id' => (int)$last['id'], 'correction_id' => $correctionId, 'status' => 'OUT',
        'previous_destination_office_id' => $expectedDestination, 'destination_office_id' => $destination,
        'destination_office_name' => $destOffice['name'], 'destination_office_code' => $destOffice['code']];
    $pdo->prepare("UPDATE movement_requests SET state='recorded',response_json=? WHERE request_id=?")->execute([json_encode($response, JSON_THROW_ON_ERROR), $requestId]);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    smartflow_reject_write_conflict($pdo, $e);
    smartflow_write_audit_log($pdo, 'movement.destination_corrected', $documentId, $user['id'], $user['office_id'], 'OUT', 'failed', 'Could not correct destination');
    json_response(['success' => false, 'message' => 'Could not correct the destination. Check the saved outcome before retrying.', 'scan_error' => 'server_error'], 500);
}
smartflow_write_audit_log($pdo, 'movement.destination_corrected', $documentId, $user['id'], $user['office_id'], 'OUT', 'success', $message,
    ['movement_id' => (int)$last['id'], 'correction_id' => $correctionId, 'previous_destination_office_id' => $expectedDestination, 'destination_office_id' => $destination]);
json_response($response);
