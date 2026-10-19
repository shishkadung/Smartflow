# Read-only API reachability check. Does not deploy, seed, change accounts or sign in.
param([string]$ApiBase = 'http://localhost/Smartflow/backend/backend/api')
$ErrorActionPreference = 'Stop'
$sfApi = $ApiBase.TrimEnd('/')
try {
    $sfHealth = Invoke-RestMethod -Uri "$sfApi/offices-list.php" -TimeoutSec 20
    if (-not $sfHealth.success) { throw 'The offices endpoint did not return success.' }
    Write-Host 'API reachability check passed.' -ForegroundColor Green
    Write-Host 'Verify your own login in the app. Use scripts/test-request-linking.php for isolated functional checks.'
} catch {
    throw 'API reachability failed. Check the configured URL and Apache/MySQL (or the protected development launcher). This helper does not sync code or replace operational settings.'
}