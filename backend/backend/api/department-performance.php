<?php
// GET /department-performance.php?months=6&end_month=2026-10
// Department performance for administrators: how fast each office forwards folders, how many visits ran past the
// desk limit, the trend over the last months and the offices that are slow again and again. Read-only.
// Auth: Bearer token required (administrator).

require __DIR__ . '/config.php';
require_once __DIR__ . '/routing-helper.php';
require_once __DIR__ . '/thresholds-helper.php';
require_once __DIR__ . '/department-performance-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
$stmtUser = $pdo->prepare('SELECT role FROM users WHERE id = :id AND is_active = 1 LIMIT 1');
$stmtUser->execute([':id' => $userId]);
$caller = $stmtUser->fetch();
if (!$caller || $caller['role'] !== 'admin') {
    json_response(['success' => false, 'message' => 'Department performance is available to administrators only'], 403);
}

$months = filter_var($_GET['months'] ?? 6, FILTER_VALIDATE_INT, ['options' => ['min_range' => 3, 'max_range' => 12]]);
if ($months === false) {
    json_response(['success' => false, 'message' => 'months must be a whole number from 3 to 12'], 400);
}
$currentMonth = date('Y-m');
$endMonth = trim((string)($_GET['end_month'] ?? $currentMonth));
$oldestMonth = date('Y-m', strtotime('-15 years'));
if (!preg_match('/^[1-9]\d{3}-(0[1-9]|1[0-2])$/D', $endMonth) || $endMonth > $currentMonth || $endMonth < $oldestMonth) {
    json_response(['success' => false, 'message' => 'end_month must be YYYY-MM, no later than this month and within the last 15 years'], 400);
}

// Schema checks run before the snapshot transaction because DDL commits implicitly.
smartflow_ensure_documents_filed_columns($pdo);
smartflow_ensure_processing_thresholds($pdo);

$window = smartflow_performance_months($endMonth, $months, date('Y-m-d H:i:s'));
$rules = smartflow_performance_rules();
$pdo->exec('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
$pdo->beginTransaction();
$folders = smartflow_performance_load_folders($pdo, $window[0]['start'], $window[array_key_last($window)]['cutoff']);
$limits = smartflow_performance_limits($pdo);
$offices = array_map(static fn (array $row) => ['id' => (int)$row['id'], 'code' => (string)$row['code'], 'name' => (string)$row['name']],
    $pdo->query('SELECT id, code, name FROM offices ORDER BY name ASC')->fetchAll());
$pdo->commit();

$visits = smartflow_performance_visits($folders, $limits, $window, $rules['default_desk_limit_hours']);
header('Cache-Control: no-store');
json_response([
    'success' => true,
    'generated_at' => date('Y-m-d H:i:s'),
    'timezone' => date_default_timezone_get(),
    'window' => [
        'months' => $months,
        'start_month' => $window[0]['month'],
        'end_month' => $window[array_key_last($window)]['month'],
        'list' => array_column($window, 'month'),
        'cutoff' => $window[array_key_last($window)]['cutoff'],
    ],
    'rules' => $rules,
    'basis' => smartflow_performance_basis(),
    ...smartflow_performance_report($offices, $window, $visits, $rules),
]);
