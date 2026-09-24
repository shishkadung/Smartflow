<?php
// POST /users-avatar-upload.php
// multipart/form-data: file field "avatar" (JPEG/PNG/WebP, max 2MB)
// Optional: remove=1 to clear avatar.

require __DIR__ . '/config.php';
require_once __DIR__ . '/users-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'message' => 'Method not allowed'], 405);
}

$userId = require_user_id();
smartflow_ensure_users_active_column($pdo);
smartflow_ensure_users_avatar_column($pdo);

$current = smartflow_fetch_user_by_id($pdo, $userId);
if (!$current) {
    json_response(['success' => false, 'message' => 'User not found'], 404);
}

$body = get_json_body();
$remove = isset($_POST['remove'])
    ? (string)$_POST['remove'] === '1'
    : ((string)($body['remove'] ?? '') === '1');

$dir = smartflow_avatars_dir();

if ($remove) {
    $old = trim((string)($current['avatar_path'] ?? ''));
    if ($old !== '') {
        $oldFile = $dir . '/' . basename($old);
        if (is_file($oldFile)) {
            @unlink($oldFile);
        }
    }
    $pdo->prepare('UPDATE users SET avatar_path = NULL WHERE id = :id')->execute([':id' => $userId]);
    $updated = smartflow_fetch_user_by_id($pdo, $userId);
    json_response([
        'success' => true,
        'message' => 'Profile photo removed',
        'user' => smartflow_user_payload($updated ?: $current),
    ]);
}

if (!isset($_FILES['avatar']) || !is_array($_FILES['avatar'])) {
    json_response(['success' => false, 'message' => 'Choose a photo to upload'], 400);
}

$file = $_FILES['avatar'];
if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
    json_response(['success' => false, 'message' => 'Upload failed. Try another image.'], 400);
}

$maxBytes = 2 * 1024 * 1024;
if (($file['size'] ?? 0) <= 0 || ($file['size'] ?? 0) > $maxBytes) {
    json_response(['success' => false, 'message' => 'Photo must be under 2 MB'], 400);
}

$tmp = (string)($file['tmp_name'] ?? '');
if ($tmp === '' || !is_uploaded_file($tmp)) {
    json_response(['success' => false, 'message' => 'Invalid upload'], 400);
}

$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime = $finfo->file($tmp) ?: '';
$extMap = [
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
];
if (!isset($extMap[$mime])) {
    json_response(['success' => false, 'message' => 'Use a JPEG, PNG, or WebP photo'], 400);
}
$ext = $extMap[$mime];

$filename = 'u' . $userId . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
$dest = $dir . '/' . $filename;

if (!move_uploaded_file($tmp, $dest)) {
    json_response(['success' => false, 'message' => 'Could not save photo'], 500);
}

// Delete previous file if any.
$old = trim((string)($current['avatar_path'] ?? ''));
if ($old !== '' && basename($old) !== $filename) {
    $oldFile = $dir . '/' . basename($old);
    if (is_file($oldFile)) {
        @unlink($oldFile);
    }
}

$upd = $pdo->prepare('UPDATE users SET avatar_path = :path WHERE id = :id');
$upd->execute([':path' => $filename, ':id' => $userId]);

$updated = smartflow_fetch_user_by_id($pdo, $userId);
json_response([
    'success' => true,
    'message' => 'Profile photo updated',
    'user' => smartflow_user_payload($updated ?: $current),
]);
