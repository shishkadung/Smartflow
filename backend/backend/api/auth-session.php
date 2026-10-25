<?php
// GET: validate the existing session without issuing another token.
require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}
$id = require_user_id();
$user = smartflow_fetch_user_by_id($pdo, $id);
if (!$user) {
    json_response(['success' => false, 'message' => 'Missing or invalid token'], 401);
}
json_response(['success' => true, 'user' => smartflow_user_payload($user)]);
