<?php
// Simple rate limiting middleware using file-based storage
// Include this in endpoints that need rate limiting

class RateLimiter {
    private string $storageDir;
    private int $requestsPerMinute;
    private string $identifier;

    public function __construct(int $requestsPerMinute = 60) {
        $this->storageDir = __DIR__ . '/cache/rate_limit';
        $this->requestsPerMinute = $requestsPerMinute;
        $this->identifier = $this->getIdentifier();
        
        // Ensure storage directory exists
        if (!is_dir($this->storageDir)) {
            mkdir($this->storageDir, 0755, true);
        }
    }

    private function getIdentifier(): string {
        // Use IP address as identifier
        $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        // For authenticated requests, use user ID instead
        $token = $this->getBearerToken();
        if ($token) {
            $userId = $this->userIdFromToken($token);
            if ($userId) {
                return 'user_' . $userId;
            }
        }
        return 'ip_' . md5($ip);
    }

    private function getBearerToken(): ?string {
        $candidates = [];
        $candidates[] = $_SERVER['HTTP_AUTHORIZATION'] ?? null;
        $candidates[] = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null;
        $candidates[] = $_SERVER['Authorization'] ?? null;

        if (function_exists('getallheaders')) {
            $headers = getallheaders();
            if (is_array($headers)) {
                $candidates[] = $headers['Authorization'] ?? $headers['authorization'] ?? null;
            }
        }

        foreach ($candidates as $auth) {
            if (!$auth) continue;
            if (preg_match('/Bearer\s+(.+)/i', $auth, $m)) {
                return trim($m[1]);
            }
        }
        return null;
    }

    private function userIdFromToken(?string $token): ?int {
        if (!$token) return null;
        $decoded = base64_decode($token, true);
        if ($decoded === false || !str_contains($decoded, '|')) return null;
        [$userIdRaw] = explode('|', $decoded, 2);
        $userId = (int)$userIdRaw;
        return $userId > 0 ? $userId : null;
    }

    public function check(): bool {
        $file = $this->storageDir . '/' . $this->identifier . '.json';
        $now = time();
        $windowStart = $now - 60; // 1 minute window

        $data = ['requests' => []];
        if (file_exists($file)) {
            $json = file_get_contents($file);
            $data = json_decode($json, true) ?: ['requests' => []];
        }

        // Clean old requests outside the window
        $data['requests'] = array_filter($data['requests'], fn($t) => $t > $windowStart);

        // Check if limit exceeded
        if (count($data['requests']) >= $this->requestsPerMinute) {
            return false;
        }

        // Add current request
        $data['requests'][] = $now;
        file_put_contents($file, json_encode($data));

        return true;
    }

    public function getHeaders(): array {
        $file = $this->storageDir . '/' . $this->identifier . '.json';
        $remaining = $this->requestsPerMinute;
        
        if (file_exists($file)) {
            $json = file_get_contents($file);
            $data = json_decode($json, true) ?: ['requests' => []];
            $windowStart = time() - 60;
            $data['requests'] = array_filter($data['requests'], fn($t) => $t > $windowStart);
            $remaining = max(0, $this->requestsPerMinute - count($data['requests']));
        }

        return [
            'X-RateLimit-Limit' => $this->requestsPerMinute,
            'X-RateLimit-Remaining' => $remaining,
            'X-RateLimit-Reset' => time() + 60
        ];
    }
}

// Usage in endpoints:
// require_once __DIR__ . '/rate-limit.php';
// $limiter = new RateLimiter((int)($_ENV['RATE_LIMIT_PER_MINUTE'] ?? 60));
// if (!$limiter->check()) {
//     http_response_code(429);
//     header('Content-Type: application/json');
//     echo json_encode(['success' => false, 'message' => 'Too many requests']);
//     exit;
// }
// foreach ($limiter->getHeaders() as $name => $value) {
//     header("$name: $value");
// }
