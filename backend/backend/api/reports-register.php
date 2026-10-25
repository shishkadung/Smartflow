<?php
// GET /reports-register.php?period=month&month=2026-09&scope=activity&page=1
// Admin municipal preview. office_id means latest custody/sending office at cutoff.
declare(strict_types=1);

require __DIR__ . '/config.php';
require_once __DIR__ . '/report-period-helper.php';
require_once __DIR__ . '/report-register-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') json_response(['success' => false, 'message' => 'Method not allowed'], 405);
$userId = require_user_id();
$caller = $pdo->prepare('SELECT role FROM users WHERE id=:id AND is_active=1 LIMIT 1');
$caller->execute([':id' => $userId]);
if ($caller->fetchColumn() !== 'admin') json_response(['success' => false, 'message' => 'Custody registers are available to administrators only'], 403);
foreach (['period', 'month', 'year', 'quarter', 'scope', 'classification', 'office_id', 'q', 'page', 'page_size', 'as_of', 'movement_watermark', 'correction_watermark'] as $key) {
    if (isset($_GET[$key]) && !is_string($_GET[$key])) json_response(['success' => false, 'message' => 'Invalid report parameters'], 400);
}
$range = smartflow_report_period($_GET);
$scope = $_GET['scope'] ?? 'activity';
$classification = $_GET['classification'] ?? 'all';
$q = trim($_GET['q'] ?? '');
$page = filter_var($_GET['page'] ?? 1, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => intdiv(PHP_INT_MAX, 50)]]);
$pageSize = filter_var($_GET['page_size'] ?? 25, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => 50]]);
$officeId = isset($_GET['office_id']) ? filter_var($_GET['office_id'], FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]) : null;
if (!in_array($scope, ['activity', 'outstanding'], true) || !in_array($classification, ['all', 'on_time', 'unforwarded', 'delayed'], true)
    || mb_strlen($q) > 200 || $page === false || $pageSize === false || $officeId === false) {
    json_response(['success' => false, 'message' => 'Invalid custody register filters or paging'], 400);
}
$asOf = smartflow_report_as_of($_GET, $range);
$pdo->exec('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
$pdo->beginTransaction();
$watermarks = smartflow_report_watermarks($pdo, $_GET);
if ($officeId !== null) {
    $office = $pdo->prepare('SELECT id FROM offices WHERE id=:id');
    $office->execute([':id' => $officeId]);
    if (!$office->fetchColumn()) {
        $pdo->rollBack();
        json_response(['success' => false, 'message' => 'Office not found'], 404);
    }
}
$result = smartflow_report_register($pdo, $range['start'], $asOf,
    ['scope' => $scope, 'classification' => $classification, 'office_id' => $officeId, 'q' => $q, ...$watermarks], $page, $pageSize);
$pdo->commit();
header('Cache-Control: no-store');
json_response(array_merge([
    'success' => true, 'period' => $range['period'], 'month' => $range['month'], 'quarter' => $range['quarter'], 'year' => $range['year'],
    'period_label' => $range['label'], 'period_start' => $range['start'], 'period_end' => $asOf, 'as_of' => $asOf,
    'timezone' => date_default_timezone_get(), 'generated_at' => date('Y-m-d H:i:s'),
    'scope' => $scope, 'classification' => $classification, 'office_id' => $officeId, 'q' => $q,
    'page' => $page, 'page_size' => $pageSize,
    'office_filter_basis' => 'Latest custody/sending office at the report cutoff; not all offices touched in the period.',
    'movement_count_basis' => 'All recorded movements through the report cutoff.',
    'classification_note' => smartflow_report_classification_note(),
    ...$watermarks,
], $result));
