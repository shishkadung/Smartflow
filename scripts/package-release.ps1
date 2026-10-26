# Builds a deployment package folder from committed source: the web portal build plus the approved API code.
# Nothing is uploaded or installed, no server is contacted, and no private file (.env, .qr-secret, uploads, logs,
# backups) is read or copied. Layout and exclusions follow docs/product/PRODUCTION-DEPLOYMENT.md.
[CmdletBinding()]
param(
    [string]$ApiBase = '/api',
    [string]$Php = 'C:\xampp\php\php.exe',
    [string]$OutputRoot
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputRoot) { $OutputRoot = Join-Path $projectRoot 'release' }
$apiSource = (Resolve-Path -LiteralPath (Join-Path $projectRoot 'backend\backend\api')).Path
$webSource = (Resolve-Path -LiteralPath (Join-Path $projectRoot 'web')).Path
if (-not (Test-Path -LiteralPath $Php -PathType Leaf)) { throw "PHP not found: $Php" }

# The package must match a recorded commit, so uncommitted changes in shipped code stop the build.
$commit = (& git -C $projectRoot rev-parse --short HEAD).Trim()
$uncommitted = @(& git -C $projectRoot status --porcelain -- web backend)
if ($uncommitted.Count -gt 0) { throw "Commit or stash changes in web/ and backend/ first:`n$($uncommitted -join "`n")" }

$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$packageName = "smartflow-$stamp-$commit"
$package = Join-Path $OutputRoot $packageName
if (Test-Path -LiteralPath $package) { throw "Package folder already exists: $package" }
$site = Join-Path $package 'site'
$siteApi = Join-Path $site 'api'

# 1. Web build. VITE_API_BASE is compiled into the JavaScript; a PowerShell environment variable is not rewritten like in Git Bash.
Push-Location $webSource
try {
    $env:VITE_API_BASE = $ApiBase
    & npm run build
    if ($LASTEXITCODE -ne 0) { throw 'The web build failed.' }
} finally {
    Remove-Item Env:VITE_API_BASE -ErrorAction SilentlyContinue
    Pop-Location
}
$dist = Join-Path $webSource 'dist'
$bundles = Get-ChildItem -LiteralPath (Join-Path $dist 'assets') -Filter '*.js' -File
# The minified bundle holds the base as a template literal followed by .replace (see the production guide's check).
if (-not ($bundles | Select-String -SimpleMatch -Pattern ('`' + $ApiBase + '`.replace') -List)) { throw "The bundle does not contain the API base $ApiBase." }
if ($bundles | Select-String -SimpleMatch -Pattern '/smartflow-api' -List) { throw 'The bundle still points at the development proxy path /smartflow-api.' }

# 2. Assemble the site folder: portal at the root, API beside it in api/.
New-Item -ItemType Directory -Path $siteApi -Force | Out-Null
Copy-Item -Path (Join-Path $dist '*') -Destination $site -Recurse -Force
# Vite's manifest is a build record, not part of the site.
Remove-Item -LiteralPath (Join-Path $site '.vite') -Recurse -Force -ErrorAction SilentlyContinue
if (-not (Test-Path -LiteralPath (Join-Path $site '.htaccess') -PathType Leaf)) { throw 'The portal .htaccess is missing from the build.' }

$apiFiles = Get-ChildItem -LiteralPath $apiSource -File | Where-Object {
    ($_.Name -match '^[a-z][a-z0-9-]*\.php$' -and ($_.Name -notmatch '^dev-' -or $_.Name -eq 'dev-tools-policy.php') -and $_.Name -ne 'users-email-migration.php') -or
    $_.Name -in @('.htaccess', 'qr-generator.js', 'qr-label-renderer.js', '.env.production.example')
}
if (-not ($apiFiles | Where-Object Name -eq 'config.php')) { throw 'config.php is missing from the approved API files.' }
foreach ($file in $apiFiles) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $siteApi $file.Name) }

# 3. Checks that stop the build rather than ship a broken or unsafe package.
$forbidden = Get-ChildItem -LiteralPath $site -Recurse -Force -File | Where-Object {
    $_.Name -in @('.env', '.env.example', '.qr-secret') -or $_.Name -like '*.sql' -or $_.Name -like '*.log' -or
    ($_.Name -match '^dev-' -and $_.Name -ne 'dev-tools-policy.php') -or $_.Name -eq 'users-email-migration.php'
}
if ($forbidden) { throw "Private or maintenance files reached the package: $(($forbidden | ForEach-Object Name) -join ', ')" }
foreach ($runtimeFolder in 'cache', 'logs', 'uploads') {
    if (Test-Path -LiteralPath (Join-Path $siteApi $runtimeFolder)) { throw "Runtime folder reached the package: $runtimeFolder" }
}
$lintFailures = @()
foreach ($file in Get-ChildItem -LiteralPath $siteApi -Filter '*.php' -File) {
    $result = & $Php -l $file.FullName 2>&1
    if ($LASTEXITCODE -ne 0) { $lintFailures += "$($file.Name): $result" }
}
if ($lintFailures) { throw "PHP syntax errors:`n$($lintFailures -join "`n")" }
$missingIncludes = @()
foreach ($file in Get-ChildItem -LiteralPath $siteApi -Filter '*.php' -File) {
    foreach ($match in [regex]::Matches((Get-Content -LiteralPath $file.FullName -Raw), "(?:require|include)(?:_once)?\s*\(?\s*__DIR__\s*\.\s*['""]/([^'""]+\.php)['""]")) {
        if (-not (Test-Path -LiteralPath (Join-Path $siteApi $match.Groups[1].Value))) { $missingIncludes += "$($file.Name) needs $($match.Groups[1].Value)" }
    }
}
if ($missingIncludes) { throw "Packaged PHP files need files that are not in the package:`n$($missingIncludes -join "`n")" }

# 4. Records: what was built, from which commit, and a checksum for every shipped file.
$siteFiles = Get-ChildItem -LiteralPath $site -Recurse -Force -File | Sort-Object FullName
$sums = $siteFiles | ForEach-Object {
    $relative = $_.FullName.Substring($site.Length + 1).Replace('\', '/')
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower(), $relative
}
Set-Content -LiteralPath (Join-Path $package 'SHA256SUMS.txt') -Value $sums -Encoding UTF8
$info = @(
    "SmartFlow release package $packageName",
    "Built:        $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Commit:       $commit (no uncommitted changes in web/ or backend/)",
    "API base:     $ApiBase (compiled into the portal)",
    "Files:        $($siteFiles.Count) in site/ ($(($siteFiles | Where-Object { $_.FullName.StartsWith($siteApi) }).Count) in site/api/)",
    "Left out:     .env, .env.example, .qr-secret, cache/, logs/, uploads/, dev-*.php (except dev-tools-policy.php), users-email-migration.php, *.sql",
    "Checks:       PHP syntax of every packaged file, every required file present, no private or maintenance files, bundle uses the API base"
)
Set-Content -LiteralPath (Join-Path $package 'BUILD-INFO.txt') -Value $info -Encoding UTF8
$readme = @'
# Deploying this package

This folder is a staging copy. Nothing has been uploaded anywhere. The full procedure and its checks are in
docs/product/PRODUCTION-DEPLOYMENT.md in the project; this page is the short version.

## What is here

- `site/`  upload the CONTENTS of this folder to the web root (https://HOST/). It already holds the portal
  (including the hidden `.htaccess`) and the API in `site/api/`.
- `SHA256SUMS.txt`  checksum of every file in `site/`; verify after upload.
- `BUILD-INFO.txt`  commit, API base and what was left out.

## Before the first upload (new installation only)

1. Confirm the real host name, HTTPS certificate and PHP/MariaDB versions (see the guide, section 1).
2. On the server, copy `api/.env.production.example` to `api/.env` and fill every value. Never copy the development `.env`.
   Production refuses to start (HTTP 500 "Server configuration is incomplete") until CORS lists the exact https origin,
   `LOG_LEVEL` is info/warning/error, `ALLOW_DEV_TOOLS=false` and the database user is not `root` and has a password.
3. Create a dedicated database account for the smartflow database only. The API creates and repairs its own tables on first use.
4. Apache needs mod_rewrite, mod_headers and `AllowOverride All` on the site root and on `api/`.

## Updating an existing installation

Keep the server's `api/.env`, `api/.qr-secret`, `api/uploads/`, `api/logs/` and the database. This package contains none of
them and does not overwrite them. Take a system backup first (`scripts/backup-system.ps1`), then replace only the code files.

## After uploading (no sign-in needed)

```
curl.exe -i https://HOST/documents                 # 200 text/html: the portal
curl.exe -i https://HOST/assets/missing-file.js    # 404, not HTML
curl.exe -i https://HOST/.htaccess                 # 403
curl.exe -i https://HOST/api/auth-session.php      # 401 JSON from the API
```

Then sign in with a real account, open the Requests page and refresh it.

## Not in this package

- The Android app. A release build needs the signing key (`keystore.properties`) and the confirmed HTTPS host:
  `flutter build apk --release --dart-define=ENV=production --dart-define=API_BASE=https://HOST/api --dart-define=FORCE_LOGIN_ON_START=false`
- The database. Do not import old migration files; the API builds its schema at runtime.
'@
Set-Content -LiteralPath (Join-Path $package 'README-DEPLOY.md') -Value $readme -Encoding UTF8

Write-Host "Package ready: $package"
Write-Host "  site files: $($siteFiles.Count); API files: $(@($apiFiles).Count); commit $commit"
Write-Host 'Nothing was uploaded. Review README-DEPLOY.md before using it.'
