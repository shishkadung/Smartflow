# Sync project PHP backend -> XAMPP htdocs (run after any backend edit)
#   Source:  Capstone\backend\backend
#   Dest:    C:\xampp\htdocs\Smartflow\backend\backend
#
# Usage:
#   .\scripts\sync-backend-to-xampp.ps1
#   .\scripts\sync-backend-to-xampp.ps1 -Quiet

param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$Src = Join-Path $ProjectRoot "backend\backend"
$Dest = "C:\xampp\htdocs\Smartflow\backend\backend"

if (-not (Test-Path $Src)) {
    throw "Source not found: $Src"
}

if (-not (Test-Path "C:\xampp\htdocs")) {
    throw "XAMPP htdocs not found. Install XAMPP or fix the destination path."
}

$destParent = Split-Path $Dest -Parent
if (-not (Test-Path $destParent)) {
    New-Item -ItemType Directory -Path $destParent -Force | Out-Null
}

if (-not $Quiet) {
    Write-Host "Syncing backend..." -ForegroundColor Cyan
    Write-Host "  From: $Src"
    Write-Host "  To:   $Dest"
}

# /MIR = mirror (add/update/delete) so htdocs matches project
# Exclude dev-only junk if present
robocopy $Src $Dest /MIR /XD .git node_modules /XF *.log /R:2 /W:2 /NFL /NDL /NJH /NJS | Out-Null
$code = $LASTEXITCODE
# robocopy: 0-7 = success; 8+ = failure
if ($code -ge 8) {
    throw "robocopy failed with exit code $code"
}

if (-not $Quiet) {
    $okCodes = @(0, 1, 2, 3)
    if ($code -in $okCodes) {
        Write-Host "  Sync OK (no changes or files copied)." -ForegroundColor Green
    } else {
        Write-Host "  Sync OK (exit code $code)." -ForegroundColor Green
    }
    Write-Host "  API: http://localhost/Smartflow/backend/backend/api" -ForegroundColor DarkGray
}

exit 0
