# Package mockups for html.to.design — role bundles (Accounting / Employee) + legacy all-in-one path
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'package-figma-html-bundles.ps1')
Write-Host ""
Write-Host "Legacy path (symlink): mockups\SmartFlow-figma-import.zip -> bundles\SmartFlow-all-screens.zip"
$legacy = Join-Path (Split-Path $PSScriptRoot -Parent) 'mockups\SmartFlow-figma-import.zip'
$all = Join-Path (Split-Path $PSScriptRoot -Parent) 'mockups\bundles\SmartFlow-all-screens.zip'
if (Test-Path $all) { Copy-Item $all $legacy -Force }
