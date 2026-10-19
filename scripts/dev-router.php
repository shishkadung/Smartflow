<?php
declare(strict_types=1);

// Use only with the PHP development launcher. The repository is not a public file root.
$path = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH);
$path = is_string($path) ? rawurldecode($path) : '';
$api = realpath(dirname(__DIR__) . '/backend/backend/api');
$allowed = preg_match('~^/backend/backend/api/([a-z][a-z0-9-]*\.php|qr-generator\.js|qr-label-renderer\.js)$~D', $path, $match);
$allowed = $allowed && !str_starts_with($match[1], 'dev-') && $match[1] !== 'users-email-migration.php';
$file = $allowed && $api !== false ? realpath($api . '/' . $match[1]) : false;

// Only normal top-level API scripts and the two public label assets reach PHP's handler.
// Dotfiles, logs, caches, SQL, backups, traversal and links outside the API stay private.
if ($file !== false && is_file($file) && strcasecmp(dirname($file), $api) === 0 && basename($file) === $match[1]) {
    return false;
}

http_response_code(404);
header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: no-store');
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'HEAD') {
    echo 'Not found';
}
