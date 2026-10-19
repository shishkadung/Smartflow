<?php
declare(strict_types=1);

/** Add nullable fields without inventing contents for existing folders. Run before transactions. */
function smartflow_ensure_folder_contents(PDO $pdo): void
{
    static $ready = false;
    if ($ready) return;
    foreach (['documents' => 'folder_inventory', 'movements' => 'contents_receipt'] as $table => $column) {
        if (!$pdo->query("SHOW COLUMNS FROM $table LIKE '$column'")->fetch()) {
            try { $pdo->exec("ALTER TABLE $table ADD COLUMN $column LONGTEXT NULL"); }
            catch (PDOException $e) { if ((int)($e->errorInfo[1] ?? 0) !== 1060) throw $e; }
        }
    }
    $ready = true;
}

function smartflow_contents_decode(?string $json): ?array
{
    if ($json === null || $json === '') return null;
    $value = json_decode($json, true, 32, JSON_THROW_ON_ERROR);
    if (!is_array($value) || !isset($value['items']) || !is_array($value['items'])) {
        throw new RuntimeException('Stored folder contents are invalid');
    }
    return $value;
}

function smartflow_contents_pages(mixed $value): int
{
    if (!is_int($value) || $value < 0 || $value > 999) {
        throw new InvalidArgumentException('Page counts must be whole numbers between 0 and 999');
    }
    return $value;
}

/** Names and required items are declared by the office; no universal DV checklist is invented. */
function smartflow_inventory_validate(mixed $input): array
{
    if (!is_array($input) || ($input['count_confirmed'] ?? false) !== true) {
        throw new InvalidArgumentException('Confirm you physically hold the folder and counted its contents');
    }
    $rows = $input['items'] ?? null;
    if (!is_array($rows) || !array_is_list($rows) || count($rows) < 1 || count($rows) > 21) {
        throw new InvalidArgumentException('List the main document and at most 20 attachments');
    }
    $items = []; $names = [];
    foreach ($rows as $index => $row) {
        if (!is_array($row)) throw new InvalidArgumentException('Invalid folder item');
        $name = $index === 0 ? 'Main document' : trim(is_string($row['name'] ?? null) ? $row['name'] : '');
        if ($name === '' || mb_strlen($name) > 100 || isset($names[mb_strtolower($name)])) {
            throw new InvalidArgumentException('Give each attachment a distinct name of 1–100 characters');
        }
        $names[mb_strtolower($name)] = true;
        $pages = smartflow_contents_pages($row['pages'] ?? null);
        if ($index === 0 && $pages < 1) throw new InvalidArgumentException('The main document must have at least 1 page');
        if ($index > 0 && !is_bool($row['required'] ?? null)) throw new InvalidArgumentException('Specify whether each attachment is required');
        $items[] = ['id' => $index === 0 ? 'main' : 'attachment-' . $index, 'name' => $name,
            'pages' => $pages, 'required' => $index === 0 || $row['required'], 'kind' => $index === 0 ? 'main' : 'attachment'];
    }
    $total = array_sum(array_column($items, 'pages'));
    if ($total > 9999) throw new InvalidArgumentException('A folder may contain at most 9999 registered pages');
    return ['items' => $items, 'total_pages' => $total, 'status' => smartflow_contents_status($items, false)];
}

function smartflow_contents_status(array $items, bool $different): string
{
    foreach ($items as $item) {
        if ($item['required'] && ($item['pages'] === 0 || $item['pages'] < ($item['registered_pages'] ?? 0))) return 'incomplete';
    }
    return $different ? 'discrepancy' : 'complete';
}

/** Receipt IDs/names/requirements come from the immutable server inventory, never the request. */
function smartflow_receipt_validate(array $inventory, mixed $input): array
{
    if (!is_array($input) || ($input['confirmed'] ?? false) !== true) {
        throw new InvalidArgumentException('Confirm physical receipt and check the folder contents');
    }
    $rows = $input['items'] ?? null;
    if (!is_array($rows) || !array_is_list($rows) || count($rows) !== count($inventory['items'])) {
        throw new InvalidArgumentException('Record an actual page count for every registered item');
    }
    $byId = [];
    foreach ($rows as $row) {
        if (!is_array($row) || !is_string($row['id'] ?? null) || isset($byId[$row['id']])) {
            throw new InvalidArgumentException('Each registered item must appear exactly once');
        }
        $byId[$row['id']] = smartflow_contents_pages($row['pages'] ?? null);
    }
    $items = []; $different = false;
    foreach ($inventory['items'] as $registered) {
        if (!array_key_exists($registered['id'], $byId)) throw new InvalidArgumentException('Receipt does not match this folder inventory');
        $pages = $byId[$registered['id']];
        $different = $different || $pages !== $registered['pages'];
        $items[] = [...$registered, 'pages' => $pages, 'registered_pages' => $registered['pages']];
    }
    $total = array_sum(array_column($items, 'pages'));
    if ($total > 9999) throw new InvalidArgumentException('A folder may contain at most 9999 received pages');
    $reason = trim(is_string($input['reason'] ?? null) ? $input['reason'] : '');
    if (($different && mb_strlen($reason) < 5) || mb_strlen($reason) > 1000) {
        throw new InvalidArgumentException('Describe any discrepancy in 5–1000 characters');
    }
    return ['items' => $items, 'total_pages' => $total, 'registered_total_pages' => $inventory['total_pages'],
        'status' => smartflow_contents_status($items, $different), 'has_discrepancy' => $different, 'reason' => $reason, 'confirmed' => true];
}

function smartflow_folder_state(PDO $pdo, string $documentId, ?string $inventoryJson): array
{
    if ($inventoryJson === null) return smartflow_folder_state_row(null, null);
    $stmt = $pdo->prepare("SELECT m.contents_receipt, m.id AS movement_id, m.scanned_at AS checked_at, u.name AS checked_by, o.name AS office_name FROM movements m JOIN users u ON u.id=m.user_id JOIN offices o ON o.id=m.office_id WHERE m.document_id = ? AND m.status = 'IN' AND m.contents_receipt IS NOT NULL ORDER BY m.scanned_at DESC, m.id DESC LIMIT 1");
    $stmt->execute([$documentId]);
    $row = $stmt->fetch() ?: null;
    return smartflow_folder_state_row($inventoryJson, $row);
}

/** Decode already joined receipts, without another database round trip for every list row. */
function smartflow_folder_state_row(?string $inventoryJson, ?array $row): array
{
    $inventory = smartflow_contents_decode($inventoryJson);
    if ($inventory === null) return ['folder_inventory' => null, 'current_contents_receipt' => null, 'contents_status' => 'unrecorded'];
    $receipt = smartflow_contents_decode($row['contents_receipt'] ?? null);
    if ($receipt !== null) {
        foreach (['movement_id', 'checked_at', 'checked_by', 'office_name'] as $field) $receipt[$field] = $row[$field] ?? null;
    }
    return ['folder_inventory' => $inventory, 'current_contents_receipt' => $receipt,
        'contents_status' => $receipt['status'] ?? $inventory['status']];
}

function smartflow_receipt_summary(array $receipt): string
{
    $label = match ($receipt['status']) { 'incomplete' => 'Incomplete contents', 'discrepancy' => 'Contents discrepancy', default => 'Contents checked' };
    $parts = [$label . ': ' . $receipt['total_pages'] . '/' . $receipt['registered_total_pages'] . ' registered pages'];
    foreach ($receipt['items'] as $item) {
        if ($item['pages'] !== $item['registered_pages'] || ($item['required'] && $item['pages'] === 0)) {
            $parts[] = $item['name'] . ': ' . $item['pages'] . '/' . $item['registered_pages'] . ' pages' . ($item['required'] && $item['pages'] === 0 ? ' (required item missing)' : '');
        }
    }
    if ($receipt['reason'] !== '') $parts[] = $receipt['reason'];
    return implode('; ', $parts);
}
