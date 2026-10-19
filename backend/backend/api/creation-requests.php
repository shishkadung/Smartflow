<?php
require __DIR__ . '/config.php';
require_once __DIR__ . '/creation-requests-helper.php';
if ($_SERVER['REQUEST_METHOD'] !== 'GET') json_response(['success'=>false,'message'=>'Method not allowed'],405);
$userId = require_user_id();
try { $id = smartflow_creation_id($_GET['operation_id'] ?? null); }
catch (InvalidArgumentException $e) { json_response(['success'=>false,'message'=>$e->getMessage()],400); }
$kind = (string)($_GET['kind'] ?? '');
if ($id === null || !in_array($kind, ['document','request'], true)) json_response(['success'=>false,'message'=>'Valid operation ID and kind required'],400);
smartflow_ensure_creation_requests($pdo);
$select = $pdo->prepare('SELECT response_json FROM creation_requests WHERE operation_id=? AND user_id=? AND kind=?');
$select->execute([$id,$userId,$kind]);
$row = $select->fetch();
json_response(['success'=>true,'state'=>$row && $row['response_json'] !== null ? 'recorded' : 'unknown',
    'result'=>$row && $row['response_json'] !== null ? json_decode($row['response_json'],true,64,JSON_THROW_ON_ERROR) : null]);
