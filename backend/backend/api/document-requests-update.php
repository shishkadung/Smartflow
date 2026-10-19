<?php
// POST /document-requests-update.php
// Body: {
//   "request_id": 1,
//   "action": "approve|reject|fulfill|cancel|link",
//   "expected_status": "pending",        // optional compatibility guard
//   "expected_revision": "<revision>",   // revision returned with the displayed request
//   "review_notes": "...",
//   "related_document_id": "DOC-2026-000001"  // required on link; optional on fulfill
// }

require __DIR__ . '/config.php';
require_once __DIR__ . '/document-requests-helper.php';
require_once __DIR__ . '/audit-helper.php';

smartflow_ensure_document_requests($pdo);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
$stmt = $pdo->prepare('
    SELECT u.id, u.role, u.office_id, o.code AS office_code
    FROM users u
    JOIN offices o ON o.id = u.office_id
    WHERE u.id = :id AND u.is_active = 1
    LIMIT 1
');
$stmt->execute([':id' => $userId]);
$user = $stmt->fetch();
if (!$user) {
    json_response(['success' => false, 'message' => 'User not found'], 401);
}
if (!in_array($user['role'], ['staff', 'head', 'admin'], true)) {
    json_response(['success'=>false,'message'=>'Your role cannot decide or link document requests'],403);
}

$body = get_json_body();
$requestId = (int)($body['request_id'] ?? 0);
$action = strtolower(trim((string)($body['action'] ?? '')));
$notes = trim((string)($body['review_notes'] ?? ''));
$docId = trim((string)($body['related_document_id'] ?? ''));
$expectedStatus = isset($body['expected_status']) ? trim((string)$body['expected_status']) : null;
$expectedRevision = isset($body['expected_revision']) ? trim((string)$body['expected_revision']) : null;

if ($requestId <= 0 || !in_array($action, ['approve', 'reject', 'fulfill', 'cancel', 'link'], true)) {
    json_response(['success' => false, 'message' => 'request_id and valid action required'], 400);
}
if ($expectedStatus !== null && !in_array($expectedStatus, ['pending', 'approved', 'rejected', 'fulfilled', 'cancelled'], true)) {
    json_response(['success' => false, 'message' => 'expected_status must be a valid request status'], 400);
}
if ($expectedRevision !== null && !preg_match('/^[a-f0-9]{64}$/', $expectedRevision)) {
    json_response(['success' => false, 'message' => 'expected_revision must be the revision returned with the request'], 400);
}
$isAdmin = $user['role'] === 'admin';
// Every decision reads the authoritative state under the same row lock as its write.
// Guards are optional for old clients; current clients send the displayed state/revision.
$pdo->beginTransaction();
try {
    $locked = $pdo->prepare('SELECT * FROM document_requests WHERE id = :id LIMIT 1 FOR UPDATE');
    $locked->execute([':id' => $requestId]);
    $row = $locked->fetch();
    if (!$row) throw new InvalidArgumentException('Request not found', 404);
    $isRequester = (int)$row['requested_by'] === $userId;
    $isHandlerOffice = (int)$row['handler_office_id'] === (int)$user['office_id'];
    if (($expectedStatus !== null && $row['status'] !== $expectedStatus)
        || ($expectedRevision !== null && !hash_equals(smartflow_request_revision($row), $expectedRevision))) {
        throw new InvalidArgumentException('This request changed. Refresh and review the latest details before deciding.', 409);
    }
    if ($action === 'link') {
        if ($docId === '') throw new InvalidArgumentException('related_document_id is required to link a folder', 400);
        smartflow_link_request_document($pdo, $user, $requestId, $docId);
    } elseif ($action === 'cancel') {
        if (!$isRequester && !$isAdmin) {
            throw new InvalidArgumentException('Only the requester or admin can cancel', 403);
        }
        if (!in_array($row['status'], ['pending', 'approved'], true)) {
            throw new InvalidArgumentException('Request cannot be cancelled in current status', 409);
        }
        $pdo->prepare("
            UPDATE document_requests SET status = 'cancelled', cancelled_by = :uid,
                cancelled_office_id = :office, cancelled_at = NOW(), cancelled_notes = :n
            WHERE id = :id AND status = :status
        ")->execute([':uid' => $userId, ':office' => (int)$user['office_id'], ':n' => $notes,
            ':id' => $requestId, ':status' => $row['status']]);
    } else {
        $category = strtolower((string)$row['document_category']);
        $officeCode = strtoupper((string)$user['office_code']);
        // Accounting accepts DV tickets; Treasury closes them after actual payment release.
        $isTreasuryPaymentCloser = $action === 'fulfill'
            && $category === 'disbursement' && $officeCode === 'TRE';
        if (!$isTreasuryPaymentCloser && !$isHandlerOffice && !$isAdmin) {
            throw new InvalidArgumentException('Only the handler office or admin can process this request', 403);
        }
        if ($action === 'approve' || $action === 'reject') {
            if ($row['status'] !== 'pending') {
                throw new InvalidArgumentException('Only pending requests can be ' . ($action === 'approve' ? 'approved' : 'rejected'), 409);
            }
            if ($action === 'reject' && $notes === '') {
                throw new InvalidArgumentException('A reason is required when declining a request', 400);
            }
            $pdo->prepare("
                UPDATE document_requests
                SET status = :next_status, reviewed_by = :uid, reviewed_office_id = :office, reviewed_at = NOW(), review_notes = :n
                WHERE id = :id AND status = 'pending'
            ")->execute([
                ':next_status' => $action === 'approve' ? 'approved' : 'rejected',
                ':uid' => $userId, ':office' => (int)$user['office_id'], ':n' => $notes !== '' ? $notes : null, ':id' => $requestId,
            ]);
        } else {
            if ($category === 'disbursement') {
                if ($row['status'] !== 'approved') {
                    throw new InvalidArgumentException('Accounting must accept the DV ticket before Treasury marks payment released', 409);
                }
                if (!$isAdmin && $officeCode !== 'TRE') {
                    throw new InvalidArgumentException('Treasury marks disbursement requests complete after payment release', 403);
                }
            } elseif (!in_array($row['status'], ['pending', 'approved'], true)) {
                throw new InvalidArgumentException('Request cannot be fulfilled in current status', 409);
            }
            $linkedDocumentId = trim((string)($row['related_document_id'] ?? ''));
            if ($docId !== '' && $docId !== $linkedDocumentId) {
                // Closing cannot bypass Accounting/handler linking authority or accepted status.
                smartflow_assert_request_link_authority($user, $row);
            }
            $completionDocumentId = $docId !== '' ? $docId : $linkedDocumentId;
            if ($completionDocumentId !== '') {
                // Existing links stay usable by Treasury, but must still be valid handler evidence.
                smartflow_validate_request_document($pdo, $row, $completionDocumentId);
            }
            $defaultNote = $category === 'disbursement' ? 'Payment released at Treasury' : '';
            $pdo->prepare("
                UPDATE document_requests
                SET status = 'fulfilled',
                    fulfilled_notes = :n,
                    related_document_id = COALESCE(NULLIF(:doc, ''), related_document_id),
                    fulfilled_at = NOW(),
                    fulfilled_by = :uid,
                    fulfilled_office_id = :fulfilled_office_id
                WHERE id = :id AND status = :status
            ")->execute([
                ':uid' => $userId, ':n' => $notes !== '' ? $notes : $defaultNote,
                ':doc' => $docId, ':id' => $requestId, ':status' => $row['status'],
                ':fulfilled_office_id' => (int)$user['office_id'],
            ]);
        }
    }
    $stmtReq = $pdo->prepare(SMARTFLOW_DR_SELECT . ' WHERE r.id = :id LIMIT 1');
    $stmtReq->execute([':id' => $requestId]);
    $updated = $stmtReq->fetch();
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    if ($e instanceof InvalidArgumentException) {
        $response = ['success' => false, 'message' => $e->getMessage()];
        if ($e->getCode() === 409) $response['request_error'] = 'request_conflict';
        json_response($response, $e->getCode());
    }
    throw $e;
}

$requestLabel = (string)($row['request_code'] ?? ('#' . $requestId));
smartflow_audit_action(
    $pdo,
    'request.' . $action,
    $userId,
    ucfirst($action) . ' request ' . $requestLabel . ($notes !== '' ? ': ' . $notes : ''),
    [
        'request_id'        => $requestId,
        'request_code'      => $row['request_code'] ?? null,
        'category'          => $row['document_category'] ?? null,
        'previous_status'   => $row['status'],
        'new_status'        => $updated['status'] ?? null,
        'handler_office_id' => (int)$row['handler_office_id'],
        'as_admin'          => $isAdmin,
    ],
    $docId !== '' ? $docId : null
);

json_response([
    'success' => true,
    'message' => 'Request ' . [
        'approve' => 'approved',
        'reject'  => 'rejected',
        'fulfill' => 'fulfilled',
        'cancel'  => 'cancelled',
        'link'    => 'linked to folder',
    ][$action],
    'request' => smartflow_format_document_request_row($updated),
]);
