<?php

// GET /accountant-alerts.php

// Municipal-wide alerts using configured processing thresholds.



require __DIR__ . '/config.php';
require_once __DIR__ . '/thresholds-helper.php';

smartflow_ensure_documents_due_column($pdo);



if ($_SERVER['REQUEST_METHOD'] !== 'GET') {

    json_response(['success' => false, 'message' => 'Method not allowed'], 405);

}



require_user_id();



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

        TIMESTAMPDIFF(HOUR, latest.scanned_at, NOW()) AS hours_pending

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

    ORDER BY latest.scanned_at ASC

    LIMIT 100

";



$rows = $pdo->query($sql)->fetchAll();



$alerts = [];

foreach ($rows as $r) {

    $alert = smartflow_build_alert_from_row($pdo, $r, 0);

    if ($alert !== null) {

        $alerts[] = $alert;

    }

}



json_response([

    'success' => true,

    'alerts'  => $alerts,

]);

