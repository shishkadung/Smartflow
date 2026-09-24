<?php
// POST /document-requests-update.php
// Body: {
//   "request_id": 1,
//   "action": "approve|reject|fulfill|cancel",
//   "review_notes": "...",
//   "related_document_id": "DOC-2026-000001"  // optional on fulfill
// }

require __DIR__ . '/config.php';
require_once __DIR__ . '/document-requests-helper.php';

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

$body = get_json_body();
$requestId = (int)($body['request_id'] ?? 0);
$action = strtolower(trim((string)($body['action'] ?? '')));
$notes = trim((string)($body['review_notes'] ?? ''));
$docId = trim((string)($body['related_document_id'] ?? ''));

if ($requestId <= 0 || !in_array($action, ['approve', 'reject', 'fulfill', 'cancel'], true)) {
    json_response(['success' => false, 'message' => 'request_id and valid action required'], 400);
}

$stmtReq = $pdo->prepare(SMARTFLOW_DR_SELECT . ' WHERE r.id = :id LIMIT 1');
$stmtReq->execute([':id' => $requestId]);
$row = $stmtReq->fetch();
if (!$row) {
    json_response(['success' => false, 'message' => 'Request not found'], 404);
}

$isRequester = (int)$row['requested_by'] === $userId;
$isHandlerOffice = (int)$row['handler_office_id'] === (int)$user['office_id'];
$isAdmin = $user['role'] === 'admin';

if ($action === 'cancel') {
    if (!$isRequester && !$isAdmin) {
        json_response(['success' => false, 'message' => 'Only the requester or admin can cancel'], 403);
    }
    if (!in_array($row['status'], ['pending', 'approved'], true)) {
        json_response(['success' => false, 'message' => 'Request cannot be cancelled in current status'], 409);
    }
    $pdo->prepare("
        UPDATE document_requests SET status = 'cancelled', reviewed_by = :uid, reviewed_at = NOW(), review_notes = :n
        WHERE id = :id
    ")->execute([':uid' => $userId, ':n' => $notes ?: 'Cancelled', ':id' => $requestId]);
} elseif (in_array($action, ['approve', 'reject', 'fulfill'], true)) {
    $category = strtolower((string)$row['document_category']);
    $officeCode = strtoupper((string)$user['office_code']);
    // ACC approves/rejects DV tickets; Treasury closes them after payment (client discovery).
    $isTreasuryPaymentCloser = $action === 'fulfill'
        && $category === 'disbursement'
        && $officeCode === 'TRE';

    if ($action === 'approve' || $action === 'reject') {
        if (!$isHandlerOffice && !$isAdmin) {
            json_response(['success' => false, 'message' => 'Only the handler office or admin can process this request'], 403);
        }
    } elseif (!$isTreasuryPaymentCloser && !$isHandlerOffice && !$isAdmin) {
        json_response(['success' => false, 'message' => 'Only the handler office or admin can process this request'], 403);
    }

    if ($action === 'approve') {
        if ($row['status'] !== 'pending') {
            json_response(['success' => false, 'message' => 'Only pending requests can be approved'], 409);
        }
        $pdo->prepare("
            UPDATE document_requests
            SET status = 'approved', reviewed_by = :uid, reviewed_at = NOW(), review_notes = :n
            WHERE id = :id
        ")->execute([':uid' => $userId, ':n' => $notes ?: null, ':id' => $requestId]);
    } elseif ($action === 'reject') {
        if ($row['status'] !== 'pending') {
            json_response(['success' => false, 'message' => 'Only pending requests can be rejected'], 409);
        }
        $pdo->prepare("
            UPDATE document_requests
            SET status = 'rejected', reviewed_by = :uid, reviewed_at = NOW(), review_notes = :n
            WHERE id = :id
        ")->execute([':uid' => $userId, ':n' => $notes ?: 'Rejected', ':id' => $requestId]);
    } else {
        // Fulfill
        if ($category === 'disbursement') {
            if ($row['status'] !== 'approved') {
                json_response([
                    'success' => false,
                    'message' => 'Accounting must accept the DV ticket before Treasury marks payment released',
                ], 409);
            }
            if (!$isAdmin && $officeCode !== 'TRE') {
                json_response([
                    'success' => false,
                    'message' => 'Treasury marks disbursement requests complete after payment release',
                ], 403);
            }
        } elseif (!in_array($row['status'], ['pending', 'approved'], true)) {
            json_response(['success' => false, 'message' => 'Request cannot be fulfilled in current status'], 409);
        }

        if ($docId !== '') {
            $chk = $pdo->prepare('SELECT id FROM documents WHERE id = :id LIMIT 1');
            $chk->execute([':id' => $docId]);
            if (!$chk->fetch()) {
                json_response(['success' => false, 'message' => 'related_document_id not found'], 400);
            }
        }
        $defaultNote = $category === 'disbursement'
            ? 'Payment released at Treasury'
            : null;
        $pdo->prepare("
            UPDATE document_requests
            SET status = 'fulfilled',
                reviewed_by = COALESCE(reviewed_by, :uid),
                reviewed_at = COALESCE(reviewed_at, NOW()),
                review_notes = COALESCE(:n, review_notes),
                related_document_id = COALESCE(NULLIF(:doc, ''), related_document_id),
                fulfilled_at = NOW()
            WHERE id = :id
        ")->execute([
            ':uid' => $userId,
            ':n'   => $notes !== '' ? $notes : $defaultNote,
            ':doc' => $docId,
            ':id'  => $requestId,
        ]);
    }
}

$stmtReq->execute([':id' => $requestId]);
$updated = $stmtReq->fetch();

json_response([
    'success' => true,
    'message' => 'Request ' . $action . 'd',
    'request' => smartflow_format_document_request_row($updated),
]);
