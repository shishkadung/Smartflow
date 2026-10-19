<?php
function smartflow_office_queue_sql(int $officeId, bool $municipal = false): string {
 $complete=smartflow_sql_trail_complete_known_latest('d','m','sender');
 $defaults=smartflow_threshold_defaults(); $in=(int)$defaults['max_hours']; $out=(int)$defaults['out_unconfirmed_hours'];
 $scope = $municipal ? '1=1' : "m.office_id=$officeId OR (m.status='OUT' AND m.destination_office_id=$officeId)";
 $outTray = $municipal ? "'forwarded'" : "CASE WHEN q.current_office_id=$officeId THEN 'forwarded' ELSE 'incoming' END";
 $processingDue = $municipal ? " AND (q.current_status='IN' OR q.due_at IS NOT NULL)" : '';
 return "SELECT q.*, (q.trail_complete=0 AND q.effective_due_at < NOW() $processingDue) AS queue_overdue,
 CASE WHEN q.trail_complete THEN 'completed' WHEN q.current_status='IN' THEN 'in_office'
 ELSE $outTray END AS tray
 FROM (SELECT d.id,d.title,d.type,d.reference_no,d.payee,d.fund_source,d.due_at,d.folder_inventory,d.filed_at,
 $complete AS trail_complete, origin.name AS origin_office_name, m.id AS last_movement_id,
 m.status AS current_status,m.office_id AS current_office_id,sender.name AS current_office_name,
 sender.code AS current_office_code,m.destination_office_id,dest.name AS destination_office_name,
 m.scanned_at AS last_scanned_at,
 COALESCE(d.due_at,DATE_ADD(m.scanned_at,INTERVAL CASE WHEN m.status='OUT' THEN COALESCE(t.out_unconfirmed_hours,$out) ELSE COALESCE(t.max_hours,$in) END HOUR)) AS effective_due_at
 FROM documents d JOIN offices origin ON origin.id=d.origin_office_id
 JOIN movements m ON m.document_id=d.id AND m.id=(SELECT l.id FROM movements l WHERE l.document_id=d.id ORDER BY l.scanned_at DESC,l.id DESC LIMIT 1)
 JOIN offices sender ON sender.id=m.office_id LEFT JOIN offices dest ON dest.id=m.destination_office_id
 LEFT JOIN processing_thresholds t ON t.office_id=m.office_id AND t.document_type=d.type AND t.is_active=1
 WHERE $scope) q";
}
