# Serves the existing local API with private-file protection. Does not sync, seed or reset data.
param(
    [ValidateRange(1024, 65535)][int]$Port = 8000,
    [string]$Php = 'C:\xampp\php\php.exe',
    [switch]$Foreground
)

$ErrorActionPreference = 'Stop'
$sfProject = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$sfRouter = Join-Path $PSScriptRoot 'dev-router.php'
if (-not (Test-Path -LiteralPath $Php -PathType Leaf)) { throw 'PHP executable is missing.' }
if (-not (Test-Path -LiteralPath $sfRouter -PathType Leaf)) { throw 'The protected development router is missing.' }

# Refuse an occupied port; never stop an unrelated server to make room.
$sfProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
try { $sfProbe.Start() } finally { $sfProbe.Stop() }
$sfArguments = @('-S', "127.0.0.1:$Port", '-t', '.', 'scripts/dev-router.php')
if ($Foreground) {
    Push-Location -LiteralPath $sfProject
    try { & $Php @sfArguments; exit $LASTEXITCODE } finally { Pop-Location }
}

$sfRuntime = Join-Path $sfProject '.runtime'
New-Item -ItemType Directory -Path $sfRuntime -Force | Out-Null
$sfProcess = Start-Process -FilePath $Php -ArgumentList $sfArguments -WorkingDirectory $sfProject -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $sfRuntime "api-dev-$Port.stdout.log") -RedirectStandardError (Join-Path $sfRuntime "api-dev-$Port.stderr.log")
$sfManifest = [pscustomobject]@{
    pid = $sfProcess.Id
    base_url = "http://127.0.0.1:$Port/backend/backend/api"
    project = $sfProject
    router = $sfRouter
    started_at = (Get-Date).ToString('o')
}
$sfManifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $sfRuntime "api-dev-$Port.json") -Encoding utf8
Write-Output "Protected local API starting on 127.0.0.1:$Port (PID $($sfProcess.Id))."
