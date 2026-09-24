# Start Android emulator (after you create an AVD in Android Studio once)
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:Path = "$env:ANDROID_HOME\emulator;$env:ANDROID_HOME\platform-tools;C:\src\flutter\bin;" + $env:Path

$avds = & "$env:ANDROID_HOME\emulator\emulator.exe" -list-avds 2>$null
if (-not $avds -or $avds.Count -eq 0) {
    Write-Host "No emulator found. In Android Studio:" -ForegroundColor Yellow
    Write-Host "  More Actions (3 dots) -> Virtual Device Manager -> Create Device"
    Write-Host "  Pick Pixel 6 -> API 35 -> Finish -> Play button"
    Start-Process "C:\Program Files\Android\Android Studio\bin\studio64.exe"
    exit 1
}

$name = $avds[0]
Write-Host "Starting emulator: $name"
Start-Process -FilePath "$env:ANDROID_HOME\emulator\emulator.exe" -ArgumentList "-avd", $name
Write-Host "Wait until home screen appears, then run:"
Write-Host '  .\scripts\run-flutter.ps1'
