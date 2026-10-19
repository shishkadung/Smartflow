<?php
// Shared COA reporting period parser (monthly, quarterly, annual).

declare(strict_types=1);

/**
 * Reads period / month / quarter / year from query params.
 * Sends a 400 JSON response on invalid input.
 *
 * @return array{period: string, start: string, end: string, label: string, month: ?string, quarter: ?int, year: string}
 */
function smartflow_report_period(array $query): array
{
    $period = strtolower(trim((string)($query['period'] ?? 'month')));
    $month = trim((string)($query['month'] ?? date('Y-m'))); // YYYY-MM
    $year = trim((string)($query['year'] ?? date('Y')));     // YYYY
    $quarter = (int)($query['quarter'] ?? (int)ceil((int)date('n') / 3)); // 1–4

    if (!in_array($period, ['month', 'quarter', 'year'], true)) {
        json_response([
            'success' => false,
            'message' => 'period must be month, quarter, or year',
        ], 400);
    }

    if ($period === 'quarter') {
        if (!preg_match('/^[1-9]\d{3}$/', $year) || !preg_match('/^[1-4]$/', (string)($query['quarter'] ?? $quarter))) {
            json_response([
                'success' => false,
                'message' => 'year must be YYYY and quarter must be 1–4',
            ], 400);
        }
        $firstMonth = ($quarter - 1) * 3 + 1;
        return [
            'period'  => 'quarter',
            'start'   => sprintf('%s-%02d-01 00:00:00', $year, $firstMonth),
            'end'     => date('Y-m-t 23:59:59', strtotime(sprintf('%s-%02d-01', $year, $firstMonth + 2))),
            'label'   => 'Q' . $quarter . ' ' . $year,
            'month'   => null,
            'quarter' => $quarter,
            'year'    => $year,
        ];
    }

    if ($period === 'year') {
        if (!preg_match('/^[1-9]\d{3}$/', $year)) {
            json_response([
                'success' => false,
                'message' => 'year must be YYYY',
            ], 400);
        }
        return [
            'period'  => 'year',
            'start'   => $year . '-01-01 00:00:00',
            'end'     => $year . '-12-31 23:59:59',
            'label'   => 'Annual ' . $year,
            'month'   => null,
            'quarter' => null,
            'year'    => $year,
        ];
    }

    if (!preg_match('/^[1-9]\d{3}-(0[1-9]|1[0-2])$/', $month)) {
        json_response([
            'success' => false,
            'message' => 'month must be YYYY-MM',
        ], 400);
    }
    $start = $month . '-01 00:00:00';
    return [
        'period'  => 'month',
        'start'   => $start,
        'end'     => date('Y-m-t 23:59:59', strtotime($start)),
        'label'   => date('F Y', strtotime($start)),
        'month'   => $month,
        'quarter' => null,
        'year'    => substr($month, 0, 4),
    ];
}
