<?php
// Real delayed endpoint calls, copied sources, generated schemas only. No live accounts or mail.
declare(strict_types=1);
require __DIR__ . '/stabilization-test-helper.php';
require_once __DIR__ . '/../backend/backend/api/creation-requests-helper.php';
$f = new SmartflowStabilizationFixture();
$db = $f->db;
$lock = null;
$pending = null;
$second = null;
try {
    $f->user(101, 'writer', 1);
    $f->user(102, 'handler', 3);
    $f->user(103, 'head', 1, 'head');
    $f->user(104, 'admin', 4, 'admin');
    $f->startServers(2);
    $admin = $f->login('admin', 1);
    $writer = $f->login('writer', 1);
    $handler = $f->login('handler', 1);
    $head = $f->login('head', 1);
    $lock = $f->connect();
    $document = static function () use ($f, $db, &$writer): array {
        [$status,$body] = $f->call('documents-create.php', $writer, ['title'=>'Synthetic authority folder','type'=>'Others: Authority','origin_office_id'=>1], 1);
        $f->check($status===201, 'owned synthetic folder registration succeeds');
        $id = $body['document']['id'];
        $read=$db->prepare('SELECT id FROM movements WHERE document_id=? ORDER BY id DESC LIMIT 1'); $read->execute([$id]);
        return [$id,(int)$read->fetchColumn()];
    };
    $ticket = static function () use ($db): int {
        $db->prepare("INSERT INTO document_requests(request_code,request_kind,document_category,requested_by,requester_office_id,requester_role,handler_office_id,purpose,status) VALUES(?,'access','budget',101,1,'staff',3,'Synthetic purpose','pending')")->execute(['TEST-'.bin2hex(random_bytes(5))]);
        return (int)$db->lastInsertId();
    };
    foreach (['logout','deactivation','expiry','assignment','password_required','valid'] as $mode) {
        $writer=$f->login('writer',1);
        [$id,$movement]=$document();
        $lock->beginTransaction();
        $lock->prepare('SELECT id FROM documents WHERE id=? FOR UPDATE')->execute([$id]);
        $body=['document_id'=>$id,'office_id'=>1,'status'=>'OUT','destination_office_id'=>3,'expected_movement_id'=>$movement,'movement_source'=>'system','request_id'=>bin2hex(random_bytes(16))];
        $pending=$f->begin('movements-create.php',$writer,$body);
        $f->waitForLock($pending,'documents');
        $f->check(true,"movement/$mode reaches actual folder-lock wait");
        if ($mode==='logout') $f->check($f->call('auth-logout.php',$writer,[],1)[0]===200,'waiting movement session logs out');
        if ($mode==='deactivation') $f->check($f->call('users-set-active.php',$admin,['user_id'=>101,'active'=>false],1)[0]===200,'waiting movement sender is deactivated through admin endpoint');
        if ($mode==='expiry') $db->prepare('UPDATE auth_tokens SET expires_at=DATE_SUB(NOW(),INTERVAL 1 SECOND) WHERE token_hash=?')->execute([hash('sha256',$writer)]);
        if ($mode==='assignment') $db->exec('UPDATE users SET office_id=3 WHERE id=101');
        if ($mode==='password_required') $db->exec('UPDATE users SET must_change_password=1 WHERE id=101');
        $lock->commit(); [$status,$result]=$f->finish($pending); $pending=null;
        $expected=match($mode){'valid'=>200,'assignment'=>409,'password_required'=>403,default=>401};
        $f->check($status===$expected,"movement/$mode returns $expected after waiting");
        $read=$db->prepare('SELECT COUNT(*) FROM movements WHERE document_id=?'); $read->execute([$id]);
        $f->check((int)$read->fetchColumn()===($mode==='valid'?2:1),"movement/$mode commits exactly the permitted custody evidence");
        $read=$db->prepare('SELECT state FROM movement_requests WHERE request_id=?'); $read->execute([$body['request_id']]);
        $f->check($read->fetchColumn()===($mode==='valid'?'recorded':false),"movement/$mode preserves atomic recovery state");
        if ($mode==='valid') {
            [$replay,$saved]=$f->call('movements-create.php',$writer,$body,1);
            $f->check($replay===200 && $saved===$result,'valid movement replay returns its exact saved result without another write');
        }
        if ($mode==='deactivation') $f->check($f->call('users-set-active.php',$admin,['user_id'=>101,'active'=>true],1)[0]===200,'reactivate only the synthetic sender');
        $db->exec('UPDATE users SET office_id=1,must_change_password=0 WHERE id=101');
    }
    // Decisions and own profile use the same current-authority boundary.
    foreach (['logout','valid'] as $mode) {
        $handler=$f->login('handler',1); $id=$ticket();
        $lock->beginTransaction(); $lock->query('SELECT id FROM document_requests WHERE id='.$id.' FOR UPDATE')->fetchColumn();
        $pending=$f->begin('document-requests-update.php',$handler,['request_id'=>$id,'action'=>'approve','expected_status'=>'pending']);
        $f->waitForLock($pending,'document_requests');
        if ($mode==='logout') $f->check($f->call('auth-logout.php',$handler,[],1)[0]===200,'waiting ticket handler logs out');
        $lock->commit(); [$status]=$f->finish($pending); $pending=null;
        $f->check($status===($mode==='valid'?200:401) && $db->query('SELECT status FROM document_requests WHERE id='.$id)->fetchColumn()===($mode==='valid'?'approved':'pending'),"ticket/$mode keeps decision and caller authority coherent");
        $handler=$f->login('handler',1);
        $before=$db->query('SELECT name FROM users WHERE id=102')->fetchColumn();
        $lock->beginTransaction(); $lock->query('SELECT id FROM users WHERE id=102 FOR UPDATE')->fetchColumn();
        $pending=$f->begin('users-profile-update.php',$handler,['name'=>'Synthetic changed name','username'=>'handler','email'=>'handler@example.test']);
        $f->waitForLock($pending,'users');
        if ($mode==='logout') $f->check($f->call('auth-logout.php',$handler,[],1)[0]===200,'waiting profile session logs out');
        $lock->commit(); [$status]=$f->finish($pending); $pending=null;
        $f->check($status===($mode==='valid'?200:401) && $db->query('SELECT name FROM users WHERE id=102')->fetchColumn()===($mode==='valid'?'Synthetic changed name':$before),"profile/$mode changes only with current authority");
    }
    // Adjacent physical/monitoring operations wait on the same custody lock.
    foreach (['filing','correction','deadline'] as $action) {
        $writer=$f->login('writer',1); [$id,$movement]=$document();
        if ($action==='correction') {
            [$status,$sent]=$f->call('movements-create.php',$writer,['document_id'=>$id,'office_id'=>1,'status'=>'OUT','destination_office_id'=>3,'expected_movement_id'=>$movement,'movement_source'=>'system'],1);
            $f->check($status===200,'correction fixture has a real unreceived OUT'); $movement=$sent['movement_id'];
        }
        $token=$action==='deadline'?$head:$writer;
        $path=match($action){'filing'=>'documents-file.php','correction'=>'movements-correct-destination.php',default=>'documents-update-due.php'};
        $body=match($action){
            'filing'=>['document_id'=>$id,'expected_movement_id'=>$movement],
            'correction'=>['document_id'=>$id,'request_id'=>bin2hex(random_bytes(16)),'expected_movement_id'=>$movement,'expected_destination_office_id'=>3,'expected_correction_id'=>0,'destination_office_id'=>2,'correction_confirmed'=>true,'reason'=>'Synthetic recorded destination correction'],
            default=>['document_id'=>$id,'expected_movement_id'=>$movement,'expected_due_at'=>null,'due_at'=>date('Y-m-d H:i:s',time()+3600)]};
        $lock->beginTransaction(); $lock->prepare('SELECT id FROM documents WHERE id=? FOR UPDATE')->execute([$id]);
        $pending=$f->begin($path,$token,$body); $f->waitForLock($pending,'documents');
        $f->check($f->call('auth-logout.php',$token,[],1)[0]===200,"waiting $action session logs out");
        $lock->commit(); [$status]=$f->finish($pending); $pending=null;
        $f->check($status===401,"waiting $action rejects the ended session");
        $read=$db->prepare('SELECT filed_at,due_at FROM documents WHERE id=?'); $read->execute([$id]);
        $f->check($read->fetch()===['filed_at'=>null,'due_at'=>null],"rejected $action leaves filing/deadline unchanged");
        if($action==='correction') $f->check((int)$db->query('SELECT COUNT(*) FROM movement_destination_corrections')->fetchColumn()===0,'rejected correction appends no correction evidence');
    }
    // Publishing and profile-file changes have their own mutable resources too.
    $head=$f->login('head',1);
    $checklist=['name'=>'Synthetic requirements','document_type'=>'Others: Authority','items'=>[['name'=>'Attachment','required'=>true]]];
    [$status,$made]=$f->call('folder-checklists.php',$head,$checklist,1);
    $f->check($status===200,'head can publish an own-office checklist'); $checklistId=$made['id'];
    $lock->beginTransaction();$lock->query('SELECT id FROM folder_checklists WHERE id='.$checklistId.' FOR UPDATE')->fetchColumn();
    $pending=$f->begin('folder-checklists.php',$head,['id'=>$checklistId]+array_replace($checklist,['name'=>'Rejected replacement']));$f->waitForLock($pending,'folder_checklists');
    $f->check($f->call('auth-logout.php',$head,[],1)[0]===200,'waiting checklist publisher logs out');
    $lock->commit();[$status]=$f->finish($pending);$pending=null;
    $f->check($status===401&&$db->query('SELECT name FROM folder_checklists WHERE id='.$checklistId)->fetchColumn()==='Synthetic requirements','checklist write rolls back after publisher logout');
    $writer=$f->login('writer',1);
    mkdir($f->root.'/uploads/avatars',0700,true);file_put_contents($f->root.'/uploads/avatars/synthetic.png','synthetic-only-file');
    $db->exec("UPDATE users SET avatar_path='synthetic.png' WHERE id=101");
    $lock->beginTransaction();$lock->query('SELECT id FROM users WHERE id=101 FOR UPDATE')->fetchColumn();
    $pending=$f->begin('users-avatar-upload.php',$writer,['remove'=>1]);$f->waitForLock($pending,'users');
    $f->check($f->call('auth-logout.php',$writer,[],1)[0]===200,'waiting avatar owner logs out');
    $lock->commit();[$status]=$f->finish($pending);$pending=null;
    $f->check($status===401&&is_file($f->root.'/uploads/avatars/synthetic.png')&&$db->query('SELECT avatar_path FROM users WHERE id=101')->fetchColumn()==='synthetic.png','rejected avatar removal preserves file and row');
    // Creation recovery waits must not allow a logged-out caller to create a new record.
    foreach(['document','request']as$kind){
        $writer=$f->login('writer',1);$op=bin2hex(random_bytes(16));
        $body=$kind==='document'?['operation_id'=>$op,'title'=>'Rejected creation','type'=>'Others: Authority','origin_office_id'=>1]:['operation_id'=>$op,'request_kind'=>'access','document_category'=>'budget','purpose'=>'Synthetic request','required_by'=>date('Y-m-d',time()+86400)];
        $db->prepare('INSERT INTO creation_requests(operation_id,user_id,kind,body_hash) VALUES(?,101,?,?)')->execute([$op,$kind,smartflow_creation_hash($body)]);
        $before=(int)$db->query('SELECT (SELECT COUNT(*) FROM documents)+(SELECT COUNT(*) FROM movements)+(SELECT COUNT(*) FROM document_requests)')->fetchColumn();
        $lock->beginTransaction();$lock->prepare('SELECT operation_id FROM creation_requests WHERE operation_id=? FOR UPDATE')->execute([$op]);
        $pending=$f->begin($kind==='document'?'documents-create.php':'document-requests-create.php',$writer,$body);$f->waitForLock($pending,'creation_requests');
        $f->check($f->call('auth-logout.php',$writer,[],1)[0]===200,"waiting $kind creator logs out");
        $lock->commit();[$status]=$f->finish($pending);$pending=null;
        $f->check($status===401&&(int)$db->query('SELECT (SELECT COUNT(*) FROM documents)+(SELECT COUNT(*) FROM movements)+(SELECT COUNT(*) FROM document_requests)')->fetchColumn()===$before,"rejected $kind creation leaves no record or custody orphan");
        $read=$db->prepare('SELECT response_json FROM creation_requests WHERE operation_id=?');$read->execute([$op]);$f->check($read->fetchColumn()===null,"rejected $kind creation saves no successful outcome");
    }
    // Name-only edits preserve codes; a mailbox change retires every old unused code atomically.
    $handler=$f->login('handler',1);
    $addCode=static function(string $code)use($db):int{$db->prepare('INSERT INTO password_resets(user_id,token_hash,expires_at) VALUES(102,?,DATE_ADD(NOW(),INTERVAL 1 HOUR))')->execute([password_hash($code,PASSWORD_DEFAULT)]);return(int)$db->lastInsertId();};
    $codeId=$addCode('482619');
    $f->check($f->call('users-profile-update.php',$handler,['name'=>'Synthetic renamed','username'=>'handler','email'=>'handler@example.test'],1)[0]===200 && (int)$db->query('SELECT used_at IS NULL FROM password_resets WHERE id='.$codeId)->fetchColumn()===1,'name-only edit preserves an outstanding reset code');
    $f->check($f->call('users-profile-update.php',$handler,['name'=>'Synthetic renamed','username'=>'handler','email'=>'replacement@example.test'],1)[0]===200 && (int)$db->query('SELECT used_at IS NOT NULL FROM password_resets WHERE id='.$codeId)->fetchColumn()===1,'self email replacement retires the previous mailbox code');
    $f->check($f->call('auth-reset-password.php',body:['username'=>'handler','code'=>'482619','new_password'=>'synthetic-replacement-password'],server:1)[0]===401,'code from previous mailbox cannot reset the account');
    $raceCode=$addCode('395827');
    $lock->beginTransaction();$lock->query('SELECT id FROM password_resets WHERE id='.$raceCode.' FOR UPDATE')->fetchColumn();
    $pending=$f->begin('users-profile-update.php',$handler,['name'=>'Synthetic renamed','username'=>'handler','email'=>'latest@example.test']);$f->waitForLock($pending,'password_resets');
    $second=$f->begin('auth-reset-password.php',body:['username'=>'handler','code'=>'395827','new_password'=>'race-must-not-win-password'],server:1);$f->waitForLock($second,'users');
    $lock->commit();[$profileStatus]=$f->finish($pending);$pending=null;[$resetStatus]=$f->finish($second);$second=null;
    $f->check($profileStatus===200&&$resetStatus===401,'reset waiting behind the actual email transaction rechecks retired code without a lock cycle');
    $newCode=$addCode('617284');
    $f->check($f->call('auth-reset-password.php',body:['username'=>'handler','code'=>'617284','new_password'=>'synthetic-replacement-password'],server:1)[0]===200,'new mailbox code still resets the password normally');
    $f->check($f->call('auth-session.php',$handler,server:1)[0]===401,'successful reset still revokes existing sessions');
    $f->check($f->call('auth-reset-password.php',body:['username'=>'handler','code'=>'617284','new_password'=>'another-synthetic-password'],server:1)[0]===401,'new mailbox reset remains single-use');
    $f->assertCopies();
} finally {
    if($lock?->inTransaction())$lock->rollBack();
    foreach([$pending,$second] as $call)if($call!==null){[$multi,$curl]=$call;curl_multi_remove_handle($multi,$curl);curl_close($curl);curl_multi_close($multi);}
    $lock=null;$f->close();
}
echo "{$f->checks} isolated write-authority checks passed\n";
