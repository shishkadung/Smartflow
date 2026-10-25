# Safe invalid-input checks: each case must stop before SDK/build/network discovery.
$ErrorActionPreference = 'Stop'
$releaseConfigChecks = 0
$releaseCases = @(
    @{ Arguments = @{}; Message = 'Release builds require -ApiBase' },
    @{ Arguments = @{ ApiBase = 'http://release.example.test/api' }; Message = 'Release builds require an HTTPS' },
    @{ Arguments = @{ ApiBase = 'https://synthetic@release.example.test/api' }; Message = 'Pass a plain HTTP' },
    @{ Arguments = @{ ApiBase = 'https://release.example.test/api?mode=test' }; Message = 'Pass a plain HTTP' },
    @{ Arguments = @{ ApiBase = 'https://release.example.test/api#fragment' }; Message = 'Pass a plain HTTP' }
)
foreach ($releaseCase in $releaseCases) {
    $releaseArgs = $releaseCase.Arguments
    $releaseRejected = $false
    try { & (Join-Path $PSScriptRoot 'build-phone.ps1') -Mode release @releaseArgs | Out-Null }
    catch { $releaseRejected = $_.Exception.Message.Contains($releaseCase.Message) }
    if (!$releaseRejected) { throw 'Release configuration did not reject the expected unsafe input' }
    $releaseConfigChecks++
    Write-Output "PASS release input rejected before build: $($releaseCase.Message)"
}
Write-Output "Phone release configuration checks passed: $releaseConfigChecks"
