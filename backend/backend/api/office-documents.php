<?php
// Authenticated office tray and document QR. Incoming records appear after OUT to this office.
require __DIR__ . '/config.php';
require_once __DIR__ . '/movements-helper.php';
require_once __DIR__ . '/qr-token-helper.php';
require_once __DIR__ . '/documents-logbook-helper.php';
require_once __DIR__ . '/routing-helper.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/journey-helper.php';
require_once __DIR__ . '/folder-contents-helper.php';
require_once __DIR__ . '/office-queue-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}
$user = smartflow_require_authenticated_user($pdo, require_user_id());
$scope = (string)($_GET['scope'] ?? 'office');
if (!in_array($scope, ['office', 'municipal'], true)) {
    json_response(['success' => false, 'message' => 'Invalid document scope'], 400);
}
$municipal = $scope === 'municipal';
if ($municipal && $user['role'] !== 'admin') {
    json_response(['success' => false, 'message' => 'Municipal documents require an administrator account'], 403);
}
$currentOfficeId = filter_var($_GET['current_office_id'] ?? 0, FILTER_VALIDATE_INT, ['options' => ['min_range' => 0]]);
if ($currentOfficeId === false || (!$municipal && $currentOfficeId !== 0)) {
    json_response(['success' => false, 'message' => 'Invalid municipal office filter'], 400);
}
smartflow_ensure_documents_logbook_columns($pdo);
smartflow_ensure_documents_filed_columns($pdo);
smartflow_ensure_folder_contents($pdo);
smartflow_ensure_documents_due_column($pdo);
smartflow_ensure_processing_thresholds($pdo);
smartflow_ensure_movement_corrections($pdo);
$thresholds = [];
foreach ($pdo->query('SELECT office_id, document_type, max_hours, out_unconfirmed_hours FROM processing_thresholds WHERE is_active=1')->fetchAll() as $rule) {
    $thresholds[(int)$rule['office_id'] . ':' . mb_strtolower($rule['document_type'])] = ['max_hours' => (int)$rule['max_hours'], 'out_unconfirmed_hours' => (int)$rule['out_unconfirmed_hours']];
}
$officeId = $user['office_id'];
if (isset($_GET['office_id']) && (int)$_GET['office_id'] !== $officeId) {
    json_response(['success' => false, 'message' => 'Documents are limited to your assigned office'], 403);
}
$id = trim((string)($_GET['id'] ?? ''));
$base = smartflow_office_queue_sql($officeId, $municipal);
if ($currentOfficeId > 0) {
    $base = "SELECT * FROM ($base) municipal_queue WHERE current_office_id=$currentOfficeId";
}
$paged = $id === '' && isset($_GET['limit']);
$where = '1=1'; $params = []; $pagination = [];
$order = 'last_scanned_at DESC,last_movement_id DESC'; $limitSql = '';
if ($id !== '') { $where='id=?'; $params[]=$id; }
if ($paged) {
    $limit=filter_var($_GET['limit'],FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>100]]);
    $offset=filter_var($_GET['offset']??0,FILTER_VALIDATE_INT,['options'=>['min_range'=>0,'max_range'=>1000000]]);
    $tray=(string)($_GET['tray']??'incoming'); $sort=(string)($_GET['sort']??'urgency');
    $search=trim((string)($_GET['search']??'')); $overdue=($_GET['overdue']??'0')==='1';
    if ($limit===false || $offset===false || !in_array($tray,['incoming','in_office','forwarded','completed'],true) || !in_array($sort,['urgency','waiting','recent'],true) || mb_strlen($search)>200)
        json_response(['success'=>false,'message'=>'Invalid queue filters'],400);
    $where=$overdue?'queue_overdue=1':'tray=?'; if(!$overdue) $params[]=$tray;
    if($search!=='') { $where.=" AND LOWER(CONCAT(id,' ',title,' ',COALESCE(reference_no,''))) LIKE ? ESCAPE '!'"; $params[]='%'.str_replace(['!','%','_'],['!!','!%','!_'],mb_strtolower($search)).'%'; }
    $order=match($sort) { 'recent'=>'last_scanned_at DESC,id ASC', 'waiting'=>'last_scanned_at ASC,id ASC', default=>'queue_overdue DESC,effective_due_at ASC,last_scanned_at ASC,id ASC' };
    $count=$pdo->prepare("SELECT tray,COUNT(*) AS amount,SUM(queue_overdue) AS overdue,SUM(CASE WHEN $where THEN 1 ELSE 0 END) AS filtered_total FROM ($base) queue GROUP BY tray"); $count->execute($params);
    $total=0;
    $counts=['incoming'=>0,'in_office'=>0,'forwarded'=>0,'completed'=>0]; $overdueCount=0;
    foreach($count->fetchAll() as $row) { $counts[$row['tray']]=(int)$row['amount']; $overdueCount+=(int)$row['overdue']; $total+=(int)$row['filtered_total']; }
    $pagination=['total'=>$total,'offset'=>$offset,'limit'=>$limit,'has_more'=>$offset+$limit<$total,'tray_counts'=>$counts,'overdue_count'=>$overdueCount];
    $limitSql=" LIMIT $limit OFFSET $offset";
}
$outerOrder=preg_replace('/\b(last_scanned_at|last_movement_id|queue_overdue|effective_due_at|id)\b/','page.$1',$order);
$stmt=$pdo->prepare("SELECT page.*,checked.contents_receipt,checked.id AS movement_id,checked.scanned_at AS checked_at,u.name AS checked_by,checkedOffice.name AS office_name
 FROM (SELECT * FROM ($base) queue WHERE $where ORDER BY $order $limitSql) page
 LEFT JOIN movements checked ON checked.document_id=page.id AND checked.id=(SELECT r.id FROM movements r WHERE r.document_id=page.id AND r.status='IN' AND r.contents_receipt IS NOT NULL ORDER BY r.scanned_at DESC,r.id DESC LIMIT 1)
 LEFT JOIN users u ON u.id=checked.user_id LEFT JOIN offices checkedOffice ON checkedOffice.id=checked.office_id
 ORDER BY $outerOrder");
$stmt->execute($params);
$documents = array_map(static function (array $row) use ($officeId, $municipal, $thresholds, $pdo): array {
    $row = array_merge($row, smartflow_folder_state_row($row['folder_inventory'], $row));
    foreach (['contents_receipt','movement_id','checked_at','checked_by','office_name','effective_due_at','queue_overdue'] as $field) unset($row[$field]);
    $row['last_movement_id'] = (int)$row['last_movement_id'];
    $row['current_office_id'] = (int)$row['current_office_id'];
    $row['destination_office_id'] = $row['destination_office_id'] === null ? null : (int)$row['destination_office_id'];
    $row['trail_complete'] = (bool)$row['trail_complete'];
    $isDv = smartflow_type_is_dv((string)$row['type']);
    $row['can_return_to_accounting'] = !$municipal && $isDv && $row['trail_complete']
        && empty($row['filed_at']) && $row['current_status'] === 'IN' && $row['current_office_code'] === 'TRE';
    unset($row['filed_at']);
    $row['tray'] = $row['trail_complete'] ? 'completed' : ($row['current_status'] === 'IN' ? 'in_office'
        : ($municipal || $row['current_office_id'] === $officeId ? 'forwarded' : 'incoming'));
    $rule = $thresholds[$row['current_office_id'] . ':' . mb_strtolower($row['type'])] ?? smartflow_threshold_defaults();
    $hasManualDue = !empty($row['due_at']);
    $row['manual_due_at'] = $row['due_at'];
    $due = smartflow_calculate_document_due($row['current_status'], $row['current_office_id'], $row['last_scanned_at'], $row['due_at'], $rule);
    $row['due_at'] = $due['due_at'];
    $row['due_at_display'] = $due['due_at_display'];
    $row['is_overdue'] = !$row['trail_complete'] && $due['is_overdue']
        && (!$municipal || $row['current_status'] === 'IN' || $hasManualDue);
    $row['hours_waiting'] = round(max(0, time() - strtotime($row['last_scanned_at'])) / 3600, 2);
    return $row;
}, $stmt->fetchAll());
if ($id !== '') {
    if (!$documents) {
        json_response(['success' => false, 'message' => 'Document is not in your office tray'], 404);
    }
    $doc = $documents[0];
    $doc = array_merge($doc, smartflow_movement_correction_state($pdo, [
        'id' => $doc['last_movement_id'], 'status' => $doc['current_status'],
        'office_id' => $doc['current_office_id'], 'destination_office_id' => $doc['destination_office_id'],
    ], $user, $doc['trail_complete']));
    $doc['suggested_forward'] = smartflow_build_suggested_forward($pdo, (string)$doc['id'], (string)$doc['type'], [
        'status' => $doc['current_status'],
        'office_code' => $doc['current_office_code'],
        'office_id' => $doc['current_office_id'],
    ]);
    $doc['can_file'] = (string)$user['role'] === 'staff'
        && !$doc['trail_complete']
        && !smartflow_type_has_fixed_route((string)$doc['type'])
        && $doc['current_status'] === 'IN'
        && (int)$doc['current_office_id'] === (int)$officeId;
    $issued = smartflow_document_qr($pdo, $doc['id']);
    $doc['qr_payload'] = $issued['payload'];
    $doc['qr_expires_at'] = $issued['expires_at'];
    $doc['journey'] = smartflow_document_journey($pdo, $doc['id']);
    $doc['visited_office_codes'] = array_values(array_unique(array_column(
        array_filter($doc['journey'], static fn(array $step): bool => $step['status'] === 'IN'), 'office_code'
    )));
    json_response(['success' => true, 'office_id' => $officeId, 'scope' => $scope, 'read_only' => $municipal || $user['role'] !== 'staff', 'document' => $doc]);
}
json_response(['success' => true, 'office_id' => $officeId, 'scope' => $scope, 'read_only' => $municipal || $user['role'] !== 'staff', 'documents' => $documents, ...$pagination]);
