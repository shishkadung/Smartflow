# Synthetic filesystem checks only. Does not access the real XAMPP directory.
$ErrorActionPreference = 'Stop'
$sfFixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('smartflow-code-sync-' + [guid]::NewGuid().ToString('N'))
$sfFixtureRoot = [IO.Path]::GetFullPath($sfFixtureRoot)
$sfChecks = 0
function Assert-SfSync([bool]$Pass, [string]$Message) {
    if (-not $Pass) { throw $Message }
    $script:sfChecks++
    Write-Output "PASS $Message"
}
try {
    $sfProject = Join-Path $sfFixtureRoot 'project'
    $sfSource = Join-Path $sfProject 'backend\backend\api'
    $sfScripts = Join-Path $sfProject 'scripts'
    $sfTarget = Join-Path $sfFixtureRoot 'xampp\htdocs\Smartflow\backend\backend\api'
    foreach ($sfDirectory in @($sfSource, $sfScripts, $sfTarget, (Join-Path $sfSource 'uploads'), (Join-Path $sfTarget 'uploads'))) {
        New-Item -ItemType Directory -Path $sfDirectory -Force | Out-Null
    }
    $sfSyncSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'sync-backend-to-xampp.ps1'))
    $sfSyncSource = $sfSyncSource.Replace("'C:\xampp\htdocs\Smartflow\backend\backend\api'", ("'" + $sfTarget.Replace("'", "''") + "'"))
    $sfSyntheticScript = Join-Path $sfScripts 'sync-backend-to-xampp.ps1'
    [IO.File]::WriteAllText($sfSyntheticScript, $sfSyncSource)
    foreach ($sfName in @('.htaccess', 'dev-block.php', 'dev-tools-policy.php', 'production-config-guard.php', 'config.php', 'sample.php', 'qr-generator.js', 'qr-label-renderer.js')) {
        [IO.File]::WriteAllText((Join-Path $sfSource $sfName), 'SYNTHETIC_NEW_CODE')
        [IO.File]::WriteAllText((Join-Path $sfTarget $sfName), 'SYNTHETIC_OLD_CODE')
    }
    foreach ($sfName in @('.env', '.qr-secret', 'schema.sql', 'backup.log', 'uploads\avatar.png')) {
        [IO.File]::WriteAllText((Join-Path $sfSource $sfName), 'SYNTHETIC_SOURCE_PRIVATE')
        [IO.File]::WriteAllText((Join-Path $sfTarget $sfName), 'SYNTHETIC_TARGET_PRIVATE')
    }
    [IO.File]::WriteAllText((Join-Path $sfTarget 'target-only.php'), 'SYNTHETIC_EXISTING_TARGET')
    & $sfSyntheticScript -Quiet -WhatIf
    Assert-SfSync ([IO.File]::ReadAllText((Join-Path $sfTarget 'sample.php')) -eq 'SYNTHETIC_OLD_CODE') 'WhatIf leaves code unchanged'
    Assert-SfSync (-not (Test-Path -LiteralPath (Join-Path $sfProject '.runtime'))) 'WhatIf creates no backup or other filesystem changes'
    & $sfSyntheticScript -Quiet
    foreach ($sfName in @('.htaccess', 'dev-block.php', 'dev-tools-policy.php', 'production-config-guard.php', 'config.php', 'sample.php', 'qr-generator.js', 'qr-label-renderer.js')) {
        Assert-SfSync ([IO.File]::ReadAllText((Join-Path $sfTarget $sfName)) -eq 'SYNTHETIC_NEW_CODE') "Approved top-level code deployed: $sfName"
    }
    foreach ($sfName in @('.env', '.qr-secret', 'schema.sql', 'backup.log', 'uploads\avatar.png')) {
        Assert-SfSync ([IO.File]::ReadAllText((Join-Path $sfTarget $sfName)) -eq 'SYNTHETIC_TARGET_PRIVATE') "Private or operational file preserved: $sfName"
    }
    Assert-SfSync ([IO.File]::ReadAllText((Join-Path $sfTarget 'target-only.php')) -eq 'SYNTHETIC_EXISTING_TARGET') 'Target-only code is preserved without deletion'
    $sfBackups = @(Get-ChildItem -LiteralPath (Join-Path $sfProject '.runtime\code-sync-backups') -Recurse -File)
    Assert-SfSync ($sfBackups.Count -eq 8 -and @($sfBackups | Where-Object { [IO.File]::ReadAllText($_.FullName) -ne 'SYNTHETIC_OLD_CODE' }).Count -eq 0) 'Every changed existing code file has an unchanged backup'
    foreach ($sfName in @('run-flutter.ps1', 'fix-api.ps1')) {
        $sfContents = [IO.File]::ReadAllText((Join-Path $PSScriptRoot $sfName))
        Assert-SfSync ($sfContents -notmatch 'sync-backend-to-xampp|auth-login\.php|dev-api-health\.php') "Normal helper has no automatic deployment or login: $sfName"
    }
    foreach ($sfName in @('setup-smartflow.ps1', 'purge-demo-data.ps1')) {
        $sfContents = [IO.File]::ReadAllText((Join-Path $PSScriptRoot $sfName))
        Assert-SfSync ($sfContents -match '(?m)^throw ' -and $sfContents -notmatch 'Invoke-RestMethod|Copy-Item|robocopy|sync-backend-to-xampp') "Obsolete destructive helper fails before side effects: $sfName"
    }
    Write-Output "$sfChecks synthetic code-sync/launcher checks passed"
} finally {
    $sfTemporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $sfFixtureRoot.StartsWith($sfTemporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $sfFixtureRoot -Leaf) -notmatch '^smartflow-code-sync-[a-f0-9]{32}$') {
        throw 'Refusing cleanup outside the exact synthetic fixture root.'
    }
    if (Test-Path -LiteralPath $sfFixtureRoot -PathType Container) { Remove-Item -LiteralPath $sfFixtureRoot -Recurse -Force }
}
