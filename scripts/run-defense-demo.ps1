# One command before defense: check API reachability and remind Flutter path.
# Usage:  .\scripts\run-defense-demo.ps1
#         .\scripts\run-defense-demo.ps1 -Launch   # also starts flutter run

param(
    [switch]$Launch
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "  SmartFlow - defense prep (Neil: huwag mag-isip, sundin lang)" -ForegroundColor Cyan
Write-Host ""

& (Join-Path $PSScriptRoot "fix-api.ps1")

Write-Host ""
Write-Host "  XAMPP: Apache + MySQL dapat RUNNING (green)" -ForegroundColor Yellow
Write-Host "  Flutter: cd mobile\flutter  OR  .\scripts\run-flutter.ps1" -ForegroundColor Yellow
Write-Host "  Cheat sheet: docs\defense\START-HERE.md" -ForegroundColor Green
Write-Host ""

if ($Launch) {
    & (Join-Path $PSScriptRoot "run-flutter.ps1")
}
