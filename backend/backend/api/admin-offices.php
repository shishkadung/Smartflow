<?php

// GET /admin-offices.php

// Pilot offices and processing thresholds from database.

// Auth: Bearer token required.



require __DIR__ . '/config.php';

require_once __DIR__ . '/thresholds-helper.php';



if ($_SERVER['REQUEST_METHOD'] !== 'GET') {

    json_response(['success' => false, 'message' => 'Method not allowed'], 405);

}



require_user_id();



$offices = smartflow_list_thresholds_by_office($pdo);



json_response([

    'success' => true,

    'offices' => $offices,

]);

