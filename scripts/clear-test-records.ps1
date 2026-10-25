# Clears folder, movement, request and sign-up records so the system can start clean.
# Keeps: users, offices, thresholds, checklists, QR material, active sessions and (by default) the audit log.
#
#   .\scripts\clear-test-records.ps1                  Dry run: only prints what WOULD be deleted. Changes nothing.
#   .\scripts\clear-test-records.ps1 -Execute         Backs up the database, asks you to type a phrase, then deletes.
#   .\scripts\clear-test-records.ps1 -Execute -IncludeAuditLogs   Also clears audit_logs (not recommended).
#
# Run it yourself, deliberately. It refuses to delete anything unless a backup file was just created and verified non-empty.
param(
    [switch]$Execute,
    [switch]$IncludeAuditLogs,
    [string]$DbName = 'smartflow',
    [string]$DbUser = 'root',
    [string]$DbPass = '',
    [string]$MysqlDir = 'C:\xampp\mysql\bin'
)
$ErrorActionPreference = 'Stop'
$mysql = Join-Path $MysqlDir 'mysql.exe'
$dump = Join-Path $MysqlDir 'mysqldump.exe'
foreach ($tool in @($mysql, $dump)) { if (-not (Test-Path $tool)) { throw "Not found: $tool" } }
$auth = @("--user=$DbUser"); if ($DbPass -ne '') { $auth += "--password=$DbPass" }

function Invoke-Sql([string]$sql) { & $mysql @auth --batch --skip-column-names $DbName -e $sql }

# Children first, so no foreign key is ever violated.
$tables = @(
    'movement_destination_corrections',
    'movement_requests',
    'movements',
    'documents',
    'document_requests',
    'creation_requests',
    'password_resets'
)
$signupWhere = "status <> 'pending'"   # a request still waiting for an administrator decision is kept
if ($IncludeAuditLogs) { $tables += 'audit_logs' }

Write-Host "Database: $DbName" -ForegroundColor Cyan
Write-Host 'Rows that would be deleted:' -ForegroundColor Cyan
$total = 0
foreach ($t in $tables) {
    $n = [int](Invoke-Sql "SELECT COUNT(*) FROM ``$t``")
    $total += $n
    '{0,-36} {1,6}' -f $t, $n
}
$n = [int](Invoke-Sql "SELECT COUNT(*) FROM signup_requests WHERE $signupWhere")
$total += $n
'{0,-36} {1,6}  (pending sign-ups are kept)' -f 'signup_requests', $n
Write-Host ''
Write-Host 'Kept untouched: users, offices, processing_thresholds, folder_checklists, qr_tokens, auth_tokens' $(if ($IncludeAuditLogs) { '' } else { ', audit_logs' }) -ForegroundColor Green

if (-not $Execute) {
    Write-Host "`nDRY RUN: nothing was changed. Add -Execute to back up and delete." -ForegroundColor Yellow
    return
}

# 1. Backup first. Abort if it did not produce a real file.
$backupDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$backupFile = Join-Path $backupDir ("before-clear-test-records_{0}.sql" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
& $dump @auth --single-transaction --routines --triggers --result-file=$backupFile $DbName
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $backupFile) -or (Get-Item $backupFile).Length -lt 10KB) {
    throw 'Backup failed or looks empty. Nothing was deleted.'
}
Write-Host "Backup saved: $backupFile ($([math]::Round((Get-Item $backupFile).Length / 1KB)) KB)" -ForegroundColor Green

# 2. Explicit confirmation.
$answer = Read-Host "Type DELETE RECORDS to remove $total rows from '$DbName' (anything else cancels)"
if ($answer -cne 'DELETE RECORDS') { Write-Host 'Cancelled. Nothing was deleted.' -ForegroundColor Yellow; return }

# 3. One transaction: all or nothing.
$statements = @('START TRANSACTION;')
foreach ($t in $tables) { $statements += "DELETE FROM ``$t``;" }
$statements += "DELETE FROM signup_requests WHERE $signupWhere;"
$statements += 'COMMIT;'
& $mysql @auth $DbName -e ($statements -join ' ')
if ($LASTEXITCODE -ne 0) { throw "Delete failed and was rolled back. The backup is at $backupFile" }

Write-Host "`nDone. Rows remaining:" -ForegroundColor Cyan
foreach ($t in $tables) { '{0,-36} {1,6}' -f $t, [int](Invoke-Sql "SELECT COUNT(*) FROM ``$t``") }
Write-Host "To undo, restore $backupFile with scripts\restore-database.ps1." -ForegroundColor Yellow
