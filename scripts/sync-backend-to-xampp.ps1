# Explicit code-only XAMPP deployment. No mirror/delete, database, login or private-file sync.
[CmdletBinding(SupportsShouldProcess = $true)]
param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
$sfProjectRoot = Split-Path $PSScriptRoot -Parent
$sfSourceApi = (Resolve-Path -LiteralPath (Join-Path $sfProjectRoot 'backend\backend\api')).Path
$sfTargetApi = 'C:\xampp\htdocs\Smartflow\backend\backend\api'
if (-not (Test-Path -LiteralPath $sfTargetApi -PathType Container)) {
    throw "Existing XAMPP API directory not found: $sfTargetApi. Configure a reviewed target separately."
}
$sfTargetApi = (Resolve-Path -LiteralPath $sfTargetApi).Path
if ($sfSourceApi -eq $sfTargetApi -or -not $sfTargetApi.EndsWith('\Smartflow\backend\backend\api', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The source/target API boundary is invalid.'
}
$sfBackup = Join-Path $sfProjectRoot ('.runtime\code-sync-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$sfCodeFiles = @(Get-ChildItem -LiteralPath $sfSourceApi -File | Where-Object {
    $_.Name -match '^[a-z][a-z0-9-]*\.php$' -or $_.Name -in @('.htaccess', 'qr-generator.js', 'qr-label-renderer.js')
} | Sort-Object @{ Expression = {
    switch ($_.Name) { '.htaccess' { 0 } 'dev-block.php' { 1 } 'dev-tools-policy.php' { 2 } 'config.php' { 3 } default { 4 } }
} }, Name)
if ($sfCodeFiles.Count -eq 0) { throw 'No approved top-level API code files found.' }
$sfCopied = 0
foreach ($sfCodeFile in $sfCodeFiles) {
    $sfTargetFile = Join-Path $sfTargetApi $sfCodeFile.Name
    if (Test-Path -LiteralPath $sfTargetFile -PathType Leaf) {
        if ((Get-FileHash -LiteralPath $sfCodeFile.FullName -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $sfTargetFile -Algorithm SHA256).Hash) { continue }
    }
    if ($PSCmdlet.ShouldProcess($sfTargetFile, 'Back up existing file and deploy reviewed API code')) {
        if (-not (Test-Path -LiteralPath $sfBackup -PathType Container)) { New-Item -ItemType Directory -Path $sfBackup -Force | Out-Null }
        if (Test-Path -LiteralPath $sfTargetFile -PathType Leaf) { Copy-Item -LiteralPath $sfTargetFile -Destination (Join-Path $sfBackup $sfCodeFile.Name) }
        Copy-Item -LiteralPath $sfCodeFile.FullName -Destination $sfTargetFile -Force
        if ((Get-FileHash -LiteralPath $sfCodeFile.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $sfTargetFile -Algorithm SHA256).Hash) { throw "Code verification failed: $($sfCodeFile.Name)" }
        $sfCopied++
    }
}
if (-not $Quiet) {
    Write-Host "Deployed $sfCopied approved code files. No private files or target-only files were copied or deleted."
    if ($sfCopied -gt 0) { Write-Host "Previous code backup: $sfBackup" }
}