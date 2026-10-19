# Restores a system snapshot into an owned temporary DB, verifies it, and removes it.
param([Parameter(Mandatory=$true)][string]$Snapshot, [string]$Php = 'C:\xampp\php\php.exe', [string]$BackupRoot)
$ErrorActionPreference = 'Stop'
if (!$BackupRoot) { $BackupRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'backups' }
& $Php (Join-Path $PSScriptRoot 'backup-system.php') verify $Snapshot $BackupRoot
if ($LASTEXITCODE -ne 0) { throw 'Isolated system restore verification failed' }
