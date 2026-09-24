# SmartFlow one-click local setup (XAMPP + API seed + optional Flutter)

# Run in PowerShell:  .\scripts\setup-smartflow.ps1



$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent

$HtdocsApi = "http://localhost/Smartflow/backend/backend/api"

$HtdocsPath = "C:\xampp\htdocs\Smartflow"



Write-Host "=== SmartFlow Setup ===" -ForegroundColor Cyan



# 1) Sync backend\backend -> XAMPP (always mirror project copy)

& (Join-Path $PSScriptRoot "sync-backend-to-xampp.ps1")

$apiDir = Join-Path $HtdocsPath "backend\backend\api"
$requiredApi = @(
    "document-requests-list.php",
    "document-requests-create.php",
    "document-requests-update.php",
    "document-requests-summary.php",
    "dashboard-stats.php"
)
$missingApi = $requiredApi | Where-Object { -not (Test-Path (Join-Path $apiDir $_)) }
if ($missingApi.Count -gt 0) {
    Write-Host "  Missing API files after sync: $($missingApi -join ', ')" -ForegroundColor Red
    Write-Host "  Re-run sync-backend-to-xampp.ps1 or copy backend\backend manually." -ForegroundColor Red
    exit 1
}



# 2) Schema + API health

Write-Host "Running API health check..."
try {
    $health = Invoke-RestMethod -Uri "$HtdocsApi/dev-api-health.php" -TimeoutSec 30
    if (-not $health.success) {
        Write-Host "  Health check failed:" -ForegroundColor Red
        $health.checks | Where-Object { -not $_.ok } | ForEach-Object {
            Write-Host "    $($_.name): $($_.error)" -ForegroundColor Red
        }
        exit 1
    }
    Write-Host "  Health OK ($($health.checks.Count) checks)" -ForegroundColor Green
} catch {
    Write-Host "  dev-api-health.php failed. Sync backend and ensure MySQL is running." -ForegroundColor Red
    exit 1
}

# 3) Test API

Write-Host "Testing API..."

try {

    $offices = Invoke-RestMethod -Uri "$HtdocsApi/offices-list.php" -TimeoutSec 15

    if (-not $offices.success) { throw "offices-list failed" }

    Write-Host "  API OK - $($offices.offices.Count) pilot offices" -ForegroundColor Green

} catch {

    Write-Host "  API not reachable. Start Apache/MySQL in XAMPP Control Panel." -ForegroundColor Red

    Write-Host "  Expected: $HtdocsApi/offices-list.php"

    exit 1

}



# 4) Replace / seed Capstone team user accounts (no sample documents)

Write-Host "Installing Capstone team user accounts..."

try {
    $seed = Invoke-RestMethod -Uri "$HtdocsApi/dev-replace-team-users.php" -TimeoutSec 60
} catch {
    $seed = Invoke-RestMethod -Uri "$HtdocsApi/dev-seed-demo-users.php" -TimeoutSec 30
}

Write-Host "  $($seed.message)" -ForegroundColor Green



# 5) Remove legacy demo documents if a previous setup seeded them

Write-Host "Purging demo documents (if any)..."

try {

    $purge = Invoke-RestMethod -Uri "$HtdocsApi/dev-purge-demo-documents.php?all=1" -TimeoutSec 30

    Write-Host "  $($purge.message)" -ForegroundColor Green

    if ($purge.deleted.Count -gt 0) {

        Write-Host "  Removed: $($purge.deleted -join ', ')" -ForegroundColor DarkGray

    }

} catch {

    Write-Host "  Purge skipped (endpoint not available yet)." -ForegroundColor DarkYellow

}



# 6) Test login (ENG clerk — Kristofer)

$loginUser = "kristofer.eng"

$loginPass = "smartflow123"

$login = Invoke-RestMethod -Uri "$HtdocsApi/auth-login.php" -Method POST `

    -Body "{`"username`":`"$loginUser`",`"password`":`"$loginPass`"}" `

    -ContentType "application/json"

if ($login.success) {

    Write-Host "  Login OK as $loginUser" -ForegroundColor Green

}



Write-Host ""

Write-Host "Mobile API URLs (already set in apps):" -ForegroundColor Cyan

Write-Host "  Emulator:  http://10.0.2.2/Smartflow/backend/backend/api"

Write-Host "  Browser:   $HtdocsApi"

Write-Host ""

Write-Host "Pilot accounts use password smartflow123 (change in production)." -ForegroundColor DarkGray

Write-Host "Documents are not auto-seeded — register and scan real folders in the app."

Write-Host ""

Write-Host "Flutter (after SDK installed):" -ForegroundColor Cyan

Write-Host "  cd mobile\flutter"

Write-Host "  C:\src\flutter\bin\flutter.bat pub get"

Write-Host "  C:\src\flutter\bin\flutter.bat run"

Write-Host ""

Write-Host "Android Studio: open mobile/android and Run" -ForegroundColor Cyan

