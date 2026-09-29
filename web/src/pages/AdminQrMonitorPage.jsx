import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { formatWhen } from '../tracking.js'
import { DocTable, ExceptionCard, LifeEmpty, LifeSkeleton, Overview, Segmented, StatusPill } from '../components/ui.jsx'

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
      <div className="admin-grid admin-grid--stack">
        <div className="card sf-life__panel">
          <h3 className="section-title">Custody exceptions</h3>
          {loading && exceptions.length === 0 ? <LifeSkeleton rows={2} label="Loading exceptions" /> : null}
          {!loading && exceptions.length === 0 ? (
            <LifeEmpty icon="coaSupport" tone="ok">No exceptions in the last 48h.</LifeEmpty>
          ) : null}
          {exceptions.length > 0 ? (
            <div className="exception-grid">
              {exceptions.map((ex, i) => (
                <ExceptionCard key={`${ex.document_id}-${ex.exception_type}-${i}`} exception={ex} />
              ))}
            </div>
          ) : null}
        </div>
        <div className="card sf-life__panel">
          <h3 className="section-title">Scan events</h3>
          {loading && rows.length === 0 ? (
            <LifeSkeleton rows={4} label="Loading scan events" />
          ) : rows.length === 0 ? (
            <LifeEmpty icon="qrMonitor">No scan events.</LifeEmpty>
          ) : (
            <DocTable
              scroll
              onRowClick={(r) => r.document_id && navigate(`/history?id=${encodeURIComponent(r.document_id)}`)}
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
          ) : activity.length === 0 ? (
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
