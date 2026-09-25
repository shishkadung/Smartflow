import { Link } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { LifeEmpty, Overview, StatusPill, statTone } from '../components/ui.jsx'

export default function AdminHomePage() {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    smartflow.accountantDashboard()
      .then((dash) => {
        if (!cancelled) setData(dash)
      })
      .catch((e) => {
        if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load municipal dashboard')
      })
    return () => { cancelled = true }
  }, [])

  const stats = data?.stats || {}
  const offices = data?.office_totals || []
  const pending = stats.pending_signups ?? 0
  const officeCount = stats.pilot_offices ?? offices.length
  const month = data?.month

  return (
    <div className="sf-life">
      <Overview
        title="Municipal dashboard"
        body="Active custody across municipal offices."
      />
      {pending > 0 ? (
        <Link className="stat admin-tile admin-tile--alert" to="/admin/users" style={{ display: 'block', textDecoration: 'none' }}>
          <b>Review sign-up requests</b>
          <span>{pending} pending approval</span>
        </Link>
      ) : null}
      {error ? <div className="error">{error}</div> : null}

      {month ? (
        <p className="muted admin-home__meta">
          {month} · {officeCount} office{officeCount === 1 ? '' : 's'}
        </p>
      ) : null}

      <div className="stats sf-life__stats">
        <Link className={statTone(stats.active_documents, 'stat--desk')} to="/admin/offices" style={{ textDecoration: 'none' }}>
          <b>{stats.active_documents ?? '—'}</b>
          <span>Active</span>
        </Link>
        <Link className={statTone(stats.overdue, 'stat--overdue')} to="/admin/offices" style={{ textDecoration: 'none' }}>
          <b>{stats.overdue ?? '—'}</b>
          <span>Overdue</span>
        </Link>
        <Link className={statTone(pending, 'stat--pending')} to="/admin/users" style={{ textDecoration: 'none' }}>
          <b>{pending || '—'}</b>
          <span>Sign-ups</span>
        </Link>
      </div>

      <div className="card sf-life__panel">
        <div className="admin-home__section-head">
          <h3 className="section-title">By office</h3>
          <Link className="linkish" to="/admin/offices">All offices</Link>
        </div>
        {offices.length === 0 ? (
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
                  to="/admin/offices"
                  className={`admin-office-tile office-accent--${code.toLowerCase() || 'eng'}`}
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
    </div>
  )
}
