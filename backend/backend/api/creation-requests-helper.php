<?php
declare(strict_types=1);

// The operation result commits in the same transaction as the created record.
function smartflow_ensure_creation_requests(PDO $pdo): void {
    $pdo->exec("CREATE TABLE IF NOT EXISTS creation_requests (
        operation_id CHAR(32) PRIMARY KEY,
        user_id INT NOT NULL,
        kind VARCHAR(12) NOT NULL,
        body_hash CHAR(64) NOT NULL,
        response_json LONGTEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX creation_owner (user_id, kind, created_at)
    ) ENGINE=InnoDB");
}

function smartflow_creation_id(mixed $value): ?string {
    if ($value === null || $value === '') return null;
    if (!is_string($value) || !preg_match('/^[a-f0-9]{32}$/D', $value)) {
        throw new InvalidArgumentException('Invalid creation operation ID', 400);
    }
    return $value;
}

function smartflow_creation_hash(array $body): string {
    unset($body['operation_id'], $body['access_token'], $body['token']);
    $sort = static function (array $value) use (&$sort): array {
        if (!array_is_list($value)) ksort($value);
        foreach ($value as &$item) if (is_array($item)) $item = $sort($item);
        return $value;
    };
    return hash('sha256', json_encode($sort($body), JSON_THROW_ON_ERROR));
}

// Read committed results before time-sensitive validation (for example a
// request's deadline may now be yesterday after yesterday's successful POST).
function smartflow_replay_creation(PDO $pdo, ?string $id, int $userId, string $kind, array $body): ?array {
    if ($id === null) return null;
    $select = $pdo->prepare('SELECT user_id,kind,body_hash,response_json FROM creation_requests WHERE operation_id=?');
    $select->execute([$id]);
    $row = $select->fetch();
    if (!$row) return null;
    if ((int)$row['user_id'] !== $userId || $row['kind'] !== $kind || !hash_equals($row['body_hash'], smartflow_creation_hash($body))) {
        throw new InvalidArgumentException('This operation ID belongs to a different submission', 409);
    }
    return $row['response_json'] === null ? null : json_decode($row['response_json'], true, 64, JSON_THROW_ON_ERROR);
}

// Caller must already own a transaction. A second identical submission waits
// for that transaction, then returns its saved result rather than creating again.
function smartflow_lock_creation(PDO $pdo, ?string $id, int $userId, string $kind, array $body): ?array {
    if ($id === null) return null; // Existing external clients remain compatible.
    $hash = smartflow_creation_hash($body);
    $insert = $pdo->prepare('INSERT IGNORE INTO creation_requests (operation_id,user_id,kind,body_hash) VALUES (?,?,?,?)');
    $insert->execute([$id, $userId, $kind, $hash]);
    $select = $pdo->prepare('SELECT * FROM creation_requests WHERE operation_id=? FOR UPDATE');
    $select->execute([$id]);
    $row = $select->fetch();
    if (!$row || (int)$row['user_id'] !== $userId || $row['kind'] !== $kind || !hash_equals($row['body_hash'], $hash)) {
        throw new InvalidArgumentException('This operation ID belongs to a different submission', 409);
    }
    return $row['response_json'] === null ? null : json_decode($row['response_json'], true, 64, JSON_THROW_ON_ERROR);
}

function smartflow_save_creation(PDO $pdo, ?string $id, array $response): void {
    if ($id === null) return;
    $pdo->prepare('UPDATE creation_requests SET response_json=? WHERE operation_id=?')
        ->execute([json_encode($response, JSON_THROW_ON_ERROR), $id]);
}
