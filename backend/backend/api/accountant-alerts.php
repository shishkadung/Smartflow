<?php

// GET /accountant-alerts.php

// Municipal-wide alerts using configured processing thresholds.



require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/routing-helper.php';
smartflow_ensure_documents_filed_columns($pdo);

smartflow_ensure_documents_due_column($pdo);



if ($_SERVER['REQUEST_METHOD'] !== 'GET') {

    json_response(['success' => false, 'message' => 'Method not allowed'], 405);

}



smartflow_require_admin($pdo, require_user_id());



$trailCompleteSql = smartflow_sql_trail_complete('d.id');
$defaults = smartflow_threshold_defaults();
$defaultIn = (int)$defaults['max_hours'];
$defaultOut = (int)$defaults['out_unconfirmed_hours'];
$sql = "

    SELECT

        d.id AS document_id,

        d.title,

        d.type AS document_type,

        d.due_at AS document_due_at,

        latest.status        AS last_status,

        latest.office_id     AS last_office_id,

        latest.scanned_at    AS last_scanned_at,

        latest.office_name   AS last_office_name,

        latest.office_code   AS last_office_code,

        TIMESTAMPDIFF(HOUR, latest.scanned_at, NOW()) AS hours_pending,
        COALESCE(rule.max_hours, $defaultIn) AS rule_max_hours,
        COALESCE(rule.out_unconfirmed_hours, $defaultOut) AS rule_out_hours

    FROM documents d

    JOIN (

        SELECT m.document_id, m.status, m.office_id, m.scanned_at, o.name AS office_name, o.code AS office_code

        FROM movements m

        JOIN offices o ON o.id = m.office_id

        WHERE m.id = (

            SELECT m2.id FROM movements m2

            WHERE m2.document_id = m.document_id

            ORDER BY m2.scanned_at DESC, m2.id DESC LIMIT 1

        )

    ) latest ON latest.document_id = d.id
    LEFT JOIN processing_thresholds rule ON rule.office_id=latest.office_id
        AND rule.document_type=d.type AND rule.is_active=1
    WHERE NOT {$trailCompleteSql}

    ORDER BY latest.scanned_at ASC

";



$rows = $pdo->query($sql);



$alerts = [];

foreach ($rows as $r) {

    // Select the complete candidate cohort; classification must precede any UI cap.
    // Joined rules avoid repeating schema/default/threshold queries for every folder.
    $alert = smartflow_build_alert_from_row($pdo, $r, 0, [
        'max_hours'=>(int)$r['rule_max_hours'],
        'out_unconfirmed_hours'=>(int)$r['rule_out_hours'],
    ]);

    if ($alert !== null) {

        $alerts[] = $alert;

    }

}



json_response([

    'success' => true,

    'alerts'  => $alerts,

]);

