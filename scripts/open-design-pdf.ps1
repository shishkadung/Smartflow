# Open Capstone SmartFlow.pdf in your default PDF viewer (Edge, etc.)
$pdf = Join-Path (Split-Path $PSScriptRoot -Parent) "docs\design\Capstone SmartFlow.pdf"
if (-not (Test-Path $pdf)) {
    Write-Error "Not found: $pdf"
    exit 1
}
Start-Process $pdf
Write-Host "Opened: $pdf"
