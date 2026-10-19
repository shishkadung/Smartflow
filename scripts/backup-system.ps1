# Private database, configuration, QR signing key, and upload snapshot.
param([string]$Php = 'C:\xampp\php\php.exe', [string]$BackupRoot)
$ErrorActionPreference = 'Stop'
if (!$BackupRoot) { $BackupRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'backups' }
if (!(Test-Path -LiteralPath $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot | Out-Null }
# Restrict new private backup files to the current Windows user and SYSTEM.
$ownerSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $backupRoot /inheritance:r /grant:r "*${ownerSid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not protect private backup storage' }
& $Php (Join-Path $PSScriptRoot 'backup-system.php') backup $BackupRoot
if ($LASTEXITCODE -ne 0) { throw 'System backup failed' }
