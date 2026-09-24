# SmartFlow Database Backup Script
# Usage: .\scripts\backup-database.ps1

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$BackupDir = Join-Path $ProjectRoot "backups"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupFile = Join-Path $BackupDir "smartflow_backup_$Timestamp.sql"

# Create backups directory if it doesn't exist
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-Host "Created backup directory: $BackupDir" -ForegroundColor Green
}

# MySQL configuration (update these for your environment)
$MysqlBin = "C:\xampp\mysql\bin\mysqldump.exe"
$DbHost = "localhost"
$DbName = "smartflow"
$DbUser = "root"
$DbPass = ""

# Check if mysqldump exists
if (-not (Test-Path $MysqlBin)) {
    Write-Host "Error: mysqldump not found at $MysqlBin" -ForegroundColor Red
    Write-Host "Please update the MysqlBin path in this script." -ForegroundColor Red
    exit 1
}

Write-Host "=== SmartFlow Database Backup ===" -ForegroundColor Cyan
Write-Host "Backing up database: $DbName" -ForegroundColor Yellow
Write-Host "Output file: $BackupFile" -ForegroundColor Yellow

# Build mysqldump command
$Arguments = @(
    "--host=$DbHost",
    "--user=$DbUser"
)

if ($DbPass -ne "") {
    $Arguments += "--password=$DbPass"
}

$Arguments += @(
    "--single-transaction",
    "--routines",
    "--triggers",
    "--add-drop-table",
    $DbName
)

try {
    # Run mysqldump
    & $MysqlBin $Arguments | Out-File -FilePath $BackupFile -Encoding utf8
    
    if ($LASTEXITCODE -eq 0) {
        $FileSize = (Get-Item $BackupFile).Length / 1KB
        Write-Host "Backup completed successfully!" -ForegroundColor Green
        Write-Host "File size: $([math]::Round($FileSize, 2)) KB" -ForegroundColor Green
        Write-Host "Location: $BackupFile" -ForegroundColor Green
        
        # Keep only last 10 backups
        $Backups = Get-ChildItem -Path $BackupDir -Filter "smartflow_backup_*.sql" | Sort-Object LastWriteTime -Descending
        if ($Backups.Count -gt 10) {
            $ToDelete = $Backups | Select-Object -Skip 10
            foreach ($File in $ToDelete) {
                Remove-Item $File.FullName -Force
                Write-Host "Deleted old backup: $($File.Name)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "Backup failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Backup failed: $_" -ForegroundColor Red
    exit 1
}
