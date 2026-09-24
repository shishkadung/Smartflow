import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { DocTable, LifeEmpty, Overview } from '../components/ui.jsx'

export default function HeadHomePage() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    smartflow.headDashboard(user.office_id)
      .then((d) => { if (!cancelled) setData(d) })
      .catch((e) => { if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load office queue') })
    return () => { cancelled = true }
  }, [user.office_id])

  const stats = data?.stats || {}
  const queue = data?.queue || []

  return (
    <div className="sf-life">
      <Overview
        title="Office queue"
        body="Folders currently at your office."
      />
      {error ? <div className="error">{error}</div> : null}
      <div className="stats sf-life__stats">
        <div className="stat stat--desk">
          <b>{stats.in_office ?? '—'}</b>
          <span>In office</span>
        </div>
        <div className="stat stat--overdue">
          <b>{stats.overdue ?? '—'}</b>
          <span>Overdue</span>
        </div>
        <div className="stat stat--hours">
          <b>{stats.avg_hours ?? '—'}</b>
          <span>Avg hours</span>
        </div>
      </div>
      <div className="card sf-life__panel">
        <h3 className="section-title">Queue</h3>
        {queue.length === 0 ? (
          <LifeEmpty icon="custodyLog" tone="ok">No documents in the office queue.</LifeEmpty>
        ) : (
          <DocTable
            columns={[
              { key: 'document_id', label: 'ID', render: (d) => d.document_id || d.id },
              { key: 'title', label: 'Title' },
              { key: 'type', label: 'Type' },
              { key: 'current_status', label: 'Status' },
            ]}
            rows={queue}
            onRowClick={(doc) => navigate(`/scan?id=${doc.document_id || doc.id}`)}
          />
        )}
      </div>
    </div>
  )
}
