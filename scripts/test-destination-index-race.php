<?php
declare(strict_types=1);
require __DIR__.'/stabilization-test-helper.php';
require_once __DIR__.'/../backend/backend/api/schema-bootstrap.php';
// Fixture-only rendezvous makes both real bootstrap requests observe the absent
// index before either ALTER. The production metadata/ALTER/error logic is intact.
$transform=static function(string $name,string $source,string $root):string{
    if($name!=='schema-bootstrap.php')return$source;
    $needle= <<<'PHP'
$pdo->exec('ALTER TABLE movements ADD KEY idx_movements_destination (destination_office_id)');
PHP;
    $barrier= <<<'PHP'
if(is_file(__DIR__.'/.fixture-index-race')){
    touch(__DIR__.'/.fixture-index-arrived-'.getmypid());
    $until=microtime(true)+8;
    while(count(glob(__DIR__.'/.fixture-index-arrived-*'))<2){
        if(microtime(true)>$until)throw new RuntimeException('Owned index barrier timed out');
        usleep(10000);
    }
}
PHP;
    if(substr_count($source,$needle)!==1)throw new RuntimeException('Index fixture insertion point changed');
    return str_replace($needle,$barrier."\n".$needle,$source);
};
$f=new SmartflowStabilizationFixture($transform);$calls=[];
try{
    $f->user(301,'index_admin',4,'admin');$f->startServers(2);$token=$f->login('index_admin',1);
    $f->db->exec('ALTER TABLE movements DROP INDEX idx_movements_destination');
    touch($f->root.'/.fixture-index-race');
    $calls=[$f->begin('auth-session.php',$token,server:0),$f->begin('auth-session.php',$token,server:1)];
    $until=microtime(true)+12;
    do{
        foreach($calls as$call)curl_multi_exec($call[0],$running);
        if(count(glob($f->root.'/.fixture-index-arrived-*'))>=2)break;
        if(microtime(true)>$until)throw new RuntimeException('Both owned bootstrap requests did not reach the index race');
        usleep(10000);
    }while(true);
    $f->check(true,'both bootstrap requests observe the missing index before ALTER');
    foreach($calls as$i=>$call){[$status]=$f->finish($call);$calls[$i]=null;$f->check($status===200,'concurrent index bootstrap succeeds after verified duplicate-name race');}
    $f->check(count($f->db->query("SHOW INDEX FROM movements WHERE Column_name='destination_office_id' AND Seq_in_index=1")->fetchAll())===1,'concurrent bootstrap installs one useful index');
    unlink($f->root.'/.fixture-index-race');
    $f->db->exec('ALTER TABLE movements DROP INDEX idx_movements_destination');
    $f->db->exec('ALTER TABLE movements ADD KEY idx_movements_destination (office_id)');
    $rejected=false;
    try{smartflow_ensure_movements_destination_index($f->db);}catch(RuntimeException$e){$rejected=str_contains($e->getMessage(),'could not be verified');}
    $f->check($rejected,'same index name on the wrong column is not swallowed as a benign race');
    $f->db->exec('ALTER TABLE movements DROP INDEX idx_movements_destination');
    $f->db->exec('ALTER TABLE movements ADD KEY equivalent_destination_lookup (destination_office_id,id)');
    smartflow_ensure_movements_destination_index($f->db);
    $f->check(count($f->db->query("SHOW INDEX FROM movements WHERE Column_name='destination_office_id' AND Seq_in_index=1")->fetchAll())===1,'equivalent leading-column index is accepted without duplicate installation');
    $f->assertCopies();
}finally{
    foreach($calls as$call)if($call!==null){[$multi,$curl]=$call;curl_multi_remove_handle($multi,$curl);curl_close($curl);curl_multi_close($multi);}
    $f->close();
}
echo "{$f->checks} isolated destination-index race checks passed\n";
