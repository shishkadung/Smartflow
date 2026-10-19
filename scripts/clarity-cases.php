<?php
/** Only called by the guarded disposable API regression harness. */
function smartflow_test_clarity(PDO $pdo, array $tokens): void
{
    if (!preg_match('/^smartflow_request_test_[a-f0-9]{12}$/D', (string)$pdo->query('SELECT DATABASE()')->fetchColumn())) {
        throw new RuntimeException('Clarity tests require the disposable database');
    }
    $body = ['office_id' => 4, 'document_type' => 'Disbursement Voucher', 'max_hours' => 60, 'out_unconfirmed_hours' => 29];
    [$http, $saved] = api('admin-thresholds-update.php', $tokens['admin'], $body);
    check($http === 200 && $saved['threshold']['max_hours'] === 60 && $saved['threshold']['out_unconfirmed_hours'] === 29,
        'admin can explicitly save both processing and receipt alert limits');
    unset($body['out_unconfirmed_hours']); $body['max_hours'] = 84;
    [$http, $partial] = api('admin-thresholds-update.php', $tokens['admin'], $body);
    $row = $pdo->query("SELECT max_hours,out_unconfirmed_hours FROM processing_thresholds WHERE office_id=4 AND document_type='Disbursement Voucher'")->fetch();
    check($http === 200 && $partial['threshold']['max_hours'] === 84 && $partial['threshold']['out_unconfirmed_hours'] === 29
        && (int)$row['max_hours'] === 84 && (int)$row['out_unconfirmed_hours'] === 29,
        'older processing-only saves preserve the existing receipt limit instead of resetting it');
    $audit = json_decode($pdo->query("SELECT meta_json FROM audit_logs WHERE event_type='threshold.update' ORDER BY id DESC LIMIT 1")->fetchColumn(), true);
    check($audit['old_max_hours'] === 60 && $audit['max_hours'] === 84
        && $audit['old_out_unconfirmed_hours'] === 29 && $audit['out_unconfirmed_hours'] === 29,
        'partial alert-limit changes retain accurate old and new values in audit evidence');
    $newType = 'Others: clarity ' . bin2hex(random_bytes(4));
    $new = ['office_id' => 2, 'document_type' => $newType, 'max_hours' => 48];
    check(api('admin-thresholds-update.php', $tokens['admin'], $new)[0] === 400,
        'a new alert rule requires an explicit receipt limit rather than guessing one');
    $count = $pdo->prepare('SELECT COUNT(*) FROM processing_thresholds WHERE office_id=2 AND document_type=?');
    $count->execute([$newType]);
    check((int)$count->fetchColumn() === 0, 'a rejected incomplete alert rule writes no threshold');
    $new['out_unconfirmed_hours'] = 36;
    [$http, $created] = api('admin-thresholds-update.php', $tokens['admin'], $new);
    check($http === 200 && $created['threshold']['out_unconfirmed_hours'] === 36,
        'an explicitly completed new alert rule saves successfully');
    foreach (['eng', 'head'] as $role) {
        check(api('admin-thresholds-update.php', $tokens[$role], $new)[0] === 403,
            "$role cannot change municipal alert limits");
    }
    foreach ([0, 169, null] as $invalidHours) {
        $invalid = $body; $invalid['out_unconfirmed_hours'] = $invalidHours;
        check(api('admin-thresholds-update.php', $tokens['admin'], $invalid)[0] === 400,
            'explicit invalid receipt limits cannot invoke omission compatibility');
    }
    $body['office_id'] = 999999;
    check(api('admin-thresholds-update.php', $tokens['admin'], $body)[0] === 404,
        'partial alert-rule updates retain office existence checks');
}
