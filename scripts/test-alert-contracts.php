<?php
declare(strict_types=1);
require __DIR__ . '/stabilization-test-helper.php';
$f=new SmartflowStabilizationFixture();$db=$f->db;
try {
    $f->user(201,'alerts_staff',1);$f->user(202,'alerts_head',1,'head');$f->user(203,'alerts_admin',4,'admin');$f->user(204,'alerts_budget',3);$f->user(205,'other_admin',1,'admin');
    $f->startServers();
    $staff=$f->login('alerts_staff');$head=$f->login('alerts_head');$admin=$f->login('alerts_admin');
    $f->check($f->call('accountant-alerts.php')[0]===401,'municipal alerts require a session');
    foreach(['staff'=>$staff,'head'=>$head]as$role=>$token)$f->check($f->call('accountant-alerts.php',$token)[0]===403,"$role cannot read municipal alerts");
    $f->check($f->call('accountant-alerts.php',$f->login('other_admin'))[0]===200,'non-Accounting administrator retains municipal alert access');
    $doc=$db->prepare('INSERT INTO documents(id,title,type,origin_office_id,created_by,due_at) VALUES(?,?,"Others: Review",3,204,?)');
    $mv=$db->prepare('INSERT INTO movements(document_id,office_id,status,user_id,scanned_at) VALUES(?,3,"IN",204,?)');
    for($i=1;$i<=100;$i++){$id=sprintf('DOC-1900-%06d',$i);$doc->execute([$id,'Synthetic not due '.$i,null]);$mv->execute([$id,date('Y-m-d H:i:s',time()-7200)]);}
    $doc->execute(['DOC-1900-900001','Synthetic overdue after quiet folders',date('Y-m-d H:i:s',time()-600)]);$mv->execute(['DOC-1900-900001',date('Y-m-d H:i:s',time()-3600)]);
    [$status,$body]=$f->call('accountant-alerts.php',$admin);
    $f->check($status===200&&array_column($body['alerts'],'document_id')===['DOC-1900-900001'],'municipal alert cohort includes overdue folder after 100 earlier non-alert rows');
    $f->check($f->call('alerts-list.php?office_id=3',$staff)[0]===403,'office alert cross-office permission remains restricted');
    for($i=1;$i<=105;$i++){$id=sprintf('DOC-1901-%06d',$i);$doc->execute([$id,'Synthetic due '.$i,date('Y-m-d H:i:s',time()-600)]);$mv->execute([$id,date('Y-m-d H:i:s',time()-1800)]);}
    [$status,$body]=$f->call('accountant-alerts.php',$admin);
    $f->check($status===200&&count($body['alerts'])===106,'municipal alerts return the complete qualifying cohort beyond 100');
    $db->exec("INSERT INTO processing_thresholds(office_id,document_type,max_hours,out_unconfirmed_hours) VALUES(3,'Others: Rule',3,2)");
    $db->exec("INSERT INTO documents(id,title,type,origin_office_id,created_by) VALUES('DOC-1902-000001','Synthetic IN limit','Others: Rule',3,204),('DOC-1902-000002','Synthetic OUT limit','Others: Rule',3,204)");
    $db->exec("INSERT INTO movements(document_id,office_id,status,user_id,scanned_at,destination_office_id) VALUES('DOC-1902-000001',3,'IN',204,DATE_SUB(NOW(),INTERVAL 4 HOUR),NULL),('DOC-1902-000002',3,'OUT',204,DATE_SUB(NOW(),INTERVAL 3 HOUR),1)");
    [$status,$body]=$f->call('accountant-alerts.php',$admin);$rules=array_column($body['alerts'],null,'document_id');
    $f->check($status===200&&$rules['DOC-1902-000001']['max_hours']===3&&$rules['DOC-1902-000001']['kind']==='delayed','complete alert cohort retains configured processing limits');
    $f->check($rules['DOC-1902-000002']['max_hours']===2&&$rules['DOC-1902-000002']['kind']==='unconfirmed','complete alert cohort retains distinct receipt limits');
    $indexes=$db->query("SHOW INDEX FROM movements WHERE Column_name='destination_office_id' AND Seq_in_index=1")->fetchAll();
    $f->check(count($indexes)===1,'fresh source schema has one destination lookup index');
    $db->exec('ALTER TABLE movements DROP INDEX idx_movements_destination');
    $f->check($f->call('auth-session.php',$admin)[0]===200,'bootstrap repairs an existing destination column without its index');
    $f->check(count($db->query("SHOW INDEX FROM movements WHERE Column_name='destination_office_id' AND Seq_in_index=1")->fetchAll())===1,'repaired destination index is installed once');
    $f->check($f->call('auth-session.php',$admin)[0]===200&&count($db->query("SHOW INDEX FROM movements WHERE Column_name='destination_office_id' AND Seq_in_index=1")->fetchAll())===1,'repeat bootstrap preserves the existing index');
    $db->exec("UPDATE documents SET filed_at=NOW(),filed_by=204 WHERE id='DOC-1900-900001'");
    $db->exec("INSERT INTO documents(id,title,type,origin_office_id,created_by) VALUES('DOC-1903-000001','Synthetic computed route completion','Approved Budget',3,204)");
    $db->exec("INSERT INTO movements(document_id,office_id,status,user_id,scanned_at,destination_office_id) VALUES('DOC-1903-000001',3,'IN',204,DATE_SUB(NOW(),INTERVAL 4 HOUR),NULL),('DOC-1903-000001',3,'OUT',204,DATE_SUB(NOW(),INTERVAL 3 HOUR),4),('DOC-1903-000001',4,'IN',203,DATE_SUB(NOW(),INTERVAL 2 HOUR),NULL)");
    [$status,$page]=$f->call('office-documents.php?scope=municipal&limit=25&tray=completed',$admin);
    $rows=array_column($page['documents']??[],null,'id');
    $f->check($status===200&&!empty($rows['DOC-1900-900001']['filed_at']),'authorized tray rows retain explicit filing timestamp');
    $f->check($rows['DOC-1903-000001']['trail_complete']===true&&$rows['DOC-1903-000001']['filed_at']===null,'computed route completion does not invent explicit filing evidence');
    [$status,$page]=$f->call('office-documents.php?limit=25&tray=in_office',$staff);
    $f->check($status===200&&($page['documents']??null)===[],'additive filing evidence does not widen staff tray scope');
    $f->assertCopies();
}finally{$f->close();}
echo "{$f->checks} isolated alert/schema contracts passed\n";
