# Safe launch regressions: HTTP and Flutter are in-memory mocks; no services start.
$ErrorActionPreference = 'Stop'
$sfChecks = 0
function Test-LaunchCheck([bool]$Passed, [string]$Message) {
    if (-not $Passed) { throw $Message }
    $script:sfChecks++
    Write-Output "PASS $Message"
}
foreach ($sfName in @('run-defense-demo.ps1', 'run-flutter.ps1', 'restore-database.ps1', 'fix-api.ps1')) {
    $sfTokens = $null
    $sfErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $sfName), [ref]$sfTokens, [ref]$sfErrors) | Out-Null
    Test-LaunchCheck (@($sfErrors).Count -eq 0) "$sfName parses in PowerShell $($PSVersionTable.PSVersion)"
}

$sfOriginalPath = $env:Path
$sfOriginalLocation = Get-Location
$sfPriorNativeExit = $global:LASTEXITCODE
$global:sfLaunchTestHttpFailure = $false
$global:sfLaunchTestHttpCalls = 0
$global:sfLaunchTestFlutterCalls = New-Object 'System.Collections.Generic.List[string]'
function global:Invoke-RestMethod {
    param([string]$Uri, [int]$TimeoutSec)
    $global:sfLaunchTestHttpCalls++
    if ($global:sfLaunchTestHttpFailure) { throw 'Synthetic HTTP failure' }
    return [pscustomobject]@{ success = $true }
}
function global:flutter {
    $global:sfLaunchTestFlutterCalls.Add(($args -join ' '))
    $global:LASTEXITCODE = 0
}

try {
    foreach ($sfExit in @(0, 23)) {
        $global:LASTEXITCODE = $sfExit
        $sfOutput = & (Join-Path $PSScriptRoot 'run-defense-demo.ps1') 6>&1 | Out-String
        Test-LaunchCheck ($sfOutput.Contains('Cheat sheet:')) "successful reachability continues after prior native exit $sfExit"
    }
    Test-LaunchCheck ($global:sfLaunchTestFlutterCalls.Count -eq 0) 'defense preparation without Launch never invokes Flutter'
    $global:LASTEXITCODE = 23
    & (Join-Path $PSScriptRoot 'run-defense-demo.ps1') -Launch 6>&1 | Out-Null
    Test-LaunchCheck ($global:sfLaunchTestFlutterCalls.Count -eq 2) 'explicit Launch reaches both mocked Flutter commands after prior native failure'
    Test-LaunchCheck ($global:sfLaunchTestFlutterCalls[0] -eq 'pub get' -and $global:sfLaunchTestFlutterCalls[1] -eq 'run') 'defense Launch preserves Flutter command order'

    $global:sfLaunchTestHttpFailure = $true
    $sfFailed = $false
    try { & (Join-Path $PSScriptRoot 'run-defense-demo.ps1') -Launch 6>&1 | Out-Null }
    catch { $sfFailed = $_.Exception.Message.Contains('API reachability failed') }
    Test-LaunchCheck $sfFailed 'failed reachability stops defense preparation with its actual error'
    Test-LaunchCheck ($global:sfLaunchTestFlutterCalls.Count -eq 2) 'failed defense reachability never reaches Flutter'

    $global:sfLaunchTestFlutterCalls.Clear()
    $sfWarnings = & (Join-Path $PSScriptRoot 'run-flutter.ps1') -d synthetic-device 3>&1 | Out-String
    Test-LaunchCheck ($sfWarnings.Contains('Cannot reach localhost API')) 'Flutter helper preserves its explicit unavailable-API warning'
    Test-LaunchCheck ($global:sfLaunchTestFlutterCalls.Count -eq 2 -and $global:sfLaunchTestFlutterCalls[1] -eq 'run -d synthetic-device') 'Flutter helper forwards explicit device arguments to the mocked command'
    Test-LaunchCheck ($global:sfLaunchTestHttpCalls -eq 6) 'all reachability checks used the in-memory HTTP mock'
    Write-Output "Launch helper checks passed: $sfChecks"
} finally {
    $env:Path = $sfOriginalPath
    Set-Location -LiteralPath $sfOriginalLocation.Path
    $global:LASTEXITCODE = $sfPriorNativeExit
    Remove-Item Function:\Invoke-RestMethod, Function:\flutter
    Remove-Variable sfLaunchTestHttpFailure, sfLaunchTestHttpCalls, sfLaunchTestFlutterCalls -Scope Global
}
