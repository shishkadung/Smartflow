<?php
// Basic database configuration for SmartFlow API

declare(strict_types=1);

require_once __DIR__ . '/schema-bootstrap.php';
smartflow_register_error_handlers();

// Load environment variables from .env file
$envFile = __DIR__ . '/.env';
if (file_exists($envFile)) {
    $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos(trim($line), '#') === 0) continue;
        list($name, $value) = explode('=', $line, 2);
        $_ENV[trim($name)] = trim($value);
    }
}

$db_host = $_ENV['DB_HOST'] ?? 'localhost';
$db_name = $_ENV['DB_NAME'] ?? 'smartflow';
$db_user = $_ENV['DB_USER'] ?? 'root';
$db_pass = $_ENV['DB_PASS'] ?? '';

$dsn = "mysql:host=$db_host;dbname=$db_name;charset=utf8mb4";

try {
    $pdo = new PDO($dsn, $db_user, $db_pass, [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        // Avoid HY093 when the same named placeholder appears twice in one SQL.
        PDO::ATTR_EMULATE_PREPARES   => true,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => 'Database connection failed',
    ]);
    exit;
}

smartflow_bootstrap_schema($pdo);

// Error logging setup
$logLevel = $_ENV['LOG_LEVEL'] ?? 'debug';
$logDir = __DIR__ . '/logs';
if (!is_dir($logDir)) {
    mkdir($logDir, 0755, true);
}

function smartflow_log(string $level, string $message, array $context = []): void {
    global $logLevel, $logDir;
    
    $levels = ['debug' => 0, 'info' => 1, 'warning' => 2, 'error' => 3];
    $currentLevel = $levels[$logLevel] ?? 0;
    $messageLevel = $levels[$level] ?? 0;
    
    if ($messageLevel < $currentLevel) {
        return; // Skip if below log level
    }
    
    $timestamp = date('Y-m-d H:i:s');
    $logMessage = "[$timestamp] [$level] $message";
    if (!empty($context)) {
        $logMessage .= ' ' . json_encode($context);
    }
    $logMessage .= PHP_EOL;
    
    $logFile = $logDir . '/smartflow_' . date('Y-m-d') . '.log';
    file_put_contents($logFile, $logMessage, FILE_APPEND);
}

// CORS handling based on environment
$corsOrigins = $_ENV['CORS_ALLOWED_ORIGINS'] ?? '*';
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '*';
    if ($corsOrigins === '*' || in_array($origin, explode(',', $corsOrigins))) {
        header('Access-Control-Allow-Origin: ' . ($corsOrigins === '*' ? '*' : $origin));
    }
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Authorization, Content-Type, X-Authorization, X-Smartflow-Token');
    header('Access-Control-Max-Age: 86400');
    http_response_code(204);
    exit;
}

// Set CORS header for non-OPTIONS requests
$origin = $_SERVER['HTTP_ORIGIN'] ?? '*';
if ($corsOrigins === '*' || in_array($origin, explode(',', $corsOrigins))) {
    header('Access-Control-Allow-Origin: ' . ($corsOrigins === '*' ? '*' : $origin));
}

// Helper: send JSON response
function json_response($data, int $statusCode = 200): void
{
    http_response_code($statusCode);
    header('Content-Type: application/json');
    echo json_encode($data);
    exit;
}

function smartflow_request_json(): array
{
    static $cached = null;
    if ($cached !== null) {
        return $cached;
    }

    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    $cached = is_array($data) ? $data : [];

    return $cached;
}

function get_json_body(): array
{
    return smartflow_request_json();
}

function get_bearer_token(): ?string
{
    $candidates = [];

    $candidates[] = $_SERVER['HTTP_AUTHORIZATION'] ?? null;
    $candidates[] = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null;
    $candidates[] = $_SERVER['Authorization'] ?? null;
    $candidates[] = $_SERVER['HTTP_X_AUTHORIZATION'] ?? null;
    $candidates[] = $_SERVER['HTTP_X_SMARTFLOW_TOKEN'] ?? null;

    if (function_exists('getallheaders')) {
        $headers = getallheaders();
        if (is_array($headers)) {
            $candidates[] = $headers['Authorization'] ?? $headers['authorization'] ?? null;
            $candidates[] = $headers['X-Authorization'] ?? $headers['x-authorization'] ?? null;
            $candidates[] = $headers['X-Smartflow-Token'] ?? $headers['x-smartflow-token'] ?? null;
        }
    }

    foreach ($candidates as $auth) {
        $auth = trim((string)$auth);
        if ($auth === '') {
            continue;
        }
        if (preg_match('/Bearer\s+(.+)/i', $auth, $m)) {
            return trim($m[1]);
        }
        // Raw token from X-Smartflow-Token (Apache often drops Authorization).
        if (!str_contains($auth, ' ')) {
            return $auth;
        }
    }

    $fromQuery = trim((string)($_GET['access_token'] ?? ''));
    if ($fromQuery !== '') {
        return $fromQuery;
    }

    $fromBody = trim((string)(smartflow_request_json()['access_token'] ?? ''));
    if ($fromBody !== '') {
        return $fromBody;
    }

    return null;
}

function user_id_from_token(?string $token): ?int
{
    if (!$token) {
        return null;
    }

    global $pdo;

    // 1) Database session (sha256 of the bearer string).
    try {
        $tokenHash = hash('sha256', $token);
        try {
            $stmt = $pdo->prepare('
                SELECT user_id
                FROM auth_tokens
                WHERE token_hash = :hash
                  AND is_revoked = 0
                  AND expires_at > NOW()
                LIMIT 1
            ');
            $stmt->execute([':hash' => $tokenHash]);
        } catch (PDOException $e) {
            $stmt = $pdo->prepare('
                SELECT user_id
                FROM auth_tokens
                WHERE token_hash = :hash
                  AND expires_at > NOW()
                LIMIT 1
            ');
            $stmt->execute([':hash' => $tokenHash]);
        }
        $row = $stmt->fetch();
        if ($row) {
            return (int)$row['user_id'];
        }
    } catch (PDOException $e) {
        // Table missing — fall through to legacy decode.
    }

    // 2) Legacy / dual-format: base64("<user_id>|<random>")
    $decoded = base64_decode($token, true);
    if ($decoded === false || !str_contains($decoded, '|')) {
        return null;
    }

    [$userIdRaw] = explode('|', $decoded, 2);
    $userId = (int)$userIdRaw;
    return $userId > 0 ? $userId : null;
}

// Generate secure token and store in database.
// Token string is always legacy-compatible base64 so API auth works even if
// auth_tokens insert/lookup fails (older schema / clock skew).
function generate_auth_token(int $userId, int $ttlSeconds = 86400): string
{
    global $pdo;

    $token = base64_encode($userId . '|' . bin2hex(random_bytes(16)));
    $tokenHash = hash('sha256', $token);

    try {
        if (function_exists('smartflow_ensure_auth_tokens')) {
            smartflow_ensure_auth_tokens($pdo);
        }

        $delete = $pdo->prepare('DELETE FROM auth_tokens WHERE user_id = :user_id');
        $delete->execute([':user_id' => $userId]);

        $insert = $pdo->prepare('
            INSERT INTO auth_tokens (user_id, token_hash, expires_at)
            VALUES (:user_id, :hash, DATE_ADD(NOW(), INTERVAL :ttl SECOND))
        ');
        $insert->execute([
            ':user_id' => $userId,
            ':hash' => $tokenHash,
            ':ttl' => $ttlSeconds,
        ]);
    } catch (PDOException $e) {
        // Session still usable via legacy decode of $token.
        smartflow_log('warning', 'auth_tokens store failed', [
            'user_id' => $userId,
            'error' => $e->getMessage(),
        ]);
    }

    return $token;
}

// Revoke all tokens for a user
function revoke_user_tokens(int $userId): void
{
    global $pdo;
    try {
        $stmt = $pdo->prepare('UPDATE auth_tokens SET is_revoked = 1 WHERE user_id = :user_id');
        $stmt->execute([':user_id' => $userId]);
    } catch (PDOException $e) {
        // Ignore if table doesn't exist
    }
}

// Very lightweight "auth": token format is base64("<user_id>|<random>")
// This is enough for capstone demo; for production store tokens in DB.
function require_user_id(): int
{
    $token = get_bearer_token();
    $userId = user_id_from_token($token);
    if (!$userId) {
        json_response(['success' => false, 'message' => 'Missing or invalid token'], 401);
    }

    return $userId;
}

/** Set ALLOW_DEV_TOOLS=false in .env on municipal LAN before go-live. */
define('SMARTFLOW_ALLOW_DEV_TOOLS', ($_ENV['ALLOW_DEV_TOOLS'] ?? 'true') === 'true');

/**
 * Blocks dev-only endpoints when SMARTFLOW_ALLOW_DEV_TOOLS is false.
 * When enabled, requires an active admin Bearer token.
 */
function smartflow_require_dev_admin(PDO $pdo): void
{
    if (!SMARTFLOW_ALLOW_DEV_TOOLS) {
        json_response([
            'success' => false,
            'message' => 'Developer tools are disabled on this server',
        ], 403);
    }

    $userId = require_user_id();
    $stmt = $pdo->prepare('
        SELECT role FROM users WHERE id = :id AND is_active = 1 LIMIT 1
    ');
    $stmt->execute([':id' => $userId]);
    $row = $stmt->fetch();
    if (!$row || ($row['role'] ?? '') !== 'admin') {
        json_response([
            'success' => false,
            'message' => 'Admin login required for developer tools',
        ], 403);
    }
}

/** Allow setup scripts on the same machine without a Bearer token. */
function smartflow_dev_localhost_or_admin(PDO $pdo): void
{
    $ip = trim((string)($_SERVER['REMOTE_ADDR'] ?? ''));
    if (in_array($ip, ['127.0.0.1', '::1'], true)) {
        return;
    }
    smartflow_require_dev_admin($pdo);
}

