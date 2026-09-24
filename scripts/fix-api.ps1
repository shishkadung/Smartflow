# One-shot fix for "API not found" in the Flutter app.
# Syncs PHP to XAMPP, runs health check, tests login + dashboard.
#
# Usage:  .\scripts\fix-api.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$Api = "http://localhost/Smartflow/backend/backend/api"

Write-Host "=== SmartFlow API fix ===" -ForegroundColor Cyan

& (Join-Path $PSScriptRoot "sync-backend-to-xampp.ps1")

Write-Host ""
Write-Host "Checking Apache + API..." -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "$Api/dev-api-health.php" -TimeoutSec 20
    if (-not $health.success) {
        Write-Host "Health check failed:" -ForegroundColor Red
        $health.checks | Where-Object { -not $_.ok } | ForEach-Object {
            Write-Host "  $($_.name): $($_.error)" -ForegroundColor Red
        }
        exit 1
    }
    Write-Host "  Health OK" -ForegroundColor Green
} catch {
    Write-Host "  Cannot reach $Api" -ForegroundColor Red
    Write-Host "  Start Apache + MySQL in XAMPP Control Panel, then run this script again." -ForegroundColor Yellow
    exit 1
}

$login = Invoke-RestMethod -Uri "$Api/auth-login.php" -Method POST `
    -Body '{"username":"engineering.staff","password":"smartflow123"}' `
    -ContentType "application/json"
if (-not $login.success) {
    Write-Host "  Login test failed" -ForegroundColor Red
    exit 1
}
$token = $login.token
$oid = [int]$login.user.office_id

$headers = @{ Authorization = "Bearer $token" }
$dash = Invoke-RestMethod -Uri "$Api/dashboard-stats.php?office_id=$oid" -Headers $headers
$sum = Invoke-RestMethod -Uri "$Api/document-requests-summary.php" -Headers $headers
if (-not $dash.success -or -not $sum.success) {
    Write-Host "  Authenticated API test failed" -ForegroundColor Red
    exit 1
}

Write-Host "  Dashboard + request summary OK" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "  1. Restart Apache in XAMPP (Stop -> Start) if the app still shows errors"
Write-Host "  2. Hot restart Flutter (R) or:  .\scripts\run-flutter.ps1"
Write-Host "  3. Emulator URL: http://10.0.2.2/Smartflow/backend/backend/api"
