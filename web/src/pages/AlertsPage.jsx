import { useLiveRefresh } from '../live-refresh.js'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, LifeSkeleton, Overview, Segmented, StatusPill } from '../components/ui.jsx'

function hoursLabel(alert) {
  const hours = Number(alert.hours_pending || 0)
  const days = Number(alert.days_pending || 0)
  const state = alert.last_status === 'OUT' || alert.kind === 'unconfirmed' ? 'since sent; receipt not recorded' : 'at this office'
  if (days > 0) return `${days} day${days === 1 ? '' : 's'} ${state}`
  if (hours > 0) return `${hours} hour${hours === 1 ? '' : 's'} ${state}`
  return 'Just recorded'
}

function alertDetail(alert) {
  if (alert.detail) return String(alert.detail)
    .replace(/Marked OUT/g, 'Sent')
    .replace(/no receive scan/g, 'receipt not recorded')
    .replace(/OUT from/g, 'Sent from')
    .replace(/IN at/g, 'Received at')
  return hoursLabel(alert)
}

export function AlertsContent({ alerts, error, loading, filter, onFilter, onRetry, onOpen }) {
  const list = alerts || []
  const counts = {
    delayed: list.filter((a) => a.kind === 'delayed').length,
    due_soon: list.filter((a) => a.kind === 'due_soon').length,
    unconfirmed: list.filter((a) => a.kind === 'unconfirmed').length,
  }

  const rank = { delayed: 0, due_soon: 1, unconfirmed: 2 }
  const visible = list.filter((a) => filter === 'all' || a.kind === filter)
    .sort((a, b) => (rank[a.kind] ?? 3) - (rank[b.kind] ?? 3))

  return (
    <div className="sf-life alerts-page">
      <Overview
        title="Alerts"
        actions={!error ? <button type="button" className="btn-secondary" disabled={loading} onClick={onRetry}>{loading && alerts ? 'Refreshing…' : 'Refresh alerts'}</button> : null}
      />
      {error ? <div className="error" role="alert"><strong>{alerts ? 'Refresh failed' : 'Alerts unavailable'}</strong><p>{error}</p>{alerts ? <p>Showing previously loaded alerts; they may be out of date.</p> : null}<button type="button" className="btn-secondary" disabled={loading} onClick={onRetry}>{loading ? 'Retrying…' : 'Retry alerts'}</button></div> : null}
      {alerts ? <>
      <div className="toolbar">
        <Segmented
          value={filter}
          onChange={onFilter}
          options={[
            { value: 'all', label: 'All', badge: !error ? list.length : null },
            { value: 'delayed', label: 'Overdue', badge: !error ? counts.delayed : null },
            { value: 'due_soon', label: 'Due soon', badge: !error ? counts.due_soon : null },
            { value: 'unconfirmed', label: 'Receipt not recorded', badge: !error ? counts.unconfirmed : null },
          ]}
        />
      </div>
      <div className="card sf-life__panel">
        {list.length === 0 && error ? <p className="muted">Current alert status could not be verified.</p> : list.length === 0 ? (
          <LifeEmpty icon="alerts" tone="ok">No alerts right now.</LifeEmpty>
        ) : visible.length === 0 ? (
          <LifeEmpty
            icon="alerts"
            action={(
              <button type="button" className="btn-secondary" onClick={() => onFilter('all')}>
                Show all
              </button>
            )}
          >
            No alerts in this filter.
          </LifeEmpty>
        ) : (
          <div className="alert-log">
            {visible.map((a) => {
              const id = a.document_id || '—'
              const office = a.last_office_name || 'Unknown office'
              const kind = String(a.kind || '')
              const tone = kind === 'delayed' ? 'bad' : kind === 'due_soon' ? 'warn' : 'info'
              const pill = kind === 'unconfirmed' ? 'Receipt not recorded' : kind === 'delayed' ? 'Overdue' : 'Due soon'
              return (
                <button
                  key={`${id}-${kind}`}
                  type="button"
                  className="alert-log__row"
                  onClick={() => onOpen(id)}
                >
                  <div className="alert-log__main">
                    <strong>{id}</strong>
                    <span>{a.document_title || a.title || 'Folder'}</span>
                    <span className="muted">{a.last_status === 'OUT' || kind === 'unconfirmed' ? 'Sent from' : 'Current office:'} {office}</span>
                    <span className="alert-detail">{alertDetail(a)}</span>
                  </div>
                  <StatusPill tone={tone}>{pill}</StatusPill>
                </button>
              )
            })}
          </div>
        )}
      </div>
      </> : loading ? <div className="card sf-life__panel"><LifeSkeleton rows={3} label="Loading alerts" /></div> : null}
    </div>
  )
}

export default function AlertsPage() {
  const revision = useLiveRefresh()
  const { user, smartflow } = useAuth()
  const navigate = useNavigate()
  const [snapshot, setSnapshot] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('all')
  const [retry, setRetry] = useState(0)
  const scope = `${user.role}:${user.office_id}`
  const alerts = snapshot?.scope === scope ? snapshot.alerts : null

  useEffect(() => {
    let cancelled = false
    // oxlint-disable-next-line react/set-state-in-effect -- Mark the current network refresh while retaining the last verified alert snapshot.
    setLoading(true)
    const request = user.role === 'admin' ? smartflow.accountantAlerts() : smartflow.alerts(user.office_id)
    request.then(data => {
      if (!cancelled) { setSnapshot({ scope, alerts: data.alerts || [] }); setError('') }
    }).catch(err => {
      if (!cancelled) setError(err instanceof ApiError ? err.message : 'Could not load alerts')
    }).finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [user.role, user.office_id, scope, revision, retry, smartflow])

  return <AlertsContent user={user} alerts={alerts} error={error} loading={loading} filter={filter} onFilter={setFilter} onRetry={() => setRetry(value => value + 1)} onOpen={id => navigate(`/documents?id=${encodeURIComponent(id)}`)} />
}
