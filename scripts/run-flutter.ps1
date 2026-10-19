# Run SmartFlow Flutter with a read-only reachability check; deployment is separate.
# Quick health ping warns if Apache/MySQL are off.
try {
    $h = Invoke-RestMethod -Uri "http://localhost/Smartflow/backend/backend/api/offices-list.php" -TimeoutSec 8
    if (-not $h.success) { Write-Warning "API health check failed - run .\scripts\fix-api.ps1" }
} catch {
    Write-Warning "Cannot reach localhost API. Start XAMPP (Apache + MySQL), then .\scripts\fix-api.ps1"
}
$env:Path = "C:\src\flutter\bin;" + $env:Path
Set-Location (Join-Path (Split-Path $PSScriptRoot -Parent) "mobile\flutter")
flutter pub get
flutter run @args
