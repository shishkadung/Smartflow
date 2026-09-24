# Purge ALL documents, movements, and document requests - clean DB for defense demo.
# Requires: XAMPP Apache + MySQL running.
# Usage:  .\scripts\purge-demo-data.ps1

$ErrorActionPreference = "Stop"
$Api = "http://localhost/Smartflow/backend/backend/api"

Write-Host ""
Write-Host "  SmartFlow - purge all demo documents" -ForegroundColor Cyan
Write-Host ""

& (Join-Path $PSScriptRoot "sync-backend-to-xampp.ps1")

Write-Host ""
Write-Host "Purging (documents + movements + requests)..." -ForegroundColor Yellow

try {
    $purge = Invoke-RestMethod -Uri "$Api/dev-purge-demo-documents.php?all=1" -TimeoutSec 30
}
catch {
    Write-Host ""
    Write-Host "  Cannot reach API. Start XAMPP (Apache + MySQL), then run again." -ForegroundColor Red
    Write-Host "    .\scripts\purge-demo-data.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if (-not $purge.success) {
    Write-Host "  Purge failed: $($purge.message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  $($purge.message)" -ForegroundColor Green
if ($purge.requests_cleared -gt 0) {
    Write-Host "  Document requests cleared: $($purge.requests_cleared)" -ForegroundColor DarkGray
}
if ($null -ne $purge.deleted -and $purge.deleted.Count -gt 0) {
    Write-Host "  Deleted IDs:" -ForegroundColor DarkGray
    foreach ($id in $purge.deleted) {
        Write-Host "    $id" -ForegroundColor DarkGray
    }
}
else {
    Write-Host "  Database was already empty - ready for fresh demo." -ForegroundColor Green
}

Write-Host ""
Write-Host "  Ready for clean defense demo." -ForegroundColor Green
Write-Host ""
