import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../auth.jsx'
import { beginScopedRead, failScopedRead, scopedReadView } from '../scoped-read.js'
import { ApiError } from '../api.js'
import { formatWhen } from '../tracking.js'
import { DocTable, ExceptionCard, LifeEmpty, LifeSkeleton, Overview, Segmented, StatusPill } from '../components/ui.jsx'

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
  const [exportError, setExportError] = useState('')
  const [exporting, setExporting] = useState(false)
  const key = JSON.stringify([user.id, outcome])
  const { data, error, loading } = scopedReadView(state, key)

  async function downloadCsv() {
    if (exporting || loading || !data || error) return
    setExporting(true)
    setExportError('')
    try {
      const csv = await apiText('audit-scans.php', { hours:48, outcome, format:'csv', limit:500 })
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
        smartflow.auditScans({ hours: 48, outcome, limit: 200 }),
        // Same 24h receipt window as Custody reports and the default office receipt limit, so one exception reads the same on both pages.
        smartflow.auditExceptions(24),
        smartflow.auditActivity({ hours: 168, limit: 100 }),
      ]).then(([scans, ex, act]) => {
        if (!cancelled) setState({ key, data: { rows: scans.events || scans.scans || scans.logs || [], exceptions: ex.exceptions || ex.items || [], activity: act.events || [] }, error: '', loading: false, updated: new Date() })
      }).catch(e => {
        if (!cancelled) setState(previous => failScopedRead(previous, key, e instanceof ApiError ? e.message : 'Could not load QR monitor'))
      })
    return () => { cancelled = true }
  }, [outcome, key, retry, smartflow])

  return <QrMonitorContent data={data} error={error} loading={loading} exportError={exportError} exporting={exporting} outcome={outcome} onOutcome={setOutcome} onRetry={() => setRetry(value => value + 1)} onExport={downloadCsv} onOpen={id => navigate(`/history?id=${encodeURIComponent(id)}`)} />
}

export function QrMonitorContent({ data, error, loading, exportError, exporting, outcome, onOutcome, onRetry, onExport, onOpen }) {
  const rows = data?.rows || []
  const exceptions = data?.exceptions || []
  const activity = data?.activity || []
  const verified = Boolean(data) && !error && !loading
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
          value={outcome}
          onChange={onOutcome}
          options={[
            { value: 'all', label: 'All' },
            { value: 'success', label: 'Accepted' },
            { value: 'rejected', label: 'Rejected' },
          ]}
        />
      </div>
      <div className="admin-grid admin-grid--stack">
        <div className="card sf-life__panel">
          <h3 className="section-title">Custody exceptions</h3>
          {loading && exceptions.length === 0 ? <LifeSkeleton rows={2} label="Loading exceptions" /> : null}
          {verified && exceptions.length === 0 ? (
            <LifeEmpty icon="coaSupport" tone="ok">No exceptions in the last 48h.</LifeEmpty>
          ) : null}
          {!loading && !verified && exceptions.length === 0 ? <p className="muted">Custody exceptions have not been verified.</p> : null}
          {exceptions.length > 0 ? (
            <div className="exception-grid">
              {exceptions.map((ex, i) => (
                <ExceptionCard key={`${ex.document_id}-${ex.exception_type}-${i}`} exception={ex} />
              ))}
            </div>
          ) : null}
        </div>
        <div className="card sf-life__panel">
          <h3 className="section-title">Scan events · last 48 hours</h3>
          {loading && rows.length === 0 ? (
            <LifeSkeleton rows={4} label="Loading scan events" />
          ) : rows.length === 0 && !verified ? <p className="muted">Scan events have not been verified.</p> : rows.length === 0 ? (
            <LifeEmpty icon="qrMonitor">No scan events.</LifeEmpty>
          ) : (
            <DocTable
              scroll
              onRowClick={(r) => r.document_id && onOpen(r.document_id)}
              columns={[
                { key: 'created_at', label: 'When', width: '19%', render: (r) => formatWhen(r.created_at || r.scanned_at) || '—' },
                { key: 'document_id', label: 'Doc', width: '17%', render: (r) => <span className="nowrap">{r.document_id || '—'}</span> },
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
