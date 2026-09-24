import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { DocTable, LifeEmpty, LifeSkeleton, Overview } from '../components/ui.jsx'

export default function AlertsPage() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [alerts, setAlerts] = useState([])
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

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

  return (
    <div className="sf-life">
      <Overview
        title="Alerts"
        body={
          user.role === 'admin'
            ? 'Delays and unconfirmed handoffs across pilot offices.'
            : `Overdue IN, or OUT from ${user.office_code} with no receive yet.`
        }
      />
      {error ? <div className="error">{error}</div> : null}
      <div className="card sf-life__panel">
        {loading ? (
          <LifeSkeleton rows={3} label="Loading alerts" />
        ) : alerts.length === 0 ? (
          <LifeEmpty icon="alerts" tone="ok">No alerts right now.</LifeEmpty>
        ) : (
          <DocTable
            columns={[
              { key: 'document_id', label: 'ID' },
              { key: 'title', label: 'Title', render: (a) => a.title || a.document_id },
              { key: 'kind', label: 'Kind' },
              { key: 'detail', label: 'Detail' },
            ]}
            rows={alerts}
            onRowClick={(a) => navigate(`/scan?id=${a.document_id}`)}
          />
        )}
      </div>
    </div>
  )
}
