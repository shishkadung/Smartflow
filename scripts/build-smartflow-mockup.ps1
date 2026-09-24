# Rebuild SmartFlow_Mockup.html (one HTML, all screens). Edit that file directly day-to-day.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$screenIds = @{
    'splash-get-started.html'  = 'screen-00-welcome'
    'auth-login.html'          = 'screen-01-login'
    'auth-signup-step1.html'   = 'screen-02-signup-step1'
    'auth-signup-step2.html'   = 'screen-03-signup-step2'
    'auth-signup-pending.html' = 'screen-04-signup-pending'
}

function Get-ScreenId {
    param([string]$FilePath)
    $base = Split-Path $FilePath -Leaf
    if ($screenIds.ContainsKey($base)) { return $screenIds[$base] }
    $slug = [IO.Path]::GetFileNameWithoutExtension($base) -replace '[^a-zA-Z0-9]+', '-'
    return "screen-$($slug.ToLower())"
}

function Rewrite-BoardLinks {
    param([string]$Block)
    foreach ($key in $screenIds.Keys) {
        $id = $screenIds[$key]
        $Block = $Block -replace "href=`"\./$([regex]::Escape($key))`"", "href=`"#$id`""
        $Block = $Block -replace "href=`"mockups/screens/$([regex]::Escape($key))`"", "href=`"#$id`""
    }
    $Block
}

function Get-ScreenBlocks {
    param([string]$FilePath)
    if ([string]::IsNullOrWhiteSpace($FilePath) -or -not (Test-Path $FilePath)) { return @() }
    $id = Get-ScreenId -FilePath $FilePath
    $html = [System.IO.File]::ReadAllText($FilePath)
    $html = [regex]::Replace($html, '(?s)<script\b[^>]*>.*?</script>', '')
    $matches = [regex]::Matches($html, '(?s)<div class="screen-wrapper">.*?(?=\s*<div class="screen-wrapper">|\s*</body>)')
    @($matches | ForEach-Object {
        $block = $_.Value.Trim()
        $block = $block -replace '<div class="screen-wrapper">', "<div class=`"screen-wrapper`" id=`"$id`">"
        Rewrite-BoardLinks -Block $block
    })
}

function Join-Blocks {
    param([string[]]$Blocks)
    $flat = @()
    foreach ($b in $Blocks) {
        if ($null -eq $b) { continue }
        if ($b -is [array]) { $flat += $b } else { $flat += @($b) }
    }
    if ($flat.Count -eq 0) { return '' }
    ($flat -join "`n`n        ")
}

$mockups = Join-Path $root 'mockups'
$screensDir = Join-Path $mockups 'screens'
$bundleDir = Join-Path $mockups 'bundles\SmartFlow-all-screens'

function Resolve-ScreenPath {
    param([string]$FileName)
    $primary = Join-Path $screensDir $FileName
    if (Test-Path $primary) { return $primary }
    $bundle = Join-Path $bundleDir $FileName
    if (Test-Path $bundle) { return $bundle }
    return $null
}

$authApprovedBlock = @'
<div class="screen-wrapper" id="screen-05-approved">
          <div class="screen-label"><span class="screen-number">05</span>Approved &middot; Ready to sign in</div>
          <div class="device">
            <div class="device-inner">
              <div class="status-bar"><span>9:41</span><div class="status-icons">5G &#9679;&#9679;&#9679;</div></div>
              <main class="app-shell" style="display:flex;flex-direction:column;justify-content:center;min-height:480px;">
                <div class="hero-card">
                  <div class="hero-tag">Approved by admin</div>
                  <div class="hero-title" style="font-size:17px;">Welcome to SmartFlow</div>
                  <div class="hero-subtitle" style="max-width:none;">Role: Clerk &middot; Office: Engineering (ENG)</div>
                  <div class="status-chip-row" style="margin-top:10px;"><div class="chip chip-green">Approved</div></div>
                </div>
                <a class="btn-primary" href="#screen-01-login" style="display:block;width:100%;text-align:center;text-decoration:none;box-sizing:border-box;">Sign In Now</a>
              </main>
            </div>
          </div>
        </div>
'@

$authBlocks = Join-Blocks @(
    (Get-ScreenBlocks (Resolve-ScreenPath 'splash-get-started.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'auth-login.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'auth-signup-step1.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'auth-signup-step2.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'auth-signup-pending.html')),
    $authApprovedBlock.Trim()
)

$clerk = Join-Blocks @(
    (Get-ScreenBlocks (Resolve-ScreenPath 'clerk-engineering.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'clerk-hr.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'clerk-accounting.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'clerk-scan.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'clerk-register.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'clerk-history.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'clerk-alerts.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'clerk-profile.html'))
)

$head = Join-Blocks @(
    (Get-ScreenBlocks (Resolve-ScreenPath 'head-budget.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'head-requests-bud.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'head-request-create-bud.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'head-register-bud.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'head-queue-bud.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'head-alerts-bud.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'head-analytics-bud.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'head-profile-bud.html'))
)

$accountant = Join-Blocks @(Get-ScreenBlocks (Resolve-ScreenPath '03-municipal-accountant.html'))

$admin = Join-Blocks @(
    (Get-ScreenBlocks (Resolve-ScreenPath 'admin-home.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'admin-users.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'admin-offices.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'admin-thresholds.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'admin-system.html')),
    (Get-ScreenBlocks (Resolve-ScreenPath 'admin-profile.html'))
)

$html = @'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>SmartFlow &mdash; Complete UI Mockup Board</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=Space+Mono:wght@700&display=swap" rel="stylesheet" />
    <link rel="stylesheet" href="mockups/smartflow-mockup.css" />
  </head>
  <body>
    <!-- ONE FILE: edit SmartFlow_Mockup.html only. All screens below. -->
    <nav class="role-nav">
      <a href="#auth">Auth</a>
      <a href="#clerk">Clerk</a>
      <a href="#head">Dept Head</a>
      <a href="#accountant">Accountant</a>
      <a href="#admin">Admin</a>
    </nav>

    <div class="board">
      <h1 class="board-title">
        <span class="seal"><span class="seal-inner">LGU</span></span>
        SmartFlow &middot; Complete Mockup Board
      </h1>
      <p class="board-subtitle">
        Municipality of Urbiztondo &mdash; <strong>isang HTML lang</strong>: <code>SmartFlow_Mockup.html</code>.
        Lahat ng screen nandito; Get Started / Back / Sign up = jump sa page (<code>#screen-00-welcome</code>, etc.).
      </p>
    </div>

    <section id="auth" class="section-block">
      <h2>Shared authentication (6 screens)</h2>
      <p>Welcome, login, sign-up (2 steps), pending approval, and approved state.</p>
      <div class="screen-grid">
__AUTH__
      </div>
    </section>

    <section id="clerk" class="section-block">
      <h2>Clerk / department employee &middot; Mobile</h2>
      <p>ENG, HR, and ACC dashboards &mdash; scan, register, history, alerts, profile.</p>
      <div class="screen-grid">
__CLERK__
      </div>
    </section>

    <section id="head" class="section-block">
      <h2>Department head &middot; Mobile (Budget BUD pilot)</h2>
      <p>Home, requests, register, queue, alerts, analytics, profile.</p>
      <div class="screen-grid" style="align-items:flex-start;">
__HEAD__
      </div>
    </section>

    <section id="accountant" class="section-block">
      <h2>Municipal accountant &middot; Web (4 screens)</h2>
      <p>All pilot offices &mdash; register documents, municipal dashboard, COA reports.</p>
      <div class="screen-grid" style="align-items:flex-start;">
__ACCOUNTANT__
      </div>
    </section>

    <section id="admin" class="section-block">
      <h2>System administrator &middot; Mobile (6 screens)</h2>
      <p>Users, offices, thresholds, system health, profile.</p>
      <div class="screen-grid">
__ADMIN__
      </div>
    </section>

    <div class="board" style="margin-top:16px;margin-bottom:40px;">
      <p class="board-subtitle">
        <strong>One design, one system.</strong> Shared tokens: background <code>#f4f7ff</code>, primary blue, gold accent, Outfit font.
        Clerk scans on mobile; Head monitors one office on web; Accountant spans all offices; Admin configures the system.
      </p>
    </div>

    <script>
      document.querySelectorAll("[data-toggle-password]").forEach(function (btn) {
        btn.addEventListener("click", function () {
          var field = btn.closest(".auth-filled-field");
          var input = field && field.querySelector('input[type="password"], input[type="text"]');
          if (!input) return;
          var show = input.type === "password";
          input.type = show ? "text" : "password";
          btn.setAttribute("aria-label", show ? "Hide password" : "Show password");
        });
      });
    </script>
  </body>
</html>
'@

$html = $html.Replace('__AUTH__', $authBlocks)
$html = $html.Replace('__CLERK__', $clerk)
$html = $html.Replace('__HEAD__', $head)
$html = $html.Replace('__ACCOUNTANT__', $accountant)
$html = $html.Replace('__ADMIN__', $admin)

$outPath = Join-Path $root 'SmartFlow_Mockup.html'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($outPath, $html, $utf8NoBom)
Write-Host "Wrote $outPath ($((Get-Item $outPath).Length) bytes)"
