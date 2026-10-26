import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth.jsx'
import { beginScopedRead, failScopedRead, scopedReadView } from '../scoped-read.js'
import { ApiError } from '../api.js'
import { formatWhen } from '../tracking.js'
import { DocTable, ExceptionCard, LifeEmpty, LifeSkeleton, Overview, Segmented, StatusPill, statTone } from '../components/ui.jsx'

const ACTIVITY_LABELS = {
  'signup.approve': 'Sign-up approved',
  'signup.reject': 'Sign-up rejected',
  'user.deactivate': 'User deactivated',
  'user.reactivate': 'User reactivated',
  'user.profile_update': 'Profile updated',
  'user.email_update': 'Reset email changed by administrator',
  'user.password_change': 'Password changed',
  'user.password_reset': 'Password reset',
  'threshold.update': 'Threshold changed',
  'request.approve': 'Request accepted',
  'request.reject': 'Request declined',
  'request.fulfill': 'Request fulfilled',
  'request.cancel': 'Request cancelled',
}

/** The time windows offered, as on the phone: 24 hours, 48 hours, 7 days. */
const SCAN_WINDOWS = [
  { value: 24, label: '24h' },
  { value: 48, label: '48h' },
  { value: 168, label: '7 days' },
]

const scanWindowLabel = hours => (hours === 168 ? '7 days' : `${hours} hours`)

const OUTCOMES = {
  success: { label: 'Accepted', tone: 'ok' },
  rejected: { label: 'Rejected', tone: 'bad' },
  failed: { label: 'Failed', tone: 'warn' },
}

function who(r) {
  return [r.username, r.office_code].filter(Boolean).join(' · ') || '—'
}

export default function AdminQrMonitorPage() {
  const navigate = useNavigate()
  const { user, smartflow, apiText } = useAuth()
  const [state, setState] = useState(null)
  const [retry, setRetry] = useState(0)
  const [outcome, setOutcome] = useState('all')
  const [hours, setHours] = useState(48)
  const [exportError, setExportError] = useState('')
  const [exporting, setExporting] = useState(false)
  const key = JSON.stringify([user.id, outcome, hours])
  const canReadExceptions = String(user.office_code || '').toUpperCase() === 'ACC'
  const { data, error, loading } = scopedReadView(state, key)

  async function downloadCsv() {
    if (exporting || loading || !data || error) return
    setExporting(true)
    setExportError('')
    try {
      const csv = await apiText('audit-scans.php', { hours, outcome, format:'csv', limit:500 })
      const url = URL.createObjectURL(new Blob([csv.startsWith('\uFEFF') ? csv : `\uFEFF${csv}`], {type:'text/csv;charset=utf-8'}))
      const link = document.createElement('a')
      link.href = url; link.download = `SmartFlow-scan-audit-${new Date().toISOString().slice(0,10)}.csv`
      link.click(); setTimeout(() => URL.revokeObjectURL(url), 60000)
    } catch (e) { setExportError(e.message) }
    finally { setExporting(false) }
  }

  useEffect(() => {
    let cancelled = false
    // oxlint-disable-next-line react/set-state-in-effect -- Outcome changes invalidate old-filter rows; a same-query refresh can retain marked stale evidence.
    setState(previous => beginScopedRead(previous, key))
    Promise.all([
        smartflow.auditScans({ hours, outcome, limit: 200 }),
        // Exceptions have narrower authority and cannot block the permitted scan/activity reads.
        canReadExceptions ? smartflow.auditExceptions(24)
          .then(result => ({ result }))
          .catch(cause => ({ error: cause.message || 'Could not load custody exceptions.' })) : Promise.resolve(null),
        smartflow.auditActivity({ hours: 168, limit: 100 }),
      ]).then(([scans, ex, act]) => {
        if (!cancelled) setState({ key, data: { rows: scans.events || scans.scans || scans.logs || [], summary: scans.summary || null, suspicious: scans.suspicious || [], topReasons: scans.top_reject_reasons || [], exceptions: ex?.result?.exceptions || ex?.result?.items || [], exceptionError: ex?.error || '', activity: act.events || [] }, error: '', loading: false, updated: new Date() })
      }).catch(e => {
        if (!cancelled) setState(previous => failScopedRead(previous, key, e instanceof ApiError ? e.message : 'Could not load QR monitor'))
      })
    return () => { cancelled = true }
  }, [outcome, hours, key, retry, smartflow, canReadExceptions])

  return <QrMonitorContent data={data} error={error} loading={loading} canReadExceptions={canReadExceptions} exportError={exportError} exporting={exporting} outcome={outcome} onOutcome={setOutcome} hours={hours} onHours={setHours} onRetry={() => setRetry(value => value + 1)} onExport={downloadCsv} onOpen={id => navigate(`/history?id=${encodeURIComponent(id)}`)} />
}

export function QrMonitorContent({ data, error, loading, canReadExceptions = true, exportError, exporting, outcome, onOutcome, hours = 48, onHours = () => {}, onRetry, onExport, onOpen }) {
  const rows = data?.rows || []
  const exceptions = data?.exceptions || []
  const activity = data?.activity || []
  const suspicious = data?.suspicious || []
  const topReasons = data?.topReasons || []
  const summary = data?.summary || null
  const windowLabel = scanWindowLabel(hours)
  const verified = Boolean(data) && !error && !loading
  const exceptionError = data?.exceptionError || ''
  return (
    <div className="sf-life">
      <Overview
        title="QR scan monitor"
        actions={!error ? <button type="button" className="btn-secondary" disabled={loading} onClick={onRetry}>Refresh monitor</button> : null}
      />
      {error ? <div className="error" role="alert"><strong>{data ? 'Monitor refresh failed' : 'QR monitor unavailable'}</strong><p>{error}</p>{data ? <p>Showing previously loaded records; they may be out of date.</p> : null}<button type="button" className="btn-secondary" disabled={loading} onClick={onRetry}>Retry monitor</button></div> : null}
      {exportError ? <div className="error" role="alert">{exportError}</div> : null}
      <div className="toolbar">
        <button type="button" className="btn-ghost" disabled={exporting || !verified} onClick={onExport}>{exporting ? 'Preparing…' : 'Download scan CSV'}</button>
        <Segmented
          value={hours}
          onChange={onHours}
          options={SCAN_WINDOWS}
        />
        <Segmented
          value={outcome}
          onChange={onOutcome}
          options={[
            { value: 'all', label: 'All' },
            { value: 'success', label: 'Accepted' },
            { value: 'rejected', label: 'Rejected' },
          ]}
        />
      </div>
      {summary ? (
        <div className="stats sf-life__stats">
          <div className={statTone(summary.accepted, 'stat--in')}><b>{Number(summary.accepted) || 0}</b><span>Accepted</span></div>
          <div className={statTone(summary.rejected, 'stat--overdue')}><b>{Number(summary.rejected) || 0}</b><span>Rejected</span></div>
        </div>
      ) : null}
      <div className="admin-grid admin-grid--stack">
        <div className="card sf-life__panel">
          <h3 className="section-title">Custody exceptions</h3>
          {!canReadExceptions ? <p className="muted">Custody exceptions are available to Accounting administrators.</p> : <>
          <p className="muted">Missing receipt records after 24 hours, receiver mismatches, route gaps and incomplete DV contents across recorded folder history.</p>
          {loading && exceptions.length === 0 ? <LifeSkeleton rows={2} label="Loading exceptions" /> : null}
          {exceptionError ? <div className="error" role="alert">Custody exceptions unavailable. {exceptionError}<button type="button" className="btn-secondary" disabled={loading} onClick={onRetry}>Retry exceptions</button></div> : null}
          {verified && !exceptionError && exceptions.length === 0 ? (
            <LifeEmpty icon="coaSupport" tone="ok">No custody exceptions found.</LifeEmpty>
          ) : null}
          {!loading && !verified && !exceptionError && exceptions.length === 0 ? <p className="muted">Custody exceptions have not been verified.</p> : null}
          {exceptions.length > 0 ? (
            <div className="exception-grid">
              {exceptions.map((ex, i) => (
                <ExceptionCard key={`${ex.document_id}-${ex.exception_type}-${i}`} exception={ex} />
              ))}
            </div>
          ) : null}
          </>}
        </div>
        <div className="card sf-life__panel">
          <h3 className="section-title">Scan events · last {windowLabel}</h3>
          {suspicious.length > 0 ? (
            <>
              <h4 className="section-title section-title--sub">Needs review</h4>
              <p className="muted">Staff with 3+ rejected scans in this window — training or mis-scans.</p>
              <DocTable
                columns={[
                  { key: 'user_name', label: 'Who', render: (r) => r.user_name || r.username || '—' },
                  { key: 'office_code', label: 'Office', width: '16%', render: (r) => r.office_code || '—' },
                  { key: 'reject_count', label: 'Rejected scans', width: '22%', render: (r) => r.reject_count ?? 0 },
                ]}
                rows={suspicious}
              />
            </>
          ) : null}
          {topReasons.length > 0 ? (
            <>
              <h4 className="section-title section-title--sub">Top reject reasons</h4>
              <div className="chips">
                {topReasons.map((reason, i) => <StatusPill key={`${reason.code}-${i}`} tone="warn">{reason.code} · {reason.count}</StatusPill>)}
              </div>
            </>
          ) : null}
          {loading && rows.length === 0 ? (
            <LifeSkeleton rows={4} label="Loading scan events" />
          ) : rows.length === 0 && !verified ? <p className="muted">Scan events have not been verified.</p> : rows.length === 0 ? (
            <LifeEmpty icon="qrMonitor">No scan events. Try a longer time window to see earlier scans.</LifeEmpty>
          ) : (
            <DocTable
              scroll
              onRowClick={(r) => r.document_id && onOpen(r.document_id)}
              columns={[
                { key: 'created_at', label: 'When', width: '19%', render: (r) => formatWhen(r.created_at || r.scanned_at) || '—' },
                { key: 'document_id', label: 'Doc', width: '17%', render: (r) => r.document_id ? <Link className="linkish nowrap tap-link" to={`/history?id=${encodeURIComponent(r.document_id)}`} aria-label={`View history of ${r.document_id}`} onClick={event => event.stopPropagation()}>{r.document_id}</Link> : '—' },
                { key: 'username', label: 'Who', width: '19%', render: who },
                {
                  key: 'outcome',
                  label: 'Outcome',
                  width: '12%',
                  render: (r) => {
                    const o = OUTCOMES[String(r.outcome || '').toLowerCase()] || { label: r.outcome || '—', tone: 'neutral' }
                    return <StatusPill tone={o.tone}>{o.label}</StatusPill>
                  },
                },
                { key: 'message', label: 'Detail', render: (r) => r.message || r.reason || r.event_type },
              ]}
              rows={rows}
            />
          )}
        </div>
        <div className="card sf-life__panel">
          <h3 className="section-title">Admin &amp; account activity · last 7 days</h3>
          {loading && activity.length === 0 ? (
            <LifeSkeleton rows={3} label="Loading activity" />
          ) : activity.length === 0 && !verified ? <p className="muted">Admin and account activity has not been verified.</p> : activity.length === 0 ? (
            <LifeEmpty icon="coaSupport" tone="ok">No admin or account actions in the last 7 days.</LifeEmpty>
          ) : (
            <DocTable
              scroll
              columns={[
                { key: 'created_at', label: 'When', width: '18%', render: (r) => formatWhen(r.created_at) || '—' },
                { key: 'username', label: 'Who', width: '16%', render: who },
                {
                  key: 'event_type',
                  label: 'Action',
                  width: '18%',
                  render: (r) => ACTIVITY_LABELS[r.event_type] || r.event_type,
                },
                { key: 'message', label: 'Detail' },
              ]}
              rows={activity}
            />
          )}
        </div>
      </div>
    </div>
  )
}
