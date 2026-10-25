# End-to-end API smoke test for the SmartFlow workflow rules.
#   - Registration limited to the office that holds the folder (admins included)
#   - Full DV trail ENG -> BUD -> ACC -> TRE -> MAY -> TRE (+ optional ACC), with a return
#   - Return rules (reason required, previous holder only)
#   - Trail completion at Treasury after the Mayor's Office
#   - Skipped-office audit exception (DV sent ENG -> ACC without Budget)
#   - Monthly / quarterly / annual COA summaries and period-filtered exceptions
#   - Admin/account audit trail (request decision, threshold change, admin-only read)
#
# Requires an explicitly isolated API/database with sample accounts already installed.
# Never seed or purge the working database. Test documents are titled
# "SMOKE TEST" and are deleted at the end unless -KeepData is passed.
#
# Usage:
#   .\scripts\smoke-test.ps1
#   .\scripts\smoke-test.ps1 -KeepData
#   .\scripts\smoke-test.ps1 -ApiBase http://localhost/Smartflow/backend/backend/api

param(
    [string]$ApiBase = 'http://localhost/Smartflow/backend/backend/api',
    [string]$Password = 'smartflow123',
    [string]$MysqlExe = 'C:\xampp\mysql\bin\mysql.exe',
    [string]$Database = 'smartflow',
    [switch]$KeepData
)

$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:CreatedDocs = @()
$script:CreatedRequests = @()
$script:AuditIds = @()
$Title = 'SMOKE TEST'

function Invoke-Api([string]$Method, [string]$Path, [string]$Token, $Body) {
    $headers = @{}
    if ($Token) { $headers['Authorization'] = "Bearer $Token" }
    $request = @{
        Method          = $Method
        Uri             = "$ApiBase/$Path"
        Headers         = $headers
        UseBasicParsing = $true
        ContentType     = 'application/json'
    }
    if ($Body) { $request['Body'] = ($Body | ConvertTo-Json -Depth 5) }
    try {
        $response = Invoke-WebRequest @request
        return @{ code = [int]$response.StatusCode; json = ($response.Content | ConvertFrom-Json) }
    } catch {
        $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        $json = $null
        try { $json = $_.ErrorDetails.Message | ConvertFrom-Json } catch {}
        return @{ code = $code; json = $json }
    }
}

function Assert-True([string]$Label, [bool]$Condition, [string]$Detail = '') {
    if ($Condition) {
        Write-Host "[PASS] $Label $Detail" -ForegroundColor Green
    } else {
        $script:Failures++
        Write-Host "[FAIL] $Label $Detail" -ForegroundColor Red
    }
}

$health = Invoke-Api GET 'offices-list.php' $null $null
if ($health.code -ne 200) {
    throw "API not reachable at $ApiBase (HTTP $($health.code)). Start XAMPP and run .\scripts\sync-backend-to-xampp.ps1"
}

$users = @{}
foreach ($name in 'kristofer.eng', 'angel.bud', 'neil.acc.staff', 'krizandra.tre', 'neil.may.staff', 'neil.admin') {
    $login = (Invoke-Api POST 'auth-login.php' $null @{ username = $name; password = $Password }).json
    if (-not $login.token) { throw "Fixture login failed for $name. Use only an isolated test database with sample accounts; do not replace working accounts." }
    $users[$name] = @{ token = $login.token; office = [int]$login.user.office_id }
}
$admin = $users['neil.admin'].token
$offices = @{}
foreach ($o in (Invoke-Api GET 'offices-list.php' $admin $null).json.offices) { $offices[$o.code] = [int]$o.id }

function New-Dv([string]$Who, [string]$Ref) {
    $r = Invoke-Api POST 'documents-create.php' $users[$Who].token @{
        title = $Title; type = 'Disbursement Voucher'; origin_office_id = $users[$Who].office
        reference_no = $Ref; payee = 'Smoke Payee'; fund_source = 'General Fund'
    }
    $id = if ($r.json.document.id) { $r.json.document.id } else { $r.json.id }
    if ($id) { $script:CreatedDocs += $id }
    return @{ code = $r.code; id = $id }
}

function Invoke-Move([string]$Doc, [string]$Who, [string]$Status, [string]$Dest, [hashtable]$Extra) {
    $body = @{ document_id = $Doc; office_id = $users[$Who].office; status = $Status }
    # Capture the reviewed fixture movement once; explicit stale guards in Extra remain testable.
    $body['expected_movement_id'] = if ($Extra -and $Extra.ContainsKey('expected_movement_id')) { $Extra['expected_movement_id'] } else { [int](Get-Doc $Doc).last_movement_id }
    if ($Dest) { $body['destination_office_id'] = $offices[$Dest] }
    if ($Extra) { foreach ($k in $Extra.Keys) { $body[$k] = $Extra[$k] } }
    return Invoke-Api POST 'movements-create.php' $users[$Who].token $body
}

function Get-Doc([string]$Doc) { (Invoke-Api GET "documents-show.php?id=$Doc" $admin $null).json.document }

function Step([string]$Doc, [string]$Who, [string]$Status, [string]$Dest) {
    $r = Invoke-Move $Doc $Who $Status $Dest $null
    $arrow = if ($Dest) { " -> $Dest" } else { '' }
    Assert-True "$Who $Status$arrow" ($r.code -eq 200) $(if ($r.code -ne 200) { "(HTTP $($r.code): $($r.json.message))" } else { '' })
}

try {
    Write-Host "`n== Registration ==" -ForegroundColor Cyan
    $r = Invoke-Api POST 'documents-create.php' $admin @{
        title = $Title; type = 'Disbursement Voucher'; origin_office_id = $offices['ENG']
        reference_no = 'SMOKE-ADMIN'; payee = 'x'; fund_source = 'x'
    }
    Assert-True 'Admin cannot register for another office' ($r.code -eq 403) "(HTTP $($r.code))"
    $dv = New-Dv 'kristofer.eng' 'SMOKE-DV-1'
    Assert-True 'Engineering registers DV' ($dv.code -in 200, 201 -and $dv.id) "($($dv.id))"
    $doc = $dv.id

    Write-Host "`n== Return rules ==" -ForegroundColor Cyan
    Step $doc 'kristofer.eng' 'OUT' 'BUD'
    Step $doc 'angel.bud' 'IN'
    $r = Invoke-Move $doc 'angel.bud' 'OUT' 'ENG' @{ is_return = $true }
    Assert-True 'Return without reason rejected' ($r.code -eq 400) "($($r.json.scan_error))"
    $r = Invoke-Move $doc 'angel.bud' 'OUT' 'TRE' @{ is_return = $true; remarks = 'Missing ObR attachment' }
    Assert-True 'Return to a non-holder rejected' ($r.code -eq 400) "($($r.json.scan_error))"
    $r = Invoke-Move $doc 'angel.bud' 'OUT' 'ENG' @{ is_return = $true; remarks = 'Missing ObR attachment' }
    Assert-True 'Return to previous holder with reason' ($r.code -eq 200 -and $r.json.is_return) "($($r.json.message))"
    $moves = Invoke-Api GET "documents-movements.php?id=$doc" $admin $null
    Assert-True 'Return reason stored in remarks' (($moves.json | ConvertTo-Json -Depth 6) -match 'Returned to') ''

    Write-Host "`n== DV trail ==" -ForegroundColor Cyan
    Step $doc 'kristofer.eng' 'IN'
    Step $doc 'kristofer.eng' 'OUT' 'BUD'
    Step $doc 'angel.bud' 'IN'
    Step $doc 'angel.bud' 'OUT' 'ACC'
    Step $doc 'neil.acc.staff' 'IN'
    Step $doc 'neil.acc.staff' 'OUT' 'TRE'
    Step $doc 'krizandra.tre' 'IN'
    Assert-True 'Not complete at first Treasury stop' (-not (Get-Doc $doc).trail_complete) ''
    Step $doc 'krizandra.tre' 'OUT' 'MAY'
    Step $doc 'neil.may.staff' 'IN'
    Step $doc 'neil.may.staff' 'OUT' 'TRE'
    Step $doc 'krizandra.tre' 'IN'
    $d = Get-Doc $doc
    Assert-True 'Complete at Treasury after Mayor' ($d.trail_complete -eq $true) "(overdue=$($d.is_overdue))"
    Step $doc 'krizandra.tre' 'OUT' 'ACC'
    Assert-True 'In transit to Accounting is not complete' (-not (Get-Doc $doc).trail_complete) ''
    Step $doc 'neil.acc.staff' 'IN'
    Assert-True 'Complete after optional return to Accounting' ((Get-Doc $doc).trail_complete -eq $true) ''

    Write-Host "`n== Skipped-office exception ==" -ForegroundColor Cyan
    $skip = New-Dv 'kristofer.eng' 'SMOKE-DV-SKIP'
    Step $skip.id 'kristofer.eng' 'OUT' 'ACC'
    Step $skip.id 'neil.acc.staff' 'IN'
    $month = Get-Date -Format 'yyyy-MM'
    $ex = Invoke-Api GET "audit-exceptions.php?period=month&month=$month" $admin $null
    $flagged = @($ex.json.exceptions | Where-Object { $_.document_id -eq $skip.id -and $_.exception_type -eq 'skipped_office' })
    Assert-True 'DV that skipped Budget is flagged' ($flagged.Count -eq 1) "($($flagged[0].detail))"
    $clean = @($ex.json.exceptions | Where-Object { $_.document_id -eq $doc -and $_.exception_type -eq 'skipped_office' })
    Assert-True 'Full-route DV is not flagged' ($clean.Count -eq 0) ''
    $old = Invoke-Api GET 'audit-exceptions.php?period=year&year=2020' $admin $null
    $oldHits = @($old.json.exceptions | Where-Object { $_.document_id -eq $skip.id })
    Assert-True 'Exceptions filtered by period' ($old.code -eq 200 -and $oldHits.Count -eq 0) "($($old.json.period_label))"

    Write-Host "`n== COA summaries ==" -ForegroundColor Cyan
    $acc = $offices['ACC']
    $year = Get-Date -Format 'yyyy'
    $quarter = [math]::Ceiling((Get-Date).Month / 3)
    $r = Invoke-Api GET "reports-summary.php?month=$month&office_id=$acc" $admin $null
    Assert-True 'Monthly summary' ($r.code -eq 200) "($($r.json.period_label))"
    $r = Invoke-Api GET "reports-summary.php?period=quarter&year=$year&quarter=$quarter&office_id=$acc" $admin $null
    Assert-True 'Quarterly summary' ($r.code -eq 200 -and $r.json.period_label -eq "Q$quarter $year") "($($r.json.period_label))"
    $r = Invoke-Api GET "reports-summary.php?period=year&year=$year&office_id=$acc" $admin $null
    Assert-True 'Annual summary' ($r.code -eq 200) "($($r.json.period_label))"
    $r = Invoke-Api GET "reports-summary.php?period=quarter&year=$year&quarter=5&office_id=$acc" $admin $null
    Assert-True 'Invalid quarter rejected' ($r.code -eq 400) ''

    Write-Host "`n== Admin & account audit trail ==" -ForegroundColor Cyan
    $tomorrow = (Get-Date).AddDays(1).ToString('yyyy-MM-dd')
    $req = Invoke-Api POST 'document-requests-create.php' $users['kristofer.eng'].token @{
        request_kind = 'access'; document_category = 'budget'; purpose = $Title; required_by = $tomorrow
    }
    $reqId = [int]$req.json.request.id
    if ($reqId) { $script:CreatedRequests += $reqId }
    $r = Invoke-Api POST 'document-requests-update.php' $users['kristofer.eng'].token @{
        request_id = $reqId; action = 'cancel'; review_notes = "$Title cleanup"
    }
    Assert-True 'Requester cancels request' ($r.code -eq 200) "($($r.json.message))"
    $act = Invoke-Api GET 'audit-activity.php?type=request&hours=1' $admin $null
    $hit = @($act.json.events | Where-Object { $_.event_type -eq 'request.cancel' -and $_.meta.request_id -eq $reqId })
    Assert-True 'Request decision is audited' ($hit.Count -eq 1 -and $hit[0].username -eq 'kristofer.eng') "($($hit[0].message))"

    $thr = & $MysqlExe -u root $Database -N -e "SELECT t.max_hours, t.out_unconfirmed_hours FROM processing_thresholds t JOIN offices o ON o.id = t.office_id WHERE o.code = 'ENG' AND t.document_type = 'Disbursement Voucher' AND t.is_active = 1 LIMIT 1"
    if ($thr) {
        $maxH, $outH = ($thr -split "\s+") | Where-Object { $_ } | ForEach-Object { [int]$_ }
        $r = Invoke-Api POST 'admin-thresholds-update.php' $admin @{
            office_id = $offices['ENG']; document_type = 'Disbursement Voucher'; max_hours = $maxH; out_unconfirmed_hours = $outH
        }
        $act = Invoke-Api GET 'audit-activity.php?type=threshold&hours=1' $admin $null
        $hit = @($act.json.events | Where-Object { $_.meta.office_code -eq 'ENG' -and $_.meta.old_max_hours -eq $maxH })
        Assert-True 'Threshold change is audited with old and new values' ($r.code -eq 200 -and $hit.Count -ge 1) "($($hit[0].message))"
        if ($hit.Count -ge 1) { $script:AuditIds += [int]$hit[0].id }
    }

    $r = Invoke-Api GET 'audit-activity.php' $users['kristofer.eng'].token $null
    Assert-True 'Non-admin cannot read admin activity' ($r.code -eq 403) "(HTTP $($r.code))"
} finally {
    if (($script:CreatedRequests.Count -gt 0 -or $script:AuditIds.Count -gt 0) -and -not $KeepData -and (Test-Path $MysqlExe)) {
        $sql = ''
        foreach ($rid in $script:CreatedRequests) {
            $sql += "DELETE FROM audit_logs WHERE event_type LIKE 'request.%' AND JSON_EXTRACT(meta_json, '$.request_id') = $rid; DELETE FROM document_requests WHERE id = $rid AND purpose = '$Title';"
        }
        foreach ($aid in $script:AuditIds) { $sql += "DELETE FROM audit_logs WHERE id = $aid;" }
        & $MysqlExe -u root $Database -e $sql
    }
    if ($script:CreatedDocs.Count -gt 0 -and -not $KeepData) {
        if (Test-Path $MysqlExe) {
            $ids = ($script:CreatedDocs | ForEach-Object { "'$_'" }) -join ','
            & $MysqlExe -u root $Database -e "DELETE FROM movements WHERE document_id IN ($ids); DELETE FROM audit_logs WHERE document_id IN ($ids); DELETE FROM documents WHERE id IN ($ids) AND title = '$Title';"
            Write-Host "`nRemoved test documents: $($script:CreatedDocs -join ', ')" -ForegroundColor DarkGray
        } else {
            Write-Host "`nmysql not found at $MysqlExe - delete test documents titled '$Title' manually." -ForegroundColor Yellow
        }
    }
}

Write-Host ''
if ($script:Failures -gt 0) {
    Write-Host "$($script:Failures) check(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host 'All checks passed.' -ForegroundColor Green
exit 0
