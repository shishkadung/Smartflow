<?php
// Legacy maintenance is CLI-only, deliberately opted in, and never a web endpoint.
// This guard must run before config.php can connect to or bootstrap a database.
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    header('Content-Type: application/json');
    header('Cache-Control: no-store');
    echo json_encode(['success' => false, 'message' => 'Not found']);
    exit;
}

if (!in_array('--allow-maintenance', $_SERVER['argv'] ?? [], true)) {
    fwrite(STDERR, "Maintenance requires explicit --allow-maintenance and ALLOW_DEV_TOOLS=true outside production. Verify the target database before proceeding.\n");
    exit(1);
}

// Existing maintenance scripts use GET unless their documented input is JSON POST.
$_SERVER['REQUEST_METHOD'] = in_array('--method=POST', $_SERVER['argv'] ?? [], true) ? 'POST' : 'GET';
require_once __DIR__ . '/dev-tools-policy.php';
smartflow_load_environment(__DIR__ . '/.env');
if (!smartflow_dev_tools_enabled($_ENV)) {
    fwrite(STDERR, "Maintenance is disabled.\n");
    exit(1);
}
require_once __DIR__ . '/config.php';
