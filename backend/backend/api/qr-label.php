<?php
// GET /qr-label.php?id=DOC-2026-000001&size=220
// Returns an HTML page you can print as a QR label.
//
// Auth:
// Retrieve with an authenticated request; credentials are accepted only in headers.
//
// QR generation uses the local vendored library; printing needs no image service.

require __DIR__ . '/config.php';
require_once __DIR__ . '/qr-token-helper.php';
require_once __DIR__ . '/folder-contents-helper.php';

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

require_user_id();

smartflow_ensure_folder_contents($pdo);
// Fetch document
$stmt = $pdo->prepare('
    SELECT d.id, d.title, d.type, d.date_registered, d.folder_inventory, o.name AS origin_office_name
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
if ($size < 220) $size = 220;
if ($size > 800) $size = 800;

try {
    $qrIssued = smartflow_document_qr($pdo, (string)$doc['id']);
} catch (InvalidArgumentException $e) {
    http_response_code(500);
    header('Content-Type: text/plain');
    echo 'Could not issue secured QR';
    exit;
}
$qrPayload = $qrIssued['payload'];
$qrExpiresDisplay = date('M j, Y', $qrIssued['expires_at_unix']);
$inventory = smartflow_contents_decode($doc['folder_inventory']);

header('Content-Type: text/html; charset=utf-8');
?>
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>QR Label - <?php echo htmlspecialchars($doc['id']); ?></title>
    <style>
      :root { --border: #1d4ed8; }
      body { font-family: Arial, sans-serif; margin: 0; padding: 16px; background: #f5f5f5; }
      .sheet { display: flex; justify-content: center; }
      .label {
        width: 3.2in;
        border: 2px solid var(--border);
        background: #fff;
        padding: 12px;
      }
      .top { display: flex; flex-direction: column; gap: 12px; align-items: center; }
      .brand { color: #122840; font-weight: 700; letter-spacing: 1px; font-size: 18px; margin: 0 0 4px; }
      .caption { color: #444; font-size: 11px; margin: 0 0 12px; }
      .inventory { border-top: 1px solid #ddd; margin-top: 10px; padding-top: 8px; font-size: 11px; }
      .qr { width: min(100%, <?php echo (int)$size; ?>px); height: auto; aspect-ratio: 1; border: 1px solid #ddd; }
      .qr svg { display: block; width: 100%; height: auto; }
      .meta { width: 100%; min-width: 0; overflow-wrap: anywhere; }
      .id { font-weight: 700; font-size: 14px; margin: 0 0 6px; }
      .row { font-size: 12px; margin: 2px 0; }
      .muted { color: #444; }
      .footer { margin-top: 10px; font-size: 11px; color: #333; display: flex; flex-wrap: wrap; gap: 4px 12px; justify-content: space-between; }
      @media print {
        body { background: #fff; padding: 0; }
        .label { border: 1px solid #000; }
      }
    </style>
  </head>
  <body>
    <div class="sheet">
      <div class="label">
        <p class="brand">SMARTFLOW</p>
        <p class="caption">Municipality of Urbiztondo · Folder tracking</p>
        <div class="top">
          <div class="qr" id="label-qr" role="img" aria-label="Secured QR code">
            <noscript>Enable JavaScript to display the secured QR.</noscript>
          </div>
          <div class="meta">
            <p class="id"><?php echo htmlspecialchars($doc['id']); ?></p>
            <div class="row"><span class="muted">Title:</span> <?php echo htmlspecialchars($doc['title']); ?></div>
            <div class="row"><span class="muted">Type:</span> <?php echo htmlspecialchars($doc['type']); ?></div>
            <div class="row"><span class="muted">Origin:</span> <?php echo htmlspecialchars($doc['origin_office_name']); ?></div>
          </div>
        </div>
        <div class="inventory">
          <?php if ($inventory !== null): ?>
            <strong>Registered contents · <?php echo (int)$inventory['total_pages']; ?> pages</strong>
            <?php foreach ($inventory['items'] as $item): ?>
              <div><?php echo htmlspecialchars($item['name']); ?>: <?php echo (int)$item['pages']; ?> pages<?php if ($item['required'] && $item['pages'] === 0) echo ' · required item missing'; ?></div>
            <?php endforeach; ?>
          <?php else: ?>
            Contents not recorded
          <?php endif; ?>
          <p>Receiving office must count actual contents. Scan to view current custody and receipt checks.</p>
        </div>
        <div class="footer">
          <div>SmartFlow · Secured QR</div>
          <div>Valid until <?php echo htmlspecialchars($qrExpiresDisplay); ?></div>
        </div>
      </div>
    </div>
    <script type="application/json" id="qr-label-data"><?php echo json_encode(['payload' => $qrPayload, 'size' => $size], JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT); ?></script>
    <script src="qr-generator.js"></script>
    <script src="qr-label-renderer.js"></script>
  </body>
</html>

