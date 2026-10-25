<?php
/** Only called by the generated-schema API regression harness. No live rules are changed. */
function smartflow_test_threshold_continuation(PDO $pdo, array $tokens): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Threshold continuation cases require the disposable database');
    }
    $type = 'Others: Threshold continuation';
    $insert = $pdo->prepare('INSERT INTO documents (id,title,type,origin_office_id,created_by,due_at,filed_at)
        VALUES (?,"Synthetic threshold continuation",?,1,1,?,?)');
    $movement = $pdo->prepare('INSERT INTO movements (document_id,office_id,status,user_id,destination_office_id,scanned_at)
        VALUES (?,1,?,1,?,DATE_SUB(NOW(),INTERVAL 12 HOUR))');
    $ids = ['in' => 'DOC-1800-000101', 'out' => 'DOC-1800-000102',
        'manual' => 'DOC-1800-000103', 'filed' => 'DOC-1800-000104'];
    foreach ($ids as $kind => $id) {
        $insert->execute([$id, $type, $kind === 'manual' ? date('Y-m-d H:i:s', time() - 3600) : null,
            $kind === 'filed' ? date('Y-m-d H:i:s') : null]);
        $movement->execute([$id, $kind === 'out' ? 'OUT' : 'IN', $kind === 'out' ? 3 : null]);
    }
    $state = static function (int $limit, bool $late) use ($tokens, $type, $ids): void {
        [$http, $saved] = api('admin-thresholds-update.php', $tokens['admin'], [
            'office_id' => 1, 'document_type' => $type, 'max_hours' => $limit, 'out_unconfirmed_hours' => $limit,
        ]);
        check($http === 200 && $saved['threshold']['max_hours'] === $limit
            && $saved['threshold']['out_unconfirmed_hours'] === $limit,
            "continuation saves $limit-hour processing and receipt rules in the disposable schema");
        foreach (['in', 'out'] as $kind) {
            [$http, $payload] = api('documents-show.php?id=' . $ids[$kind], $tokens['eng']);
            $doc = $payload['document'] ?? [];
            check($http === 200 && $doc['is_overdue'] === $late
                && $doc['due_at'] === smartflow_due_at($doc['last_scanned_at'], $limit),
                "continuation $kind detail immediately uses the saved $limit-hour rule");
        }
        [$http, $queue] = api('office-documents.php?limit=100&overdue=1&search=DOC-1800-00010', $tokens['eng']);
        $actual = array_column($queue['documents'] ?? [], 'id'); sort($actual);
        $expected = $late ? [$ids['in'], $ids['out'], $ids['manual']] : [$ids['manual']]; sort($expected);
        check($http === 200 && $actual === $expected && $queue['total'] === count($expected),
            "continuation office overdue filter updates after the $limit-hour save and retains the explicit deadline");
        foreach (['alerts-list.php?office_id=1', 'accountant-alerts.php'] as $path) {
            [$http, $alerts] = api($path, $tokens['admin']);
            $actual = array_values(array_intersect($ids, array_column($alerts['alerts'] ?? [], 'document_id'))); sort($actual);
            check($http === 200 && $actual === $expected,
                "continuation $path updates after the $limit-hour save without alerting on a filed folder");
        }
        [$http, $municipal] = api('office-documents.php?scope=municipal&limit=100&overdue=1&search=DOC-1800-00010', $tokens['admin']);
        $actual = array_column($municipal['documents'] ?? [], 'id'); sort($actual);
        $expected = $late ? [$ids['in'], $ids['manual']] : [$ids['manual']]; sort($expected);
        check($http === 200 && $actual === $expected,
            "continuation municipal processing-overdue keeps transit receipt alerts separate at $limit hours");
    };
    $state(10, true);
    $state(14, false);
    $state(10, true);

    $pending = requestFixture(handler: 4, category: 'disbursement', status: 'pending');
    foreach (['tre', 'admin'] as $who) {
        [$http] = api('document-requests-update.php', $tokens[$who], [
            'request_id' => $pending, 'action' => 'fulfill', 'expected_status' => 'pending',
        ]);
        check($http === 409
            && $pdo->query("SELECT status FROM document_requests WHERE id=$pending")->fetchColumn() === 'pending',
            "continuation $who cannot release a DV before Accounting acceptance");
    }
    $dv = requestFixture(handler: 4, category: 'disbursement');
    $requestBefore = $pdo->query("SELECT * FROM document_requests WHERE id=$dv")->fetch();
    $movementCount = (int)$pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn();
    [$http, $closed] = api('document-requests-update.php', $tokens['tre'], [
        'request_id' => $dv, 'action' => 'fulfill', 'expected_status' => 'approved',
        'expected_revision' => smartflow_request_revision($requestBefore),
        'review_notes' => 'Synthetic actual payment-release confirmation',
    ]);
    check($http === 200 && $closed['request']['status'] === 'fulfilled' && !$closed['request']['is_overdue']
        && $closed['request']['fulfilled_notes'] === 'Synthetic actual payment-release confirmation'
        && (int)$pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn() === $movementCount,
        'continuation DV payment release closes only the accepted ticket and records separate outcome notes');
    [$http] = api('document-requests-update.php', $tokens['tre'], [
        'request_id' => $dv, 'action' => 'fulfill', 'expected_status' => 'approved',
        'expected_revision' => smartflow_request_revision($requestBefore),
    ]);
    check($http === 409 && (int)$pdo->query('SELECT COUNT(*) FROM movements')->fetchColumn() === $movementCount,
        'continuation a repeated stale payment-release confirmation is rejected without custody changes');
}
