import { Link } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { LifeEmpty, Overview, StatusPill } from '../components/ui.jsx'

export default function AdminOfficesPage() {
  const [offices, setOffices] = useState([])
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    smartflow.adminOffices()
      .then((d) => {
        if (!cancelled) setOffices(d.offices || [])
      })
      .catch((e) => {
        if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load offices')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [])

  return (
    <div className="sf-life">
      <Overview
        title="Offices"
        body="Municipal offices in the SmartFlow deployment."
      />
      {error ? <div className="error">{error}</div> : null}
      <Link className="btn btn--navy" to="/admin/thresholds" style={{ alignSelf: 'flex-start' }}>
        Edit processing thresholds
      </Link>
      {loading ? <p className="muted">Loading…</p> : null}
      {!loading && offices.length === 0 ? (
        <LifeEmpty icon="offices" tone="ok">No offices loaded. Check API connection and refresh.</LifeEmpty>
      ) : null}
      <div className="admin-office-list">
        {offices.map((o) => {
          const code = String(o.office_code || '').toUpperCase()
          const thresholds = o.thresholds || []
          const threshText = thresholds.length === 0
            ? 'No thresholds configured'
            : thresholds.map((t) => `${t.document_type} · ${t.max_hours} hours at this desk`).join(' · ')
          return (
            <div key={o.office_id || code} className="card sf-life__panel admin-office-row">
              <div className={`admin-office-row__badge office-accent--${code.toLowerCase() || 'eng'}`}>
                {code || '?'}
              </div>
              <div className="admin-office-row__body">
                <strong>{o.office_name || code}</strong>
                <span className="muted">{threshText}</span>
              </div>
              <StatusPill tone="ok">Active</StatusPill>
            </div>
          )
        })}
      </div>
    </div>
  )
}
