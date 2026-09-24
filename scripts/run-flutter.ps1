# Run SmartFlow Flutter app (syncs backend to XAMPP, then runs Flutter)
& (Join-Path $PSScriptRoot "sync-backend-to-xampp.ps1") -Quiet
# Quick health ping — fails fast if Apache/MySQL are off
try {
    $h = Invoke-RestMethod -Uri "http://localhost/Smartflow/backend/backend/api/dev-api-health.php" -TimeoutSec 8
    if (-not $h.success) { Write-Warning "API health check failed — run .\scripts\fix-api.ps1" }
} catch {
    Write-Warning "Cannot reach localhost API. Start XAMPP (Apache + MySQL), then .\scripts\fix-api.ps1"
}
$env:Path = "C:\src\flutter\bin;" + $env:Path
Set-Location (Join-Path (Split-Path $PSScriptRoot -Parent) "mobile\flutter")
flutter pub get
flutter run @args
