import { Link } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { DocTable, LifeEmpty, Overview } from '../components/ui.jsx'

export default function AdminHomePage() {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    smartflow.accountantDashboard()
      .then((d) => { if (!cancelled) setData(d) })
      .catch((e) => { if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load municipal dashboard') })
    return () => { cancelled = true }
  }, [])

  const stats = data?.stats || {}
  const offices = data?.office_totals || []
  const pending = stats.pending_signups ?? 0

  return (
    <div className="sf-life">
      <Overview
        title="Municipal dashboard"
        body="Active custody across pilot offices."
      />
      {pending > 0 ? (
        <Link className="stat admin-tile admin-tile--alert" to="/admin/users" style={{ display: 'block', textDecoration: 'none' }}>
          <b>Review sign-up requests</b>
          <span>{pending} pending approval</span>
        </Link>
      ) : null}
      {error ? <div className="error">{error}</div> : null}
      <div className="stats sf-life__stats">
        <div className="stat stat--desk">
          <b>{stats.active_documents ?? '—'}</b>
          <span>Active</span>
        </div>
        <div className="stat stat--overdue">
          <b>{stats.overdue ?? '—'}</b>
          <span>Overdue</span>
        </div>
        <div className="stat stat--pending">
          <b>{pending || '—'}</b>
          <span>Pending</span>
        </div>
      </div>
      <div className="card sf-life__panel">
        <h3 className="section-title">By office</h3>
        {offices.length === 0 ? (
          <LifeEmpty icon="users" tone="ok">No office totals yet.</LifeEmpty>
        ) : (
          <DocTable
            columns={[
              { key: 'office_name', label: 'Office' },
              { key: 'in_office', label: 'On desk' },
              { key: 'overdue', label: 'Overdue' },
              { key: 'docs_processed', label: 'Processed' },
            ]}
            rows={offices}
          />
        )}
      </div>
    </div>
  )
}
