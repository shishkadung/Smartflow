# SmartFlow Database Restore Script
# Live SQL restore. For isolated verification, use verify-system-backup.ps1 instead.
# Usage: .\scripts\restore-database.ps1 -BackupFile "path\to\backup.sql"

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFile
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$BackupDir = Join-Path $ProjectRoot "backups"

# Check if backup file exists
if (-not (Test-Path $BackupFile)) {
    Write-Host "Error: Backup file not found: $BackupFile" -ForegroundColor Red
    Write-Host "Available backups in ${BackupDir}:" -ForegroundColor Yellow
    if (Test-Path $BackupDir) {
        Get-ChildItem -Path $BackupDir -Filter "smartflow_backup_*.sql" | Sort-Object LastWriteTime -Descending | ForEach-Object {
            Write-Host "  $($_.Name) - $($_.LastWriteTime)" -ForegroundColor DarkGray
        }
    }
    exit 1
}

# MySQL configuration (update these for your environment)
$MysqlBin = "C:\xampp\mysql\bin\mysql.exe"
$DbHost = "localhost"
$DbName = "smartflow"
$DbUser = "root"
$DbPass = ""

# Check if mysql exists
if (-not (Test-Path $MysqlBin)) {
    Write-Host "Error: mysql not found at $MysqlBin" -ForegroundColor Red
    Write-Host "Please update the MysqlBin path in this script." -ForegroundColor Red
    exit 1
}

Write-Host "=== SmartFlow Database Restore ===" -ForegroundColor Cyan
Write-Host "WARNING: This will replace the current database!" -ForegroundColor Red
Write-Host "Backup file: $BackupFile" -ForegroundColor Yellow
Write-Host "Target database: $DbName" -ForegroundColor Yellow

# Confirm
$Confirm = Read-Host "Type 'YES' to confirm restore"
if ($Confirm -ne "YES") {
    Write-Host "Restore cancelled." -ForegroundColor Yellow
    exit 0
}

# Build mysql command
$Arguments = @(
    "--host=$DbHost",
    "--user=$DbUser",
    "--default-character-set=utf8mb4",
    "--binary-mode"
)

if ($DbPass -ne "") {
    $Arguments += "--password=$DbPass"
}

$Arguments += $DbName

try {
    Write-Host "Restoring database..." -ForegroundColor Yellow
    
    # Send the original SQL bytes. PowerShell 5.1's text pipeline changes Unicode.
    $RestoreStart = New-Object System.Diagnostics.ProcessStartInfo
    $RestoreStart.FileName = $MysqlBin
    $RestoreStart.UseShellExecute = $false
    $RestoreStart.RedirectStandardInput = $true
    # Quote Windows native arguments, including quotes and trailing backslashes.
    $RestoreStart.Arguments = ($Arguments | ForEach-Object {
        '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
    }) -join ' '
    $RestoreProcess = [System.Diagnostics.Process]::Start($RestoreStart)
    try {
        $BackupStream = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $BackupFile).Path)
        try {
            # Out-File -Encoding utf8 in Windows PowerShell adds this preamble.
            $Prefix = New-Object byte[] 3
            $PrefixLength = $BackupStream.Read($Prefix, 0, 3)
            if ($PrefixLength -ne 3 -or $Prefix[0] -ne 239 -or $Prefix[1] -ne 187 -or $Prefix[2] -ne 191) {
                $BackupStream.Position = 0
            }
            $BackupStream.CopyTo($RestoreProcess.StandardInput.BaseStream)
        }
        finally { $BackupStream.Dispose(); $RestoreProcess.StandardInput.BaseStream.Close() }
        $RestoreProcess.WaitForExit()
        $RestoreExitCode = $RestoreProcess.ExitCode
    } finally { $RestoreProcess.Dispose() }

    if ($RestoreExitCode -eq 0) {
        Write-Host "Restore completed successfully!" -ForegroundColor Green
        Write-Host "Database $DbName has been restored from backup." -ForegroundColor Green
    } else {
        Write-Host "Restore failed with exit code: $RestoreExitCode" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Restore failed: $_" -ForegroundColor Red
    exit 1
}
