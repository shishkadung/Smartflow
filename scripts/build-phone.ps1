# Builds an Android debug APK for this PC's LAN API, retaining the default APK.
param([string]$ApiBase, [string]$FlutterSdk = 'C:\src\flutter', [ValidateSet('debug','release')][string]$Mode = 'debug', [switch]$AnalyzeSize)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$flutterRoot = Join-Path $projectRoot 'mobile/flutter'
if (!$ApiBase) {
    $route = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric | Select-Object -First 1
    $address = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex | Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -notlike '127.*' } | Select-Object -First 1
    if (!$address) { throw 'Pass -ApiBase with an API address reachable by your phone' }
    $ApiBase = 'http://' + $address.IPAddress + '/Smartflow/backend/backend/api'
}
$parsed = [Uri]$ApiBase
if (!$parsed.IsAbsoluteUri -or $parsed.Scheme -notin @('http','https') -or $parsed.UserInfo -or $parsed.Query -or $parsed.Fragment) { throw 'Pass a plain HTTP(S) API base address' }
$ApiBase = $ApiBase.TrimEnd('/')
$dart = Join-Path $FlutterSdk 'bin/cache/dart-sdk/bin/dart.exe'
$flutterTool = Join-Path $FlutterSdk 'bin/cache/flutter_tools.snapshot'
$output = Join-Path $flutterRoot 'build/app/outputs/flutter-apk'
$defaultApk = Join-Path $output "app-$Mode.apk"
$savedDefault = Join-Path $output ('.phone-build-default-' + [Guid]::NewGuid().ToString('N') + '.apk')
if (Test-Path -LiteralPath $defaultApk) { Copy-Item -LiteralPath $defaultApk -Destination $savedDefault }
Push-Location $flutterRoot
try {
    $buildArgs = @($flutterTool, 'build', 'apk', "--$Mode", '--no-pub', "--dart-define=API_BASE=$ApiBase", '--dart-define=FORCE_LOGIN_ON_START=false')
    if ($AnalyzeSize) {
        if ($Mode -ne 'release') { throw 'Size analysis requires release mode' }
        $buildArgs += @('--analyze-size', '--target-platform=android-arm64')
    }
    & $dart @buildArgs
    if ($LASTEXITCODE -ne 0) { throw 'Phone APK build failed' }
    $name = if ($AnalyzeSize) { 'app-phone-arm64-release' } else { "app-phone-$Mode" }
    Copy-Item -LiteralPath $defaultApk -Destination (Join-Path $output "$name.apk") -Force
    [IO.File]::WriteAllText((Join-Path $output "$name-api.txt"), $ApiBase, [Text.UTF8Encoding]::new($false))
    Write-Output "Phone APK: mobile/flutter/build/app/outputs/flutter-apk/$name.apk"
    Write-Output "Phone API: $ApiBase"
    Write-Output 'Use the same Wi-Fi as this PC. Rebuild if the PC address changes.'
} finally {
    Pop-Location
    if (Test-Path -LiteralPath $savedDefault) { Move-Item -LiteralPath $savedDefault -Destination $defaultApk -Force }
}
