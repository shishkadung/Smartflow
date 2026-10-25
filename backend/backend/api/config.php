<?php
// Basic database configuration for SmartFlow API

declare(strict_types=1);

require_once __DIR__ . '/schema-bootstrap.php';
require_once __DIR__ . '/rate-limit.php';
require_once __DIR__ . '/dev-tools-policy.php';
require_once __DIR__ . '/production-config-guard.php';
smartflow_register_error_handlers();

$smartflowEnvFile = __DIR__ . '/.env';
smartflow_load_environment($smartflowEnvFile);
smartflow_enforce_environment_safety($_ENV, file_exists($smartflowEnvFile));

// PHP and MySQL must share one clock — XAMPP defaults PHP to Europe/Berlin, which skews due/overdue math.
$appTimezone = $_ENV['APP_TIMEZONE'] ?? 'Asia/Manila';
if (!@date_default_timezone_set($appTimezone)) {
    date_default_timezone_set('Asia/Manila');
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
    $pdo->exec("SET time_zone = '" . (new DateTime())->format('P') . "'");
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
$corsAllowList = smartflow_cors_origin_list($corsOrigins);
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '*';
    if ($corsOrigins === '*' || in_array($origin, $corsAllowList, true)) {
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
if ($corsOrigins === '*' || in_array($origin, $corsAllowList, true)) {
    header('Access-Control-Allow-Origin: ' . ($corsOrigins === '*' ? '*' : $origin));
}

// Helper: send JSON response
function json_response($data, int $statusCode = 200): void
{
    http_response_code($statusCode);
    header('Cache-Control: no-store');
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

    $input = file_get_contents(PHP_SAPI === 'cli' ? 'php://stdin' : 'php://input');
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

    return null;
}

function user_id_from_token(?string $token): ?int
{
    if (!$token) {
        return null;
    }

    global $pdo;

    // A session must exist in the database and still be valid. Decoding the
    // user ID from the bearer string never proves that the session was issued.
    try {
        $tokenHash = hash('sha256', $token);
        $stmt = $pdo->prepare('
                SELECT user_id
                FROM auth_tokens
                WHERE token_hash = :hash
                  AND is_revoked = 0
                  AND expires_at > NOW()
                LIMIT 1
            ');
        $stmt->execute([':hash' => $tokenHash]);
        $row = $stmt->fetch();
        if ($row) {
            return (int)$row['user_id'];
        }
    } catch (PDOException $e) {
        smartflow_log('error', 'Session lookup failed', ['error' => $e->getMessage()]);
    }

    return null;
}

// Generate secure token and store in database.
// Keep the existing opaque bearer format; validity comes from its stored hash.
function generate_auth_token(int $userId, int $ttlSeconds = 86400): string
{
    global $pdo;

    $token = base64_encode($userId . '|' . bin2hex(random_bytes(16)));
    $tokenHash = hash('sha256', $token);

    try {
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
        smartflow_log('error', 'auth_tokens store failed', [
            'user_id' => $userId,
            'error' => $e->getMessage(),
        ]);
        throw new RuntimeException('Could not create authenticated session', 0, $e);
    }

    return $token;
}

// Revoke all tokens for a user
function revoke_user_tokens(int $userId): void
{
    global $pdo;
    $stmt = $pdo->prepare('UPDATE auth_tokens SET is_revoked = 1 WHERE user_id = :user_id');
    $stmt->execute([':user_id' => $userId]);
}

function require_user_id(): int
{
    $token = get_bearer_token();
    $userId = user_id_from_token($token);
    if (!$userId) {
        json_response(['success' => false, 'message' => 'Missing or invalid token'], 401);
    }

    global $pdo;
    $mustChange = 0;
    try {
        $stmt = $pdo->prepare('SELECT is_active, must_change_password FROM users WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $userId]);
        $row = $stmt->fetch();
        $active = $row === false ? false : $row['is_active'];
        $mustChange = $row === false ? 0 : (int)$row['must_change_password'];
    } catch (PDOException $e) {
        // The flag column is created by the first administrator password reset.
        $stmt = $pdo->prepare('SELECT is_active FROM users WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $userId]);
        $active = $stmt->fetchColumn();
    }
    if ($active === false || !(int)$active) {
        json_response(['success' => false, 'message' => 'This account has been deactivated. Contact your municipal administrator.'], 403);
    }
    // A temporary password allows only choosing a new one (or signing out) until it has been replaced.
    if ($mustChange && !in_array(basename((string)($_SERVER['SCRIPT_NAME'] ?? '')), ['users-change-password.php', 'auth-logout.php', 'auth-session.php'], true)) {
        json_response(['success' => false, 'message' => 'You must choose a new password before continuing.', 'password_change_required' => true], 403);
    }
    header('Cache-Control: no-store');

    static $limited = false;
    if (!$limited && PHP_SAPI !== 'cli') {
        $limited = true;
        $write = ($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET';
        smartflow_rate_limit('api:' . ($write ? 'write:' : 'read:') . $userId,
            (int)($_ENV[$write ? 'RATE_LIMIT_PER_MINUTE' : 'RATE_LIMIT_READ_PER_MINUTE'] ?? ($write ? 60 : 240)));
    }

    return $userId;
}

/** Explicit CLI maintenance opt-in only; no public response or HTTP route may rely on this flag. */
define(
    'SMARTFLOW_ALLOW_DEV_TOOLS',
    smartflow_dev_tools_enabled($_ENV)
);

/**
 * Legacy maintenance helpers must never restore localhost or admin HTTP access.
 */
function smartflow_require_dev_admin(PDO $pdo): void
{
    if (PHP_SAPI !== 'cli' || !SMARTFLOW_ALLOW_DEV_TOOLS
        || !in_array('--allow-maintenance', $_SERVER['argv'] ?? [], true)) {
        json_response([
            'success' => false,
            'message' => 'Developer tools are disabled on this server',
        ], 403);
    }

}

/**
 * Destructive dev tools (purge/reset) — explicit CLI maintenance only.
 * Movement and audit-trail records must be retained for 15 years (client).
 */
function smartflow_dev_localhost_only(): void
{
    if (PHP_SAPI !== 'cli' || !SMARTFLOW_ALLOW_DEV_TOOLS
        || !in_array('--allow-maintenance', $_SERVER['argv'] ?? [], true)) {
        json_response([
            'success' => false,
            'message' => 'Developer tools are disabled on this server',
        ], 403);
    }
}

/** Compatibility name for legacy CLI-only maintenance callers. */
function smartflow_dev_localhost_or_admin(PDO $pdo): void
{
    smartflow_require_dev_admin($pdo);
}

