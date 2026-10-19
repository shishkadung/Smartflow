<?php
declare(strict_types=1);

// Locked sliding windows. Identities must come from the IP or a validated session.
class RateLimiter {
    private string $file;
    private int $remaining;
    private int $resetAt;
    public function __construct(
        private int $requestsPerMinute = 60,
        string $identifier = '',
        private int $windowSeconds = 60,
        ?string $storageDir = null
    ) {
        $this->requestsPerMinute = max(1, $this->requestsPerMinute);
        $this->windowSeconds = max(1, $this->windowSeconds);
        $storageDir ??= __DIR__ . '/cache/rate_limit';
        if (!is_dir($storageDir) && !@mkdir($storageDir, 0700, true) && !is_dir($storageDir)) {
            throw new RuntimeException('Rate-limit storage is unavailable');
        }
        $identifier = $identifier ?: 'ip:' . ($_SERVER['REMOTE_ADDR'] ?? 'unknown');
        $this->file = $storageDir . '/' . hash('sha256', $identifier) . '.json';
        $this->remaining = $this->requestsPerMinute;
        $this->resetAt = time() + $this->windowSeconds;
    }
    public function check(?int $now = null): bool {
        $now ??= time();
        $handle = fopen($this->file, 'c+');
        if (!$handle) throw new RuntimeException('Rate-limit storage is unavailable');
        if (!flock($handle, LOCK_EX)) { fclose($handle); throw new RuntimeException('Rate-limit storage is unavailable'); }
        try {
            $data = json_decode(stream_get_contents($handle), true) ?: [];
            $requests = array_values(array_filter($data['requests'] ?? [], fn($t) => is_int($t) && $t > $now - $this->windowSeconds));
            $allowed = count($requests) < $this->requestsPerMinute;
            if ($allowed) $requests[] = $now;
            $this->remaining = max(0, $this->requestsPerMinute - count($requests));
            $this->resetAt = ($requests[0] ?? $now) + $this->windowSeconds;
            rewind($handle);
            ftruncate($handle, 0);
            $encoded = json_encode(['requests' => $requests]);
            if (fwrite($handle, $encoded) !== strlen($encoded) || !fflush($handle)) throw new RuntimeException('Could not persist the rate limit');
            return $allowed;
        } finally {
            flock($handle, LOCK_UN);
            fclose($handle);
        }
    }
    public function getHeaders(): array {
        return ['X-RateLimit-Limit' => $this->requestsPerMinute, 'X-RateLimit-Remaining' => $this->remaining, 'X-RateLimit-Reset' => $this->resetAt];
    }
    public function retryAfter(): int { return max(1, $this->resetAt - time()); }
}

function smartflow_rate_limit(string $identity, int $limit, int $windowSeconds = 60): void {
    $limiter = new RateLimiter(max(1, $limit), $identity, $windowSeconds);
    $allowed = $limiter->check();
    foreach ($limiter->getHeaders() as $name => $value) header("$name: $value");
    if (!$allowed) {
        $retry = $limiter->retryAfter();
        header('Retry-After: ' . $retry);
        json_response(['success' => false, 'message' => 'Too many requests. Please wait before trying again.', 'retry_after' => $retry], 429);
    }
}

function smartflow_public_auth_limit(string $action, int $ipLimit, ?string $username = null, int $accountLimit = 10): void {
    // Never decode the caller's bearer token to choose a public-auth bucket.
    smartflow_rate_limit('auth:' . $action . ':ip:' . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'), $ipLimit);
    if ($username !== null && trim($username) !== '') {
        smartflow_rate_limit('auth:' . $action . ':account:' . strtolower(trim($username)), $accountLimit, 900);
    }
}
