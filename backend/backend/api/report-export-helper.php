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
    $row(['Custody support only. Pair with the required financial reports.']);
    rewind($stream);
    $result = stream_get_contents($stream);
    fclose($stream);
    return $result;
}

function smartflow_report_print(array $report): string {
    $escape = static fn(mixed $value): string => htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $metadata = '';
    foreach (['period_label' => 'Period', 'scope' => 'Scope', 'prepared_by' => 'Prepared by', 'generated_at' => 'Generated at', 'timezone' => 'Timezone'] as $key => $label) $metadata .= '<dt>'.$label.'</dt><dd>'.$escape($report[$key]).'</dd>';
    $metadata .= '<dt>Date range</dt><dd>'.$escape($report['period_start']).' through '.$escape($report['period_end']).'</dd>';
    $metrics = '';
    foreach (['on_time' => 'On time', 'unforwarded' => 'Unforwarded', 'delayed' => 'Delayed'] as $key => $label) $metrics .= '<tr><td>'.$label.'</td><td>'.$escape($report['compliance'][$key]['count']).'</td><td>'.$escape($report['compliance'][$key]['percent']).'%</td></tr>';
    $offices = '';
    foreach ($report['office_totals'] as $office) $offices .= '<tr><td>'.$escape($office['office_name']).'</td><td>'.$escape($office['office_code']).'</td><td>'.$escape($office['docs_processed']).'</td></tr>';
    return '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SmartFlow custody summary</title><style>body{font:15px/1.5 Arial,sans-serif;color:#17243a;max-width:900px;margin:32px auto;padding:0 20px}h1{font-size:27px}h2{font-size:19px;margin-top:26px}dl{display:grid;grid-template-columns:140px 1fr;gap:8px}dt{font-weight:bold}dd{margin:0;overflow-wrap:anywhere}table{width:100%;border-collapse:collapse}th,td{padding:10px;border-bottom:1px solid #cbd5e1;text-align:left}th{background:#eef2f6}tr{break-inside:avoid}button{padding:10px 18px;background:#155eef;color:white;border:0;border-radius:6px}footer{border-top:1px solid #cbd5e1;margin-top:26px;font-size:12px}thead{display:table-header-group}@media print{body{margin:0;max-width:none;padding:0}button{display:none}h2{break-after:avoid}@page{size:A4;margin:18mm}}</style><button onclick="window.print()">Print / Save as PDF</button><h1>Custody support summary</h1><dl>'.$metadata.'</dl><p><strong>Documents in period: '.$escape($report['totals']['documents_in_period']).'</strong></p><h2>Custody classifications</h2><table><thead><tr><th>Classification</th><th>Documents</th><th>Percent</th></tr></thead><tbody>'.$metrics.'</tbody></table><h2>By office</h2><table><thead><tr><th>Office</th><th>Code</th><th>Distinct documents</th></tr></thead><tbody>'.$offices.'</tbody></table><footer><p>Source: SmartFlow custody scan logs. Office totals may overlap when documents pass through several offices.</p><p>Custody support only. Pair with the required financial reports.</p></footer></html>';
}
