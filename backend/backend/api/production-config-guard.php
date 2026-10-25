<?php
declare(strict_types=1);

/** Loopback, private/reserved IPs, localhost, *.localhost and *.test hosts cannot be a public production site. */
function smartflow_host_is_local(?string $hostHeader): bool
{
    $host = parse_url('//' . trim((string)$hostHeader), PHP_URL_HOST);
    if (!is_string($host) || $host === '') {
        return false;
    }
    $host = strtolower(trim($host, '[]'));
    if ($host === 'localhost' || str_ends_with($host, '.localhost') || str_ends_with($host, '.test')) {
        return true;
    }
    if (filter_var($host, FILTER_VALIDATE_IP) !== false) {
        return filter_var($host, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) === false;
    }
    return false;
}

/** Comma-separated CORS_ALLOWED_ORIGINS entries; spaces around commas are not part of an origin. */
function smartflow_cors_origin_list(string $configured): array
{
    return array_values(array_filter(
        array_map('trim', explode(',', $configured)),
        static fn(string $origin): bool => $origin !== ''
    ));
}

/**
 * Names (never values) of settings that make this environment unsafe to serve.
 *
 * APP_ENV=production must carry a deliberate configuration. An unset or unrecognised APP_ENV on a
 * web request to a non-local host is refused too, so a forgotten .env or a typo such as "prod"
 * cannot silently fall back to the development defaults (wildcard CORS, debug logs, root database).
 * The Host header is client supplied: this is a deployment safety net, not an access boundary.
 */
function smartflow_production_config_problems(array $environment, bool $envFileFound, ?string $requestHost, bool $isCli): array
{
    $appEnv = strtolower(trim((string)($environment['APP_ENV'] ?? '')));
    if (!in_array($appEnv, ['development', 'test', 'testing', 'production'], true)) {
        if ($isCli || smartflow_host_is_local($requestHost)) {
            return [];
        }
        return $envFileFound ? ['APP_ENV'] : ['.env', 'APP_ENV'];
    }
    if ($appEnv !== 'production') {
        return [];
    }

    $problems = [];
    $cors = trim((string)($environment['CORS_ALLOWED_ORIGINS'] ?? ''));
    $origins = smartflow_cors_origin_list($cors);
    $validOrigins = $origins !== [];
    foreach ($origins as $origin) {
        if (!preg_match('~^https://[a-z0-9]([a-z0-9.-]*[a-z0-9])?(:[0-9]{1,5})?$~i', $origin)) {
            $validOrigins = false;
        }
    }
    if (!$validOrigins) {
        $problems[] = 'CORS_ALLOWED_ORIGINS';
    }
    if (!in_array(strtolower(trim((string)($environment['LOG_LEVEL'] ?? ''))), ['info', 'warning', 'error'], true)) {
        $problems[] = 'LOG_LEVEL';
    }
    if (in_array(strtolower(trim((string)($environment['ALLOW_DEV_TOOLS'] ?? ''))), ['true', '1', 'yes', 'on'], true)) {
        $problems[] = 'ALLOW_DEV_TOOLS';
    }
    $dbUser = strtolower(trim((string)($environment['DB_USER'] ?? '')));
    if ($dbUser === '' || $dbUser === 'root') {
        $problems[] = 'DB_USER';
    }
    if ((string)($environment['DB_PASS'] ?? '') === '') {
        $problems[] = 'DB_PASS';
    }

    return $problems;
}

/** Stops the request or CLI script before any database work when the environment is unsafe. */
function smartflow_enforce_environment_safety(array $environment, bool $envFileFound): void
{
    $isCli = PHP_SAPI === 'cli';
    $problems = smartflow_production_config_problems(
        $environment,
        $envFileFound,
        $_SERVER['HTTP_HOST'] ?? $_SERVER['SERVER_NAME'] ?? null,
        $isCli
    );
    if ($problems === []) {
        return;
    }

    $detail = 'SmartFlow configuration rejected; review: ' . implode(', ', $problems);
    error_log($detail);
    if ($isCli) {
        fwrite(STDERR, $detail . PHP_EOL);
        exit(1);
    }
    http_response_code(500);
    header('Cache-Control: no-store');
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => 'Server configuration is incomplete. Contact the system administrator.',
    ]);
    exit;
}
