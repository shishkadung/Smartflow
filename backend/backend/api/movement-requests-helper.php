<?php
declare(strict_types=1);
// The request row and movement commit together. Cancellation takes the same lock,
// including a tombstone for requests which have not arrived at the server yet.
function smartflow_ensure_movement_requests(PDO $pdo): void {
 $pdo->exec("CREATE TABLE IF NOT EXISTS movement_requests (
 request_id CHAR(32) PRIMARY KEY, user_id INT NOT NULL, document_id VARCHAR(50) NOT NULL,
 body_hash CHAR(64) NULL, state VARCHAR(12) NOT NULL, response_json LONGTEXT NULL,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 INDEX movement_request_owner (user_id, created_at)) ENGINE=InnoDB");
}
function smartflow_request_id(mixed $value): string {
 if (!is_string($value) || !preg_match('/^[a-f0-9]{32}$/D', $value))
  json_response(['success'=>false,'message'=>'Invalid movement request ID'],400);
 return $value;
}
function smartflow_request_hash(array $body): string {
 unset($body['request_id'], $body['access_token'], $body['token']);
 $sort = static function(array $value) use (&$sort): array {
  if (!array_is_list($value)) ksort($value);
  foreach($value as &$item) if(is_array($item)) $item=$sort($item);
  return $value;
 };
 return hash('sha256', json_encode($sort($body), JSON_THROW_ON_ERROR));
}
function smartflow_lock_movement_request(PDO $pdo, string $id, int $userId, string $doc, array $body): void {
 $hash=smartflow_request_hash($body);
 $insert=$pdo->prepare("INSERT IGNORE INTO movement_requests (request_id,user_id,document_id,body_hash,state) VALUES (?,?,?,?,'pending')");
 $insert->execute([$id,$userId,$doc,$hash]);
 $stmt=$pdo->prepare('SELECT * FROM movement_requests WHERE request_id=? FOR UPDATE'); $stmt->execute([$id]); $row=$stmt->fetch();
 if ((int)$row['user_id'] !== $userId || $row['document_id'] !== $doc || ($row['body_hash']!==null && !hash_equals($row['body_hash'],$hash))) {
  $pdo->rollBack(); json_response(['success'=>false,'message'=>'Request ID belongs to another action'],409);
 }
 if ($row['state']==='cancelled') { $pdo->rollBack(); json_response(['success'=>false,'message'=>'This request was cancelled. Refresh the document before another action.'],409); }
 if ($row['state']==='recorded') { $response=json_decode($row['response_json'],true,32,JSON_THROW_ON_ERROR); $pdo->commit(); json_response($response); }
}
