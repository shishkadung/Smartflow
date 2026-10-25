# SmartFlow Production Setup Verification Script
# Run this to verify all production hardening changes are in place

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent

Write-Host "=== SmartFlow Production Setup Verification ===" -ForegroundColor Cyan
Write-Host ""

$PassCount = 0
$FailCount = 0
$Warnings = @()

function Test-FileExists {
    param($Path, $Description)
    $FullPath = Join-Path $ProjectRoot $Path
    if (Test-Path $FullPath) {
        Write-Host "[PASS] $Description" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[FAIL] $Description - File not found: $FullPath" -ForegroundColor Red
        return $false
    }
}

function Test-FileContains {
    param($Path, $Pattern, $Description)
    $FullPath = Join-Path $ProjectRoot $Path
    if (Test-Path $FullPath) {
        $Content = Get-Content $FullPath -Raw
        if ($Content -match $Pattern) {
            Write-Host "[PASS] $Description" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[FAIL] $Description - Pattern not found" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "[FAIL] $Description - File not found" -ForegroundColor Red
        return $false
    }
}

# Backend Configuration Checks
Write-Host "=== Backend Configuration ===" -ForegroundColor Yellow

if (Test-FileExists "backend\backend\api\.env" "Environment file exists") { $PassCount++ } else { $FailCount++ }
if (Test-FileExists "backend\backend\api\.env.example" "Environment example exists") { $PassCount++ } else { $FailCount++ }
if (Test-FileContains "backend\backend\api\.env" "DB_HOST=" "Database host configured") { $PassCount++ } else { $FailCount++ }
if (Test-FileContains "backend\backend\api\.env" '(?m)^\s*ALLOW_DEV_TOOLS\s*=\s*false\s*$' "Maintenance explicitly disabled") { $PassCount++ } else { $FailCount++ }
if (Test-FileContains "backend\backend\api\.env" "CORS_ALLOWED_ORIGINS=" "CORS configured") { $PassCount++ } else { $FailCount++ }

# Security Features
Write-Host ""
Write-Host "=== Security Features ===" -ForegroundColor Yellow

if (Test-FileExists "backend\backend\api\dev-block.php" "Dev tools blocker exists") { $PassCount++ } else { $FailCount++ }
if (Test-FileContains "backend\backend\api\dev-block.php" "PHP_SAPI !== 'cli'" "HTTP maintenance rejected before configuration") { $PassCount++ } else { $FailCount++ }
if (Test-FileContains "backend\backend\api\dev-block.php" '--allow-maintenance' "CLI maintenance requires explicit confirmation") { $PassCount++ } else { $FailCount++ }
if (Test-FileExists "backend\backend\api\dev-tools-policy.php" "Fail-closed maintenance policy exists") { $PassCount++ } else { $FailCount++ }
if (Test-FileContains "backend\backend\api\.htaccess" 'users-email-migration' "Apache denies maintenance scripts") { $PassCount++ } else { $FailCount++ }
if (Test-FileExists "backend\backend\api\rate-limit.php" "Rate limiter exists") { $PassCount++ } else { $FailCount++ }
if (Test-FileExists "backend\backend\api\auth-tokens-migration.sql" "Auth tokens migration exists") { $PassCount++ } else { $FailCount++ }

# Check dev files include dev-block
Write-Host ""
Write-Host "=== Dev Tools Protection ===" -ForegroundColor Yellow

$DevFiles = @(
    "backend\backend\api\dev-api-health.php",
    "backend\backend\api\dev-seed-demo-users.php",
    "backend\backend\api\dev-purge-demo-documents.php",
    "backend\backend\api\dev-reset-system.php",
    "backend\backend\api\dev-create-user.php"
)

foreach ($File in $DevFiles) {
    if (Test-FileContains $File "require __DIR__ . '/dev-block.php'" "Dev block included in $(Split-Path $File -Leaf)") {
        $PassCount++
    } else {
        $FailCount++
    }
}

# Backup Scripts
Write-Host ""
Write-Host "=== Backup Scripts ===" -ForegroundColor Yellow

if (Test-FileExists "scripts\backup-database.ps1" "Backup script exists") { $PassCount++ } else { $FailCount++ }
if (Test-FileExists "scripts\restore-database.ps1" "Restore script exists") { $PassCount++ } else { $FailCount++ }

# Flutter Configuration
Write-Host ""
Write-Host "=== Flutter Configuration ===" -ForegroundColor Yellow

if (Test-FileExists "mobile\flutter\android\keystore.properties.example" "Keystore example exists") { $PassCount++ } else { $FailCount++ }
if (Test-FileExists "mobile\flutter\android\app\proguard-rules.pro" "ProGuard rules exist") { $PassCount++ } else { $FailCount++ }
if (Test-FileExists "mobile\flutter\android\app\src\main\res\xml\network_security_config.xml" "Network security config exists") { $PassCount++ } else { $FailCount++ }

if (Test-FileContains "mobile\flutter\lib\config\api_config.dart" "_productionUrl" "Production URL configured") { $PassCount++ } else { $FailCount++ }
if (Test-FileContains "mobile\flutter\lib\config\api_config.dart" "ENV" "Environment variable support") { $PassCount++ } else { $FailCount++ }

# Android Manifest
Write-Host ""
Write-Host "=== Android Security ===" -ForegroundColor Yellow

if (Test-FileContains "mobile\flutter\android\app\src\main\AndroidManifest.xml" "usesCleartextTraffic=\"false\"" "Cleartext traffic disabled") { $PassCount++ } else { $FailCount++ }
if (Test-FileContains "mobile\flutter\android\app\src\main\AndroidManifest.xml" "networkSecurityConfig" "Network security config referenced") { $PassCount++ } else { $FailCount++ }

# Documentation
Write-Host ""
Write-Host "=== Documentation ===" -ForegroundColor Yellow

if (Test-FileExists "docs\product\PRODUCTION-DEPLOYMENT.md" "Production deployment guide exists") { $PassCount++ } else { $FailCount++ }

# Summary
Write-Host ""
Write-Host "=== Verification Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $PassCount" -ForegroundColor Green
Write-Host "Failed: $FailCount" -ForegroundColor Red
Write-Host "Total: $($PassCount + $FailCount)" -ForegroundColor Yellow

if ($FailCount -eq 0) {
    Write-Host ""
    Write-Host "Static configuration checks passed. Runtime, transport, backup and device acceptance still need their own evidence." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. New installation only: privately provision .env; updates preserve existing settings and QR keys" -ForegroundColor Yellow
    Write-Host "2. Review APP_ENV=production, ALLOW_DEV_TOOLS=false, explicit CORS origins and database privileges" -ForegroundColor Yellow
    Write-Host "3. Rehearse required schema changes on an isolated copy; do not routinely reimport legacy migrations" -ForegroundColor Yellow
    Write-Host "4. Configure the protected Android release keystore; release builds cannot fall back to debug signing" -ForegroundColor Yellow
    Write-Host "5. Verify the intended HTTPS API returns JSON and forwards authentication headers" -ForegroundColor Yellow
    Write-Host "6. Build with ENV=production and the confirmed HTTPS API_BASE, then verify signing and device behavior" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host ""
    Write-Host "✗ Some checks failed. Please review the failures above." -ForegroundColor Red
    exit 1
}
