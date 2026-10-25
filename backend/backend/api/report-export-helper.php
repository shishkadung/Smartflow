<?php
declare(strict_types=1);

function smartflow_csv_cell(mixed $value): string {
    $value = (string)$value;
    // Spreadsheet formula evaluation also applies after leading whitespace.
    return preg_match('/^\s*[=+@-]/u', $value) ? "'" . $value : $value;
}

function smartflow_report_csv(array $report): string {
    $stream = fopen('php://temp', 'r+');
    fwrite($stream, "\xEF\xBB\xBF");
    $row = static function (array $values) use ($stream): void {
        fputcsv($stream, array_map('smartflow_csv_cell', $values), ',', '"', '', "\r\n");
    };
    $row(['SmartFlow custody support summary']);
    foreach (['period_label' => 'Period', 'period_start' => 'From', 'period_end' => 'Through', 'scope' => 'Scope', 'prepared_by' => 'Prepared by', 'generated_at' => 'Generated at', 'timezone' => 'Timezone'] as $key => $label) $row([$label, $report[$key]]);
    foreach (['movement_watermark' => 'Movement evidence through ID', 'correction_watermark' => 'Correction evidence through ID'] as $key => $label) {
        if (isset($report[$key])) $row([$label, $report[$key]]);
    }
    $row(['Source', 'SmartFlow custody scan logs']);
    $row(['Documents in period', $report['totals']['documents_in_period']]);
    $row([]);
    $row(['Custody classification', 'Documents', 'Percent']);
    foreach (['on_time' => 'On time', 'unforwarded' => 'Unforwarded', 'delayed' => 'Delayed'] as $key => $label) {
        $row([$label, $report['compliance'][$key]['count'], $report['compliance'][$key]['percent']]);
    }
    $row([]);
    $row(['Office', 'Code', 'Distinct documents processed']);
    foreach ($report['office_totals'] as $office) $row([$office['office_name'], $office['office_code'], $office['docs_processed']]);
    $row([]);
    $row(['Office counts can overlap when a document passes through several offices.']);
    $row(['Classification basis', $report['classification_note'] ?? 'Receipt classifications use 72 calendar hours; they do not measure desk-deadline compliance.']);
    $row(['Outstanding transfers at cutoff', $report['outstanding_transfers'] ?? count($report['outstanding_register'] ?? [])]);
    $row(['Carried forward from before the period', $report['carried_forward_transfers'] ?? 0]);
    $row(['Activity and outstanding registers overlap; do not add their counts. Outstanding includes earlier transfers with no activity in the selected period.']);
    $row(['Custody evidence uses the report cutoff and recorded event watermarks. Folder titles and personnel/office names reflect current records.']);
    foreach (['activity_register' => 'Activity register', 'outstanding_register' => 'Outstanding transfers at cutoff'] as $key => $label) {
        $row([]);
        $row([$label]);
        $row(['Folder ID', 'Title', 'Type', 'Receipt classification', 'Custody status', 'Current / sending office', 'Destination', 'Latest movement at', 'Recorded by', 'Last received at', 'Received by', 'Last sent at', 'Sent by', 'Receipt wait (hours)', 'Movements through cutoff', 'Carried forward']);
        foreach ($report[$key] ?? [] as $document) {
            $row([$document['document_id'], $document['title'], $document['type'], smartflow_report_classification_label($document['classification']),
                $document['current_status'] === 'OUT' ? 'Awaiting receipt' : 'In office', smartflow_report_office_label($document, 'current'), smartflow_report_office_label($document, 'destination'),
                $document['last_scanned_at'], $document['recorded_by'] ?? 'Not recorded', $document['last_received_at'] ?? 'Not recorded', $document['received_by'] ?? 'Not recorded',
                $document['last_sent_at'] ?? 'Not recorded', $document['sent_by'] ?? 'Not recorded', $document['receipt_wait_hours'] ?? '', $document['movement_count'], $document['carried_forward'] ? 'Yes' : 'No']);
        }
    }
    $row(['Custody support only. Pair with the required financial reports.']);
    rewind($stream);
    $result = stream_get_contents($stream);
    fclose($stream);
    return $result;
}

function smartflow_report_classification_label(string $classification): string {
    return match ($classification) {
        'delayed' => 'Delayed receipt', 'unforwarded' => 'Awaiting receipt (Unforwarded)', default => 'On time / in custody',
    };
}

function smartflow_report_office_label(array $document, string $prefix): string {
    $name = $document[$prefix . '_office_name'] ?? null;
    $code = $document[$prefix . '_office_code'] ?? null;
    return $name ? $name . ($code ? ' (' . $code . ')' : '') : 'Not recorded';
}

function smartflow_report_register_print(string $label, array $documents): string {
    $escape = static fn(mixed $value): string => htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $html = '<h2>' . $escape($label) . ' (' . count($documents) . ' folders)</h2>';
    if (!$documents) return $html . '<p>No folders in this register.</p>';
    $html .= '<table class="register"><thead><tr><th>Folder</th><th>Custody at cutoff</th><th>Receipt classification</th><th>Latest movement</th><th>Receipt / send evidence</th><th>Trail</th></tr></thead><tbody>';
    foreach ($documents as $document) {
        $custody = ($document['current_status'] === 'OUT' ? 'OUT · Awaiting receipt' : 'IN · In office') . ' · ' . smartflow_report_office_label($document, 'current');
        if ($document['current_status'] === 'OUT') $custody .= ' → ' . smartflow_report_office_label($document, 'destination');
        $html .= '<tr><td><strong>' . $escape($document['document_id']) . '</strong><br>' . $escape($document['title']) . '<br><small>' . $escape($document['type']) . '</small></td>'
            . '<td>' . $escape($custody) . '</td><td>' . $escape(smartflow_report_classification_label($document['classification'])) . '</td>'
            . '<td>' . $escape($document['last_scanned_at']) . '<br>' . $escape($document['recorded_by'] ?? 'Person not recorded') . '</td>'
            . '<td>IN: ' . $escape($document['last_received_at'] ?? 'Not recorded') . '<br>' . $escape($document['received_by'] ?? 'Person not recorded')
            . '<br>OUT: ' . $escape($document['last_sent_at'] ?? 'Not recorded') . '<br>' . $escape($document['sent_by'] ?? 'Person not recorded') . '</td>'
            . '<td>' . $escape($document['movement_count']) . ' movements through cutoff'
            . ($document['receipt_wait_hours'] === null ? '' : '<br>Receipt wait: ' . $escape($document['receipt_wait_hours']) . ' h')
            . ($document['carried_forward'] ? '<br>Carried forward' : '') . '</td></tr>';
    }
    return $html . '</tbody></table>';
}

function smartflow_report_print(array $report): string {
    $escape = static fn(mixed $value): string => htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $metadata = '';
    foreach (['period_label' => 'Period', 'scope' => 'Scope', 'prepared_by' => 'Prepared by', 'generated_at' => 'Generated at', 'timezone' => 'Timezone'] as $key => $label) $metadata .= '<dt>'.$label.'</dt><dd>'.$escape($report[$key]).'</dd>';
    foreach (['movement_watermark' => 'Movement evidence through ID', 'correction_watermark' => 'Correction evidence through ID'] as $key => $label) {
        if (isset($report[$key])) $metadata .= '<dt>'.$label.'</dt><dd>'.$escape($report[$key]).'</dd>';
    }
    $metadata .= '<dt>Date range</dt><dd>'.$escape($report['period_start']).' through '.$escape($report['period_end']).'</dd>';
    $metrics = '';
    foreach (['on_time' => 'On time', 'unforwarded' => 'Unforwarded', 'delayed' => 'Delayed'] as $key => $label) $metrics .= '<tr><td>'.$label.'</td><td>'.$escape($report['compliance'][$key]['count']).'</td><td>'.$escape($report['compliance'][$key]['percent']).'%</td></tr>';
    $offices = '';
    foreach ($report['office_totals'] as $office) $offices .= '<tr><td>'.$escape($office['office_name']).'</td><td>'.$escape($office['office_code']).'</td><td>'.$escape($office['docs_processed']).'</td></tr>';
    $registers = '<p>' . $escape($report['classification_note'] ?? 'Receipt classifications use 72 calendar hours; they do not measure desk-deadline compliance.') . '</p>'
        . '<p><strong>Outstanding transfers at cutoff: ' . $escape($report['outstanding_transfers'] ?? count($report['outstanding_register'] ?? []))
        . '</strong> · Carried forward from before the period: ' . $escape($report['carried_forward_transfers'] ?? 0) . '</p>'
        . '<p>Activity and outstanding registers overlap; do not add their counts. Outstanding includes earlier transfers with no activity in the selected period. Evidence and receipt waits are bounded by the report cutoff.</p>'
        . '<p>Custody evidence also uses the recorded event watermarks. Folder titles and personnel/office names reflect current records.</p>'
        . smartflow_report_register_print('Activity register', $report['activity_register'] ?? [])
        . smartflow_report_register_print('Outstanding transfers at cutoff', $report['outstanding_register'] ?? []);
    return '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SmartFlow custody summary</title><style>body{font:15px/1.5 Arial,sans-serif;color:#17243a;max-width:1200px;margin:32px auto;padding:0 20px}h1{font-size:27px}h2{font-size:19px;margin-top:26px}dl{display:grid;grid-template-columns:140px 1fr;gap:8px}dt{font-weight:bold}dd{margin:0;overflow-wrap:anywhere}table{width:100%;border-collapse:collapse}th,td{padding:10px;border-bottom:1px solid #cbd5e1;text-align:left;vertical-align:top;overflow-wrap:anywhere}th{background:#eef2f6}.register{table-layout:fixed;font-size:12px}.register th:first-child{width:23%}.register th:nth-child(2){width:20%}tr{break-inside:avoid}button{padding:10px 18px;background:#155eef;color:white;border:0;border-radius:6px}footer{border-top:1px solid #cbd5e1;margin-top:26px;font-size:12px}thead{display:table-header-group}@media print{body{margin:0;max-width:none;padding:0}button{display:none}h2{break-after:avoid}@page{size:A4 landscape;margin:14mm}}</style><button onclick="window.print()">Print / Save as PDF</button><h1>Custody support summary</h1><dl>'.$metadata.'</dl><p><strong>Documents in period: '.$escape($report['totals']['documents_in_period']).'</strong></p><h2>Custody classifications</h2><table><thead><tr><th>Classification</th><th>Documents</th><th>Percent</th></tr></thead><tbody>'.$metrics.'</tbody></table><h2>By office</h2><table><thead><tr><th>Office</th><th>Code</th><th>Distinct documents</th></tr></thead><tbody>'.$offices.'</tbody></table>'.$registers.'<footer><p>Source: SmartFlow custody scan logs. Office totals may overlap when documents pass through several offices.</p><p>Custody support only. Pair with the required financial reports.</p></footer></html>';
}
