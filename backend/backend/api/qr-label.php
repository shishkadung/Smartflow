<?php
// GET /qr-label.php?id=DOC-2026-000001&size=220&token=<optional>
// Returns an HTML page you can print as a QR label.
//
// Auth:
// - If you open this in a browser, easiest is to pass `token` query param (from login response).
// - If you call from Postman, you can use Bearer token header instead.
//
// Note: The QR image is loaded from an online generator (requires internet).

require __DIR__ . '/config.php';
require_once __DIR__ . '/qr-token-helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    header('Content-Type: text/plain');
    echo 'Method not allowed';
    exit;
}

$id = trim((string)($_GET['id'] ?? ''));
if ($id === '') {
    http_response_code(400);
    header('Content-Type: text/plain');
    echo 'Missing id';
    exit;
}

// Auth (allow either Bearer header or token query param)
$token = get_bearer_token();
if (!$token) {
    $token = (string)($_GET['token'] ?? '');
}
$userId = user_id_from_token($token);
if (!$userId) {
    http_response_code(401);
    header('Content-Type: text/plain');
    echo "Unauthorized. Provide Bearer token header or ?token=... in the URL.";
    exit;
}

// Fetch document
$stmt = $pdo->prepare('
    SELECT d.id, d.title, d.type, d.date_registered, o.name AS origin_office_name
    FROM documents d
    JOIN offices o ON o.id = d.origin_office_id
    WHERE d.id = :id
    LIMIT 1
');
$stmt->execute([':id' => $id]);
$doc = $stmt->fetch();

if (!$doc) {
    http_response_code(404);
    header('Content-Type: text/plain');
    echo 'Document not found';
    exit;
}

$size = (int)($_GET['size'] ?? 220);
if ($size < 120) $size = 120;
if ($size > 800) $size = 800;

try {
    $qrIssued = smartflow_qr_issue((string)$doc['id']);
} catch (InvalidArgumentException $e) {
    http_response_code(500);
    header('Content-Type: text/plain');
    echo 'Could not issue secured QR';
    exit;
}
$qrPayload = $qrIssued['payload'];
$qrExpiresDisplay = date('M j, Y', $qrIssued['expires_at_unix']);
$qrData = rawurlencode($qrPayload);
$dimension = $size . 'x' . $size;
$qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size={$dimension}&data={$qrData}";

header('Content-Type: text/html; charset=utf-8');
?>
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>QR Label - <?php echo htmlspecialchars($doc['id']); ?></title>
    <style>
      :root { --border: #111; }
      body { font-family: Arial, sans-serif; margin: 0; padding: 16px; background: #f5f5f5; }
      .sheet { display: flex; justify-content: center; }
      .label {
        width: 3.2in;
        border: 2px solid var(--border);
        background: #fff;
        padding: 12px;
      }
      .top { display: flex; gap: 12px; align-items: center; }
      .qr { width: <?php echo (int)$size; ?>px; height: <?php echo (int)$size; ?>px; border: 1px solid #ddd; }
      .meta { flex: 1; min-width: 0; }
      .id { font-weight: 700; font-size: 14px; margin: 0 0 6px; white-space: nowrap; }
      .row { font-size: 12px; margin: 2px 0; }
      .muted { color: #444; }
      .footer { margin-top: 10px; font-size: 11px; color: #333; display: flex; justify-content: space-between; }
      @media print {
        body { background: #fff; padding: 0; }
        .label { border: 1px solid #000; }
      }
    </style>
  </head>
  <body>
    <div class="sheet">
      <div class="label">
        <div class="top">
          <img class="qr" src="<?php echo htmlspecialchars($qrUrl); ?>" alt="QR Code" />
          <div class="meta">
            <p class="id"><?php echo htmlspecialchars($doc['id']); ?></p>
            <div class="row"><span class="muted">Title:</span> <?php echo htmlspecialchars($doc['title']); ?></div>
            <div class="row"><span class="muted">Type:</span> <?php echo htmlspecialchars($doc['type']); ?></div>
            <div class="row"><span class="muted">Origin:</span> <?php echo htmlspecialchars($doc['origin_office_name']); ?></div>
          </div>
        </div>
        <div class="footer">
          <div>SmartFlow · Secured QR</div>
          <div>Valid until <?php echo htmlspecialchars($qrExpiresDisplay); ?></div>
        </div>
      </div>
    </div>
    <script>
      // Optional: auto-open print dialog
      // window.print();
    </script>
  </body>
</html>

