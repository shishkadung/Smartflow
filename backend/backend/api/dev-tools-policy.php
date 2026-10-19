<?php
declare(strict_types=1);

/** Shared read-only environment loading, before any database or maintenance action. */
function smartflow_load_environment(string $envFile): void
{
    if (!file_exists($envFile)) return;
    foreach (file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (strpos(trim($line), '#') === 0 || !str_contains($line, '=')) continue;
        [$name, $value] = explode('=', $line, 2);
        $name = trim($name);
        // Explicit process/server settings take precedence over local defaults.
        if (!array_key_exists($name, $_ENV)) {
            $processValue = getenv($name);
            $_ENV[$name] = $processValue !== false ? $processValue : trim($value);
        }
    }
}

/** Maintenance stays disabled unless both the environment and opt-in are explicit. */
function smartflow_dev_tools_enabled(array $environment): bool
{
    return in_array(strtolower(trim((string)($environment['APP_ENV'] ?? ''))), ['development', 'test', 'testing'], true)
        && ($environment['ALLOW_DEV_TOOLS'] ?? 'false') === 'true';
}
