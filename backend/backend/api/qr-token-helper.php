<?php
// Signed, time-limited QR payloads for SmartFlow custody labels.
// Format: SF1.{base64url(json)}.{base64url(hmac-sha256 signature)}

declare(strict_types=1);

const SMARTFLOW_QR_PREFIX = 'SF1';
/** Physical folder labels — reprint issues a fresh token. */
const SMARTFLOW_QR_TTL_SECONDS = 15552000; // 180 days

function smartflow_qr_secret(): string
{
    static $cached = null;
    if ($cached !== null) {
        return $cached;
    }

    $path = __DIR__ . '/.qr-secret';
    if (is_readable($path)) {
        $fromFile = trim((string)file_get_contents($path));
        if ($fromFile !== '') {
            $cached = $fromFile;
            return $cached;
        }
    }

    $cached = hash('sha256', 'smartflow-qr-v1-urbiztondo');
    if (!is_file($path)) {
        @file_put_contents($path, $cached);
    }

    return $cached;
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
function smartflow_qr_issue(string $documentId, ?int $ttlSeconds = null): array
{
    $documentId = strtoupper(trim($documentId));
    if (!preg_match('/^DOC-\d{4}-\d{6}$/', $documentId)) {
        throw new InvalidArgumentException('Invalid document id for QR issue');
    }

    $issuedAt = time();
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
            'Invalid QR — label may be damaged or forged. Reprint from SmartFlow.'
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
            'message'      => 'This QR label has expired. Ask Accounting to reprint the label.',
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
