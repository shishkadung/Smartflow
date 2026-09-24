# SmartFlow Database Restore Script
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
    Write-Host "Available backups in $BackupDir:" -ForegroundColor Yellow
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
    "--user=$DbUser"
)

if ($DbPass -ne "") {
    $Arguments += "--password=$DbPass"
}

$Arguments += $DbName

try {
    Write-Host "Restoring database..." -ForegroundColor Yellow
    
    # Run mysql restore
    Get-Content $BackupFile | & $MysqlBin $Arguments
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Restore completed successfully!" -ForegroundColor Green
        Write-Host "Database $DbName has been restored from backup." -ForegroundColor Green
    } else {
        Write-Host "Restore failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Restore failed: $_" -ForegroundColor Red
    exit 1
}
