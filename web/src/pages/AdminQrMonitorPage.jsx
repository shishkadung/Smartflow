import { useEffect, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { DocTable, LifeEmpty, Overview, Segmented, StatusPill } from '../components/ui.jsx'

const ACTIVITY_LABELS = {
  'signup.approve': 'Sign-up approved',
  'signup.reject': 'Sign-up rejected',
  'user.deactivate': 'User deactivated',
  'user.reactivate': 'User reactivated',
  'user.profile_update': 'Profile updated',
  'user.password_change': 'Password changed',
  'user.password_reset': 'Password reset',
  'threshold.update': 'Threshold changed',
  'request.approve': 'Request accepted',
  'request.reject': 'Request declined',
  'request.fulfill': 'Request fulfilled',
  'request.cancel': 'Request cancelled',
}

export default function AdminQrMonitorPage() {
  const [rows, setRows] = useState([])
  const [exceptions, setExceptions] = useState([])
  const [activity, setActivity] = useState([])
  const [outcome, setOutcome] = useState('all')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    setError('')
    try {
      const [scans, ex, act] = await Promise.all([
        smartflow.auditScans({ hours: 48, outcome, limit: 200 }),
        smartflow.auditExceptions(48),
        smartflow.auditActivity({ hours: 168, limit: 100 }),
      ])
      setRows(scans.events || scans.scans || scans.logs || [])
      setExceptions(ex.exceptions || ex.items || [])
      setActivity(act.events || [])
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not load QR monitor')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [outcome])

  return (
    <div className="sf-life">
      <Overview
        title="QR scan monitor"
        body="Accepted and rejected scan events from the last 48 hours."
      />
      {error ? <div className="error">{error}</div> : null}
      <div className="toolbar">
        <Segmented
          value={outcome}
          onChange={setOutcome}
          options={[
            { value: 'all', label: 'All' },
            { value: 'success', label: 'Accepted' },
            { value: 'rejected', label: 'Rejected' },
          ]}
        />
      </div>
      <div className="admin-grid">
        <div className="card sf-life__panel">
          <h3 className="section-title">Custody exceptions</h3>
          {exceptions.length === 0 && !loading ? (
            <LifeEmpty icon="coaSupport" tone="ok">No exceptions in the last 48h.</LifeEmpty>
          ) : null}
          {exceptions.map((ex, i) => (
            <div key={ex.document_id || i} className="pending-card">
              <strong>{ex.document_id || ex.title || 'Exception'}</strong>
              <span className="muted">{ex.detail || ex.message || ex.kind}</span>
            </div>
          ))}
        </div>
        <div className="card sf-life__panel">
          <h3 className="section-title">Scan events</h3>
          {loading ? <p className="muted">Loading…</p> : null}
          {!loading && rows.length === 0 ? (
            <LifeEmpty icon="qrMonitor">No scan events.</LifeEmpty>
          ) : (
            <DocTable
              columns={[
                { key: 'created_at', label: 'When', render: (r) => r.created_at || r.scanned_at || '—' },
                { key: 'document_id', label: 'Doc' },
                {
                  key: 'outcome',
                  label: 'Outcome',
                  render: (r) => (
                    <StatusPill tone={String(r.outcome || '').includes('reject') ? 'bad' : 'ok'}>
                      {r.outcome || '—'}
                    </StatusPill>
                  ),
                },
                { key: 'message', label: 'Detail', render: (r) => r.message || r.reason || r.event_type },
              ]}
              rows={rows}
            />
          )}
        </div>
        <div className="card sf-life__panel">
          <h3 className="section-title">Admin &amp; account activity · last 7 days</h3>
          {!loading && activity.length === 0 ? (
            <LifeEmpty icon="coaSupport" tone="ok">No admin or account actions in the last 7 days.</LifeEmpty>
          ) : (
            <DocTable
              columns={[
                { key: 'created_at', label: 'When' },
                {
                  key: 'username',
                  label: 'Who',
                  render: (r) => [r.username, r.office_code].filter(Boolean).join(' · ') || '—',
                },
                {
                  key: 'event_type',
                  label: 'Action',
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
