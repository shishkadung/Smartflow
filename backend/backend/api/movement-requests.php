<?php
require __DIR__ . '/config.php';
require_once __DIR__ . '/movements-helper.php';
require_once __DIR__ . '/movement-requests-helper.php';
$user=smartflow_require_authenticated_user($pdo,require_user_id());
$method=$_SERVER['REQUEST_METHOD'];
if (!in_array($method,['GET','POST'],true)) json_response(['success'=>false,'message'=>'Method not allowed'],405);
$body=$method==='POST'?get_json_body():$_GET;
$id=smartflow_request_id($body['request_id']??null);
smartflow_ensure_movement_requests($pdo);
$pdo->beginTransaction();
if ($method==='POST') {
 if (($body['action']??'')!=='cancel') { $pdo->rollBack(); json_response(['success'=>false,'message'=>'Only cancellation is supported'],400); }
 $doc=trim((string)($body['document_id']??''));
 if ($doc==='' || strlen($doc)>50) { $pdo->rollBack(); json_response(['success'=>false,'message'=>'Document ID required'],400); }
 $stmt=$pdo->prepare("INSERT IGNORE INTO movement_requests (request_id,user_id,document_id,state) VALUES (?,?,?,'cancelled')"); $stmt->execute([$id,$user['id'],$doc]);
}
$stmt=$pdo->prepare('SELECT * FROM movement_requests WHERE request_id=? FOR UPDATE'); $stmt->execute([$id]); $row=$stmt->fetch();
if ($row && (int)$row['user_id']!==$user['id']) { $pdo->rollBack(); json_response(['success'=>false,'message'=>'Request is not owned by this account'],403); }
if ($method==='POST' && $row['document_id']!==$doc) { $pdo->rollBack(); json_response(['success'=>false,'message'=>'Request is for a different document'],409); }
if ($method==='POST' && $row['state']==='pending') {
 $stmt=$pdo->prepare("UPDATE movement_requests SET state='cancelled' WHERE request_id=?"); $stmt->execute([$id]); $row['state']='cancelled';
}
$pdo->commit();
json_response(['success'=>true,'state'=>$row['state']??'unknown','result'=>($row['state']??'')==='recorded'?json_decode($row['response_json'],true,32,JSON_THROW_ON_ERROR):null]);
