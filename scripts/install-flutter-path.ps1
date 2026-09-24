# Add Flutter to user PATH permanently (run once)
$flutterBin = "C:\src\flutter\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$flutterBin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterBin", "User")
    Write-Host "Added $flutterBin to user PATH. Restart terminal or Cursor."
} else {
    Write-Host "Flutter already on PATH."
}
