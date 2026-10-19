import { useAuth } from '../auth.jsx'
import { useLiveRefresh } from '../live-refresh.js'
import { Link } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { ApiError } from '../api.js'
import { LifeEmpty, LifeSkeleton, Overview, StatusPill } from '../components/ui.jsx'
import { HomeMetrics, HomeTaskLinks } from '../components/HomeWorkspace.jsx'

export default function AdminHomePage() {
  const { smartflow } = useAuth()
  const revision = useLiveRefresh()
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [retry, setRetry] = useState(0)

  useEffect(() => {
    let cancelled = false
    // oxlint-disable-next-line react/set-state-in-effect -- Track refreshes while keeping the last successful dashboard visible.
    setLoading(true)
    smartflow.accountantDashboard()
      .then((dash) => {
        if (!cancelled) { setData(dash); setError('') }
      })
      .catch((e) => {
        if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load municipal dashboard')
      })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [revision, retry, smartflow])

  return <AdminDashboardContent data={data} error={error} loading={loading} onRetry={() => setRetry((value) => value + 1)} />
}

export function AdminDashboardContent({ data, error, loading, onRetry }) {
  const stats = data?.stats || {}
  const offices = data?.office_totals || []
  const pending = stats.pending_signups ?? 0
  const officeCount = stats.pilot_offices ?? offices.length
  const month = data?.month
  const [monthYear, monthNumber] = String(month || '').split('-').map(Number)
  const monthLabel = monthYear && monthNumber
    ? new Date(monthYear, monthNumber - 1, 1).toLocaleString('en-US', { month: 'long', year: 'numeric' })
    : month

  return (
    <div className="sf-life home-dashboard">
      <Overview
        title="Dashboard"
      />
      {pending > 0 ? (
        <Link className="stat admin-tile admin-tile--alert" to="/admin/users" style={{ display: 'block', textDecoration: 'none' }}>
          <b>Review sign-up requests</b>
          <span>{pending} pending approval</span>
        </Link>
      ) : null}
      {error ? <div className="error" role="alert">
        <strong>{data ? 'Refresh failed' : 'Dashboard unavailable'}</strong>
        <p>{error}</p>
        {data ? <p>Showing previously loaded data; counts may be out of date.</p> : <p>Municipal counts and office activity could not be checked.</p>}
        <button type="button" className="btn-secondary" disabled={loading} onClick={onRetry}>{loading ? 'Retrying…' : 'Try again'}</button>
      </div> : null}

      {month ? (
        <p className="muted admin-home__meta">
          {monthLabel} · {officeCount} office{officeCount === 1 ? '' : 's'}
        </p>
      ) : null}

      {data ? <HomeMetrics items={[
        { label: 'Active', value: stats.active_documents, detail: 'Across offices', to: '/documents?tray=in_office' },
        { label: 'Overdue', value: stats.overdue, detail: 'Needs follow-up', to: '/documents?overdue=1', alert: true },
        { label: 'Sign-ups', value: data ? pending : null, detail: 'Awaiting review', to: '/admin/users' },
      ]} /> : null}
      <HomeTaskLinks />

      {loading && !data ? <LifeSkeleton rows={3} label="Loading municipal dashboard" /> : null}
      {data ?
      <div className="card sf-life__panel">
        <div className="admin-home__section-head">
          <h3 className="section-title">By office</h3>
          <Link className="linkish" to="/admin/offices">All offices</Link>
        </div>
        {offices.length === 0 && !error ? (
          <LifeEmpty icon="users" tone="ok">Counts appear after an IN or OUT scan.</LifeEmpty>
        ) : (
          <div className="admin-office-health">
            {offices.map((o) => {
              const overdue = Number(o.overdue || 0)
              const onDesk = Number(o.in_office || 0)
              const processed = Number(o.docs_processed || 0)
              const quiet = overdue === 0 && onDesk === 0 && processed === 0
              const code = String(o.office_code || '').toUpperCase()
              const tone = overdue > 0 ? 'warn' : quiet ? 'neutral' : 'ok'
              const label = overdue > 0 ? 'Follow up' : quiet ? 'No activity' : 'On track'
              return (
                <Link
                  key={o.office_id || code}
                  to={`/documents?office_id=${o.office_id}&${overdue > 0 ? 'overdue=1' : 'tray=in_office'}`}
                  className="admin-office-tile"
                >
                  <div className="admin-office-tile__main">
                    <strong>{o.office_name || code}</strong>
                    <span className="admin-office-tile__code">{code}</span>
                    <span className="muted">{onDesk} on desk · {overdue} overdue</span>
                  </div>
                  <StatusPill tone={tone}>{label}</StatusPill>
                </Link>
              )
            })}
          </div>
        )}
      </div>
      : null}
    </div>
  )
}
