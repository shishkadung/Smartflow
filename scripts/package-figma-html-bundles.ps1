# Package SmartFlow mockups into role/office ZIPs for html.to.design (Figma)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$screensDir = Join-Path $root 'mockups\screens'
$cssSrc = Join-Path $root 'mockups\smartflow-mockup.css'
$bundlesDir = Join-Path $root 'mockups\bundles'

$figmaCssAppend = @'

/* html.to.design export — hide mockup chrome */
body.figma-import .screen-label,
body.figma-import .role-nav,
body.figma-import .board {
  display: none !important;
}
body.figma-import .screen-wrapper {
  width: 320px;
}
body.figma-import .device-inner {
  min-height: auto !important;
}
'@

function Write-BundleCss {
    param([string]$DestDir)
    Copy-Item $cssSrc (Join-Path $DestDir 'smartflow-mockup.css') -Force
    Add-Content -Path (Join-Path $DestDir 'smartflow-mockup.css') -Value $figmaCssAppend
}

function Write-BundleScreen {
    param([string]$SourceFile, [string]$DestDir)
    $html = [System.IO.File]::ReadAllText($SourceFile)
    $html = $html -replace '\.\./smartflow-mockup\.css', './smartflow-mockup.css'
    if ($html -match '<body class="single-screen">') {
        $html = $html -replace '<body class="single-screen">', '<body class="single-screen figma-import">'
    } elseif ($html -match '<body(?![^>]*class=)>') {
        $html = $html -replace '<body>', '<body class="figma-import">'
    } elseif ($html -notmatch 'figma-import') {
        $html = $html -replace '<body class="([^"]*)">', '<body class="$1 figma-import">'
    }
    $name = Split-Path $SourceFile -Leaf
    [System.IO.File]::WriteAllText((Join-Path $DestDir $name), $html)
}

function Apply-EmployeePovBranding {
    param([string]$BundleDir)
    # Clerk tabs ship as ACC in mockups/screens; re-label to ENG for the employee bundle.
    $files = @(
        'clerk-scan.html',
        'clerk-register.html',
        'clerk-history.html',
        'clerk-alerts.html',
        'clerk-profile.html',
        'auth-signup-step2.html',
        'auth-signup-pending.html'
    )
    foreach ($name in $files) {
        $path = Join-Path $BundleDir $name
        if (-not (Test-Path $path)) { continue }
        $html = [System.IO.File]::ReadAllText($path)
        $html = $html -replace 'Accounting \(ACC\)', 'Engineering (ENG)'
        $html = $html -replace 'Accounting Office \(ACC\)', 'Engineering Office (ENG)'
        $html = $html -replace 'Accounting clerk \(ACC\)', 'Engineering clerk (ENG)'
        $html = $html -replace 'Accounting Office clerk', 'Engineering Office clerk'
        $html = $html -replace 'ACC &middot; Accounting Office', 'ENG &middot; Engineering Office'
        $html = $html -replace 'when the folder is at Accounting', 'when the folder is at Engineering'
        $html = $html -replace 'for ACC handoffs', 'for ENG handoffs'
        $html = $html -replace 'Maria Santos', 'Rico Mendoza'
        $html = $html -replace 'admin-v2-office">ACC<', 'admin-v2-office eng">ENG<'
        $html = $html -replace 'admin-v2-chip acc"', 'admin-v2-chip eng"'
        $html = $html -replace 'admin-v2-dept-badge acc"', 'admin-v2-dept-badge eng"'
        $html = $html -replace 'admin-v2-dept-badge eng">ACC<', 'admin-v2-dept-badge eng">ENG<'
        $html = $html -replace 'clerk-profile-stat acc"', 'clerk-profile-stat eng"'
        $html = $html -replace '\(ACC\)</div>', '(ENG)</div>'
        $html = $html -replace 'acc\.clerk', 'eng.clerk'
        $html = $html -replace '@acc\.clerk', '@eng.clerk'
        $html = $html -replace '>MS<', '>RM<'
        [System.IO.File]::WriteAllText($path, $html)
    }
}

function Write-EmployeePovIndex {
    param([string]$BundleDir, [string[]]$ScreenFiles)
    $items = foreach ($file in $ScreenFiles) {
        $label = $file -replace '\.html$', '' -replace '-', ' '
        "      <li><a href=`"./$file`">$label</a></li>"
    }
    $list = $items -join "`n"
    $index = @"
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>SmartFlow &mdash; Employee POV</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      body { font-family: system-ui, sans-serif; max-width: 42rem; margin: 2rem auto; padding: 0 1rem; }
      h1 { font-size: 1.25rem; }
      ul { line-height: 1.8; }
      a { color: #1d4ed8; }
      p.note { color: #64748b; font-size: 0.9rem; }
    </style>
  </head>
  <body>
    <h1>SmartFlow &mdash; Employee POV (clerk / staff)</h1>
    <p class="note">Mobile clerk role: scan, register, history, alerts. ENG home + tabs; HR home. Open any screen, or zip this folder for Figma (html.to.design, 390px, Light).</p>
    <ul>
$list
    </ul>
  </body>
</html>
"@
    Set-Content -Path (Join-Path $BundleDir 'index.html') -Value $index -Encoding UTF8
}

function New-SmartFlowBundle {
    param(
        [string]$BundleName,
        [string[]]$ScreenFiles,
        [string]$ReadmeText,
        [scriptblock]$PostProcess
    )
    $outDir = Join-Path $bundlesDir $BundleName
    if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
    New-Item -ItemType Directory -Path $outDir | Out-Null
    Write-BundleCss -DestDir $outDir
    foreach ($file in $ScreenFiles) {
        $src = Join-Path $screensDir $file
        if (-not (Test-Path $src)) {
            Write-Warning "Skip missing: $file"
            continue
        }
        Write-BundleScreen -SourceFile $src -DestDir $outDir
    }
    if ($PostProcess) {
        & $PostProcess $outDir
    }
    if ($ReadmeText) {
        Set-Content -Path (Join-Path $outDir 'README.txt') -Value $ReadmeText
    }
    $zipPath = Join-Path $bundlesDir "$BundleName.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path (Join-Path $outDir '*') -DestinationPath $zipPath -Force
    return $zipPath
}

if (-not (Test-Path $cssSrc)) { throw "Missing $cssSrc" }
if (-not (Test-Path $bundlesDir)) { New-Item -ItemType Directory -Path $bundlesDir | Out-Null }

# Shared clerk tabs (ACC-labelled content in HTML; same layout for all pilot offices)
$clerkTabs = @(
    'clerk-scan.html',
    'clerk-register.html',
    'clerk-history.html',
    'clerk-alerts.html',
    'clerk-profile.html'
)

$authScreens = @(
    'auth-login.html',
    'auth-signup-step1.html',
    'auth-signup-step2.html',
    'auth-signup-pending.html'
)

# Accounting POV: full municipal admin (6) + ACC clerk tabs
$adminScreens = @(
    'admin-home.html',
    'admin-users.html',
    'admin-offices.html',
    'admin-thresholds.html',
    'admin-system.html',
    'admin-profile.html'
)
$accountingScreens = $adminScreens + @('clerk-accounting.html') + $clerkTabs

# Employee POV: ENG + HR clerks + auth (Employee role sign-up)
$employeeScreens = $authScreens + @(
    'clerk-engineering.html',
    'clerk-hr.html'
) + $clerkTabs

$zipAccounting = New-SmartFlowBundle -BundleName 'SmartFlow-accounting-pov' -ScreenFiles $accountingScreens -ReadmeText @"
SmartFlow — Accounting POV (html.to.design)
==========================================
Municipal admin (6 screens) + Accounting Office clerk (home + tabs).

Admin: admin-home, users, offices, thresholds, system, profile.
Clerk ACC: clerk-accounting, scan, register, history, alerts, profile.

Figma: File tab, viewport 390px, theme Light. One ZIP = one free import.
"@

$employeeReadme = @"
SmartFlow — Employee POV (html.to.design)
=========================================
Department clerk / staff (Employee role): auth + ENG mobile tabs + ENG & HR homes.

Screens (12): index.html, auth-login, auth-signup-step1/2/pending,
  clerk-engineering, clerk-hr, clerk-scan, clerk-register, clerk-history,
  clerk-alerts, clerk-profile.

Local preview: open index.html in this folder.
Figma: import SmartFlow-employee-pov.zip via html.to.design — File tab, 390px, Light.
"@

$zipEmployee = New-SmartFlowBundle -BundleName 'SmartFlow-employee-pov' -ScreenFiles $employeeScreens -ReadmeText $employeeReadme -PostProcess {
    param($dir)
    Apply-EmployeePovBranding -BundleDir $dir
    Write-EmployeePovIndex -BundleDir $dir -ScreenFiles $employeeScreens
}

# Optional: keep full bundle (all screens) for one-shot import
$allScreens = Get-ChildItem $screensDir -Filter '*.html' | ForEach-Object { $_.Name }
$zipAll = New-SmartFlowBundle -BundleName 'SmartFlow-all-screens' -ScreenFiles $allScreens -ReadmeText @"
SmartFlow — All mockup screens (21 files). Uses 1 html.to.design import.
"@

Write-Host ""
Write-Host "Bundles written to: $bundlesDir"
Write-Host "  Accounting POV: $zipAccounting"
Write-Host "  Employee POV:   $zipEmployee"
Write-Host "  All screens:    $zipAll"
Write-Host ""
Write-Host "Import in Figma (html.to.design): File -> ZIP, viewport 390px, Light."
