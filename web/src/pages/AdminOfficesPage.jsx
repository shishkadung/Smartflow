import { useAuth } from '../auth.jsx'
import { Link } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { ApiError } from '../api.js'
import { LifeEmpty, Overview } from '../components/ui.jsx'

export default function AdminOfficesPage() {
  const { smartflow } = useAuth()
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
  }, [smartflow])

  return (
    <div className="sf-life offices-page">
      <Overview
        title="Offices"
        actions={<Link className="btn-secondary" to="/admin/thresholds">Manage thresholds</Link>}
      />
      {error ? <div className="error" role="alert">{error}</div> : null}
      {loading ? <p className="muted">Loading…</p> : null}
      {!loading && !error && offices.length === 0 ? (
        <LifeEmpty icon="offices">No offices configured.</LifeEmpty>
      ) : null}
      {offices.length ? (
        <div className="card sf-life__panel admin-office-table-wrap">
          <table className="admin-office-table">
            <thead><tr><th scope="col"><span className="sr-only">Office</span></th><th scope="col">Time limits (processing hours · hours to record receipt)</th><th scope="col"><span className="sr-only">Actions</span></th></tr></thead>
            <tbody>
              {offices.map((o) => {
                const code = String(o.office_code || '').toUpperCase()
                const thresholds = o.thresholds || []
                return (
                  <tr key={o.office_id || code}>
                    <th scope="row">
                      <span className={`admin-office-row__badge office-accent--${code.toLowerCase() || 'eng'}`}>{code || '?'}</span>
                      <span className="admin-office-table__name">{o.office_name || code}</span>
                    </th>
                    <td>
                      {thresholds.length ? <ul className="office-rule-list">{thresholds.map(t => <li key={t.document_type}><strong>{t.document_type}</strong><span>{t.max_hours} processing hours · {t.out_unconfirmed_hours ?? 24} hours to record receipt</span></li>)}</ul> : <span className="muted">No custom alert rules configured.</span>}
                    </td>
                    <td className="admin-office-table__action"><Link to={`/admin/thresholds?office=${encodeURIComponent(o.office_id)}`} aria-label={`${thresholds.length ? 'Edit' : 'Add'} limits for ${o.office_name || code}`}>{thresholds.length ? 'Edit limits' : 'Add limits'} ›</Link></td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      ) : null}
    </div>
  )
}
