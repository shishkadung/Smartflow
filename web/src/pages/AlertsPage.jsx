import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, LifeSkeleton, Overview, Segmented, StatusPill } from '../components/ui.jsx'

function hoursLabel(alert) {
  const hours = Number(alert.hours_pending || 0)
  const days = Number(alert.days_pending || 0)
  if (days > 0) return `${days} day${days === 1 ? '' : 's'} at this desk`
  if (hours > 0) return `${hours} hour${hours === 1 ? '' : 's'} at this desk`
  return 'Just recorded'
}

export default function AlertsPage() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [alerts, setAlerts] = useState([])
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('all')

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    const req = user.role === 'admin'
      ? smartflow.accountantAlerts()
      : smartflow.alerts(user.office_id)
    req
      .then((d) => {
        if (!cancelled) setAlerts(d.alerts || [])
      })
      .catch((e) => {
        if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load alerts')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [user])

  const counts = useMemo(() => ({
    delayed: alerts.filter((a) => a.kind === 'delayed').length,
    due_soon: alerts.filter((a) => a.kind === 'due_soon').length,
    unconfirmed: alerts.filter((a) => a.kind === 'unconfirmed').length,
  }), [alerts])

  const visible = useMemo(() => {
    const rank = { delayed: 0, due_soon: 1, unconfirmed: 2 }
    const list = alerts.filter((a) => filter === 'all' || a.kind === filter)
    return [...list].sort((a, b) => (rank[a.kind] ?? 3) - (rank[b.kind] ?? 3))
  }, [alerts, filter])

  return (
    <div className="sf-life">
      <Overview
        title="Alerts"
        body={
          user.role === 'admin'
            ? 'Delays and unconfirmed handoffs across municipal offices.'
            : `Overdue folders, or OUT from ${user.office_code} with no receive yet.`
        }
      />
      {error ? <div className="error">{error}</div> : null}
      <div className="toolbar">
        <Segmented
          value={filter}
          onChange={setFilter}
          options={[
            { value: 'all', label: 'All', badge: alerts.length || undefined },
            { value: 'delayed', label: 'Overdue', badge: counts.delayed || undefined },
            { value: 'due_soon', label: 'Due soon', badge: counts.due_soon || undefined },
            { value: 'unconfirmed', label: 'No IN scan', badge: counts.unconfirmed || undefined },
          ]}
        />
      </div>
      <div className="card sf-life__panel">
        {loading ? (
          <LifeSkeleton rows={3} label="Loading alerts" />
        ) : alerts.length === 0 ? (
          <LifeEmpty icon="alerts" tone="ok">No alerts right now.</LifeEmpty>
        ) : visible.length === 0 ? (
          <LifeEmpty
            icon="alerts"
            action={(
              <button type="button" className="btn-secondary" onClick={() => setFilter('all')}>
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
              const pill = kind === 'unconfirmed' ? 'Awaiting receive' : kind === 'delayed' ? 'Overdue' : 'Due soon'
              return (
                <button
                  key={`${id}-${kind}`}
                  type="button"
                  className="alert-log__row"
                  onClick={() => navigate(`/history?id=${encodeURIComponent(id)}`)}
                >
                  <div className="alert-log__main">
                    <strong>{id}</strong>
                    <span>{a.document_title || a.title || 'Folder'}</span>
                    <span className="muted">{office} · {hoursLabel(a)}</span>
                  </div>
                  <StatusPill tone={tone}>{pill}</StatusPill>
                </button>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
