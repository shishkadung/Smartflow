<?php
// Signed, time-limited QR payloads for SmartFlow custody labels.
// Format: SF1.{base64url(json)}.{base64url(hmac-sha256 signature)}

declare(strict_types=1);

const SMARTFLOW_QR_PREFIX = 'SF1';
/** Downloaded and optional printed labels remain valid for 180 days. */
const SMARTFLOW_QR_TTL_SECONDS = 15552000; // 180 days

/** Run before a registration transaction: ALTER TABLE would implicitly commit it. */
function smartflow_ensure_documents_qr_column(PDO $pdo): void
{
    static $columnReady = false;
    if (!$columnReady) {
        $column = $pdo->query("SHOW COLUMNS FROM documents LIKE 'qr_issued_at_unix'")->fetch();
        if (!$column) {
            try {
                $pdo->exec('ALTER TABLE documents ADD COLUMN qr_issued_at_unix BIGINT NULL');
            } catch (PDOException $e) {
                if ((int)($e->errorInfo[1] ?? 0) !== 1060) throw $e;
            }
        }
        $columnReady = true;
    }
}

/** One stable signed QR per document until expiry; reopening or moving does not replace it. */
function smartflow_document_qr(PDO $pdo, string $documentId): array
{
    smartflow_ensure_documents_qr_column($pdo);
    $now = time();
    $update = $pdo->prepare('UPDATE documents SET qr_issued_at_unix = :now WHERE id = :id AND (qr_issued_at_unix IS NULL OR qr_issued_at_unix < :expired_before)');
    $update->execute([':now' => $now, ':id' => $documentId, ':expired_before' => $now - SMARTFLOW_QR_TTL_SECONDS]);
    $read = $pdo->prepare('SELECT qr_issued_at_unix FROM documents WHERE id = ?');
    $read->execute([$documentId]);
    $issuedAt = $read->fetchColumn();
    if ($issuedAt === false) throw new InvalidArgumentException('Document not found');
    return smartflow_qr_issue($documentId, null, (int)$issuedAt);
}

function smartflow_qr_secret(): string
{
    static $cached = null;
    if ($cached !== null) {
        return $cached;
    }

    return $cached = smartflow_load_qr_secret(__DIR__ . '/.qr-secret', trim((string)($_ENV['QR_SIGNING_SECRET'] ?? '')));
}

/** Persist one random key under a lock; upgrade the obsolete predictable key. */
function smartflow_load_qr_secret(string $path, string $configured = ''): string
{
    $legacy = hash('sha256', 'smartflow-qr-v1-urbiztondo');
    if ($configured !== '') {
        if (strlen($configured) < 32 || hash_equals($legacy, $configured)) {
            throw new RuntimeException('Configure a random QR signing secret of at least 32 bytes');
        }
        return $configured;
    }
    $handle = @fopen($path, 'c+');
    if (!$handle) throw new RuntimeException('QR signing key storage is unavailable');
    if (!flock($handle, LOCK_EX)) { fclose($handle); throw new RuntimeException('QR signing key storage is unavailable'); }
    try {
        $secret = trim((string)stream_get_contents($handle));
        if (strlen($secret) < 32 || hash_equals($legacy, $secret)) {
            $secret = bin2hex(random_bytes(32));
            rewind($handle);
            ftruncate($handle, 0);
            if (fwrite($handle, $secret) !== strlen($secret) || !fflush($handle)) {
                throw new RuntimeException('Could not persist the QR signing key');
            }
            @chmod($path, 0600);
        }
        return $secret;
    } finally {
        flock($handle, LOCK_UN);
        fclose($handle);
    }
}

function smartflow_qr_b64url_encode(string $raw): string
{
    return rtrim(strtr(base64_encode($raw), '+/', '-_'), '=');
}

function smartflow_qr_b64url_decode(string $encoded): ?string
{
    $padded = strtr($encoded, '-_', '+/');
    $pad = strlen($padded) % 4;
    if ($pad > 0) {
        $padded .= str_repeat('=', 4 - $pad);
    }
    $decoded = base64_decode($padded, true);

    return $decoded === false ? null : $decoded;
}

/**
 * @return array{
 *   payload: string,
 *   document_id: string,
 *   issued_at: string,
 *   expires_at: string,
 *   expires_at_unix: int
 * }
 */
function smartflow_qr_issue(string $documentId, ?int $ttlSeconds = null, ?int $issuedAtUnix = null): array
{
    $documentId = strtoupper(trim($documentId));
    if (!preg_match('/^DOC-\d{4}-\d{6}$/', $documentId)) {
        throw new InvalidArgumentException('Invalid document id for QR issue');
    }

    $issuedAt = $issuedAtUnix ?? time();
    $ttl = $ttlSeconds ?? SMARTFLOW_QR_TTL_SECONDS;
    if ($ttl < 60) {
        $ttl = 60;
    }
    $expiresAt = $issuedAt + $ttl;

    $body = json_encode([
        'd' => $documentId,
        'i' => $issuedAt,
        'e' => $expiresAt,
    ], JSON_THROW_ON_ERROR);

    $payloadPart = smartflow_qr_b64url_encode($body);
    $sigPart = smartflow_qr_b64url_encode(
        hash_hmac('sha256', $payloadPart, smartflow_qr_secret(), true)
    );

    return [
        'payload'           => SMARTFLOW_QR_PREFIX . '.' . $payloadPart . '.' . $sigPart,
        'document_id'       => $documentId,
        'issued_at'         => gmdate('c', $issuedAt),
        'expires_at'        => gmdate('c', $expiresAt),
        'expires_at_unix'   => $expiresAt,
    ];
}

/**
 * @return array{
 *   valid: bool,
 *   document_id: ?string,
 *   reason: ?string,
 *   message: string,
 *   issued_at: ?string,
 *   expires_at: ?string
 * }
 */
function smartflow_qr_verify(string $rawPayload): array
{
    $raw = trim($rawPayload);
    if ($raw === '') {
        return smartflow_qr_verify_fail('invalid', 'Empty QR payload');
    }

    if (!str_starts_with($raw, SMARTFLOW_QR_PREFIX . '.')) {
        return smartflow_qr_verify_fail('invalid', 'Unrecognized QR format');
    }

    $parts = explode('.', $raw);
    if (count($parts) !== 3 || $parts[0] !== SMARTFLOW_QR_PREFIX) {
        return smartflow_qr_verify_fail('malformed', 'Malformed secured QR code');
    }

    [, $payloadPart, $sigPart] = $parts;
    if ($payloadPart === '' || $sigPart === '') {
        return smartflow_qr_verify_fail('malformed', 'Malformed secured QR code');
    }

    $expectedSig = smartflow_qr_b64url_encode(
        hash_hmac('sha256', $payloadPart, smartflow_qr_secret(), true)
    );
    if (!hash_equals($expectedSig, $sigPart)) {
        return smartflow_qr_verify_fail(
            'tampered',
            'Invalid QR — image may be damaged or forged. Open the document in SmartFlow to download its QR.'
        );
    }

    $jsonRaw = smartflow_qr_b64url_decode($payloadPart);
    if ($jsonRaw === null) {
        return smartflow_qr_verify_fail('malformed', 'Malformed secured QR code');
    }

    try {
        $data = json_decode($jsonRaw, true, 512, JSON_THROW_ON_ERROR);
    } catch (Throwable $e) {
        return smartflow_qr_verify_fail('malformed', 'Malformed secured QR code');
    }

    if (!is_array($data)) {
        return smartflow_qr_verify_fail('malformed', 'Malformed secured QR code');
    }

    $documentId = strtoupper(trim((string)($data['d'] ?? '')));
    $issuedAt = (int)($data['i'] ?? 0);
    $expiresAt = (int)($data['e'] ?? 0);

    if (
        !preg_match('/^DOC-\d{4}-\d{6}$/', $documentId)
        || $issuedAt <= 0
        || $expiresAt <= 0
        || $expiresAt < $issuedAt
    ) {
        return smartflow_qr_verify_fail('invalid', 'Invalid QR token contents');
    }

    if (time() > $expiresAt) {
        return [
            'valid'        => false,
            'document_id'  => $documentId,
            'reason'       => 'expired',
            'message'      => 'This QR has expired. Open the document in SmartFlow to download its renewed QR.',
            'issued_at'    => gmdate('c', $issuedAt),
            'expires_at'   => gmdate('c', $expiresAt),
        ];
    }

    return [
        'valid'       => true,
        'document_id' => $documentId,
        'reason'      => null,
        'message'     => 'QR verified',
        'issued_at'   => gmdate('c', $issuedAt),
        'expires_at'  => gmdate('c', $expiresAt),
    ];
}

/**
 * @return array{
 *   valid: bool,
 *   document_id: ?string,
 *   reason: ?string,
 *   message: string,
 *   issued_at: ?string,
 *   expires_at: ?string
 * }
 */
function smartflow_qr_verify_fail(string $reason, string $message): array
{
    return [
        'valid'       => false,
        'document_id' => null,
        'reason'      => $reason,
        'message'     => $message,
        'issued_at'   => null,
        'expires_at'  => null,
    ];
}

function smartflow_is_signed_qr_payload(string $raw): bool
{
    return str_starts_with(trim($raw), SMARTFLOW_QR_PREFIX . '.');
}
