<?php
// GET /users-avatar.php?id=123
// Serves the profile photo for a user (municipal staff directory style).

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    exit;
}

$userId = (int)($_GET['id'] ?? 0);
if ($userId <= 0) {
    http_response_code(400);
    exit;
}

smartflow_ensure_users_avatar_column($pdo);
$stmt = $pdo->prepare('SELECT avatar_path FROM users WHERE id = :id AND is_active = 1 LIMIT 1');
$stmt->execute([':id' => $userId]);
$row = $stmt->fetch();
$path = trim((string)($row['avatar_path'] ?? ''));
if ($path === '') {
    http_response_code(404);
    exit;
}

$file = smartflow_avatars_dir() . '/' . basename($path);
if (!is_file($file)) {
    http_response_code(404);
    exit;
}

$ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
$mime = match ($ext) {
    'jpg', 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    default => 'application/octet-stream',
};

header('Content-Type: ' . $mime);
header('Cache-Control: public, max-age=86400');
header('Content-Length: ' . (string)filesize($file));
readfile($file);
exit;
