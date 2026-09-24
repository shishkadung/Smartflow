# Extract PDF text to docs/design/SmartFlow-Figma-Screens.md
$reader = Join-Path $PSScriptRoot "pdf-reader"
Set-Location $reader
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing pdf-parse..."
    npm install --silent
}
npm run extract
Set-Location (Split-Path $PSScriptRoot -Parent)
Write-Host ""
Write-Host "Done. Read: docs\design\SmartFlow-Figma-Screens.md" -ForegroundColor Green
Write-Host "Visual PDF:  .\scripts\open-design-pdf.ps1" -ForegroundColor Cyan
