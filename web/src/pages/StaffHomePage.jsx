import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { DocTable, LifeEmpty, LifeSkeleton, Overview } from '../components/ui.jsx'

/**
 * Clerk / staff desk home.
 * Visual polish is scoped under `.desk-home` / `.sf-life`.
 */
export default function StaffHomePage() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    smartflow.dashboardStats(user.office_id)
      .then((d) => { if (!cancelled) setData(d) })
      .catch((e) => { if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load dashboard') })
    return () => { cancelled = true }
  }, [user.office_id])

  const loading = !data && !error
  const stats = data?.stats || {}
  const onDesk = data?.active_documents || []
  const incoming = data?.in_transit || []
  const received = loading ? '···' : (stats.in_flow ?? '—')
  const sent = loading ? '···' : (stats.out_flow ?? '—')
  const active = loading ? '···' : (stats.active_tags ?? '—')

  return (
    <div className="desk-home sf-life">
      <Overview
        title="Desk"
        body="Today’s received, sent, and folders on desk."
      />
      {error ? <div className="error">{error}</div> : null}

      <div className="stats desk-home__stats sf-life__stats">
        <div className="stat stat--in">
          <b>{received}</b>
          <span>Received today</span>
        </div>
        <div className="stat stat--out">
          <b>{sent}</b>
          <span>Sent today</span>
        </div>
        <div className="stat stat--desk">
          <b>{active}</b>
          <span>On desk now</span>
        </div>
      </div>

      <div className="desk-grid">
        <div className="card desk-home__panel sf-life__panel">
          <h3 className="section-title">At your office now</h3>
          {loading ? (
            <LifeSkeleton rows={3} label="Loading desk" />
          ) : onDesk.length === 0 ? (
            <LifeEmpty
              icon="custodyLog"
              action={(
                <Link className="btn-secondary as-link sf-life__empty-cta" to="/scan">
                  Open Scanner
                </Link>
              )}
            >
              No folders IN here right now.
            </LifeEmpty>
          ) : (
            <DocTable
              columns={[
                { key: 'document_id', label: 'ID' },
                { key: 'type', label: 'Type' },
                { key: 'title', label: 'Title' },
              ]}
              rows={onDesk}
              onRowClick={(doc) => navigate(`/scan?id=${doc.document_id}`)}
            />
          )}
        </div>
        <div className="card desk-home__panel sf-life__panel">
          <h3 className="section-title">Incoming (in transit)</h3>
          {loading ? (
            <LifeSkeleton rows={2} label="Loading incoming" />
          ) : incoming.length === 0 ? (
            <LifeEmpty icon="scan" tone="ok">Nothing forwarded in the last 48 hours.</LifeEmpty>
          ) : (
            <ul className="timeline">
              {incoming.map((doc) => (
                <li key={doc.document_id}>
                  <button className="list-item" type="button" onClick={() => navigate(`/scan?id=${doc.document_id}`)}>
                    <strong>{doc.document_id}</strong>
                    <span className="muted">From {doc.last_office_name}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  )
}
