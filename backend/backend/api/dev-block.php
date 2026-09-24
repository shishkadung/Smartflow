<?php
// Block all dev endpoints when in production mode
// Include this at the top of all dev-*.php files

require_once __DIR__ . '/config.php';

if (!SMARTFLOW_ALLOW_DEV_TOOLS) {
    http_response_code(403);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => 'Developer tools are disabled in production mode',
    ]);
    exit;
}
