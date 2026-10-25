<?php
// Office heads publish attachment names; actual page counts are always entered separately.
require __DIR__ . '/config.php';
require_once __DIR__ . '/movements-helper.php';
$user = smartflow_require_authenticated_user($pdo, require_user_id());
$pdo->exec("CREATE TABLE IF NOT EXISTS folder_checklists (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, office_id INT NOT NULL,
 name VARCHAR(100) NOT NULL, document_type VARCHAR(150) NOT NULL, items_json LONGTEXT NOT NULL,
 updated_by INT NOT NULL, is_active TINYINT NOT NULL DEFAULT 1,
 updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 INDEX checklist_office (office_id, is_active)) ENGINE=InnoDB");
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
 $stmt = $pdo->prepare('SELECT id, name, document_type, items_json, updated_at FROM folder_checklists WHERE office_id=? AND is_active=1 ORDER BY name, id');
 $stmt->execute([$user['office_id']]);
 $rows = array_map(static function($row) { $row['id']=(int)$row['id']; $row['items']=json_decode($row['items_json'],true,32,JSON_THROW_ON_ERROR); unset($row['items_json']); return $row; }, $stmt->fetchAll());
 json_response(['success'=>true,'checklists'=>$rows]);
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') json_response(['success'=>false,'message'=>'Method not allowed'],405);
if (!in_array($user['role'], ['head','admin'], true)) json_response(['success'=>false,'message'=>'Only your office head or administrator can publish checklists'],403);
$body=get_json_body(); $id=(int)($body['id']??0);
if (($body['action']??'') === 'archive') {
 $pdo->beginTransaction();
 $stmt=$pdo->prepare('UPDATE folder_checklists SET is_active=0, updated_by=? WHERE id=? AND office_id=?');
 $stmt->execute([$user['id'],$id,$user['office_id']]);
 if (!$stmt->rowCount()) { $pdo->rollBack(); json_response(['success'=>false,'message'=>'Checklist not found in your office'],404); }
 smartflow_require_locked_writer($pdo,$user);
 $pdo->commit();
 json_response(['success'=>true]);
}
$name=trim(is_string($body['name']??null)?$body['name']:'');
$type=trim(is_string($body['document_type']??null)?$body['document_type']:'');
$items=$body['items']??null;
if ($name==='' || mb_strlen($name)>100 || $type==='' || mb_strlen($type)>150 || !is_array($items) || !array_is_list($items) || count($items)<1 || count($items)>20)
 json_response(['success'=>false,'message'=>'Provide a name, document type and 1–20 attachments'],400);
$names=[]; $clean=[];
foreach ($items as $item) {
 $label=trim(is_array($item)&&is_string($item['name']??null)?$item['name']:'');
 $key=mb_strtolower($label);
 if ($label==='' || mb_strlen($label)>100 || $key==='main document' || isset($names[$key]) || !is_bool($item['required']??null))
  json_response(['success'=>false,'message'=>'Each attachment needs a distinct name and required flag'],400);
 $names[$key]=true; $clean[]=['name'=>$label,'required'=>$item['required']];
}
$pdo->beginTransaction();
if ($id>0) {
 $stmt=$pdo->prepare('UPDATE folder_checklists SET name=?, document_type=?, items_json=?, updated_by=? WHERE id=? AND office_id=? AND is_active=1');
 $stmt->execute([$name,$type,json_encode($clean),$user['id'],$id,$user['office_id']]);
 // An unchanged update is valid, but an ID belonging to another office is not.
 $find=$pdo->prepare('SELECT id FROM folder_checklists WHERE id=? AND office_id=? AND is_active=1'); $find->execute([$id,$user['office_id']]);
 if (!$find->fetchColumn()) { $pdo->rollBack(); json_response(['success'=>false,'message'=>'Checklist not found in your office'],404); }
} else {
 $stmt=$pdo->prepare('INSERT INTO folder_checklists (office_id,name,document_type,items_json,updated_by) VALUES (?,?,?,?,?)');
 $stmt->execute([$user['office_id'],$name,$type,json_encode($clean),$user['id']]); $id=(int)$pdo->lastInsertId();
}
smartflow_require_locked_writer($pdo,$user);
$pdo->commit();
json_response(['success'=>true,'id'=>$id]);
