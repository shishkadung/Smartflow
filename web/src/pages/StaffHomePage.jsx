import { useLiveRefresh } from '../live-refresh.js'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeSkeleton, Overview, WorkCard } from '../components/ui.jsx'
import { HomeMetrics, HomeTaskLinks } from '../components/HomeWorkspace.jsx'
import { SfIcon } from '../icons.jsx'

export default function StaffHomePage() {
  const revision = useLiveRefresh()
  const { user, smartflow } = useAuth()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [retry, setRetry] = useState(0)

  useEffect(() => {
    let cancelled = false
    // oxlint-disable-next-line react/set-state-in-effect -- Retain the last successful dashboard while checking its freshness.
    setLoading(true)
    smartflow.dashboardStats(user.office_id)
      .then((d) => { if (!cancelled) { setData(d); setError('') } })
      .catch((e) => { if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load dashboard') })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [user.office_id, revision, retry, smartflow])

  const stale = Boolean(data) && (loading || Boolean(error))
  const stats = data?.stats || {}
  const onDesk = data?.active_documents || []
  const incoming = data?.in_transit || []
  // Folders waiting to be received come first: they are the next thing the staff member has to do.
  const arriving = Boolean(data) && incoming.length > 0
  const received = stats.in_flow ?? '—'
  const sent = stats.out_flow ?? '—'
  const active = stats.active_tags ?? '—'

  const incomingPanel = (
    <section className={`workspace-panel${arriving ? " workspace-panel--arriving" : ""}`}>
      <div className="workspace-panel__head"><h3>{arriving ? "Incoming: needs receipt" : "Incoming"}</h3><span>{!data ? '—' : incoming.length} {incoming.length === 1 ? 'folder' : 'folders'}</span></div>
      {loading && !data ? (
        <LifeSkeleton rows={2} label="Loading incoming" />
      ) : !data && error ? (
        <div className="workspace-empty"><span className="workspace-empty__icon"><SfIcon name="incoming" size={24} /></span><div><strong>Incoming unavailable</strong><p>Retry to check folders sent to your office.</p></div></div>
      ) : incoming.length === 0 ? (
        <div className="workspace-empty"><span className="workspace-empty__icon"><SfIcon name="incoming" size={24} /></span><div><strong>{stale ? 'Previously loaded incoming list is empty' : 'No folders on the way'}</strong><p>{stale ? 'Current incoming folders have not been verified.' : 'Folders sent to this office will appear here.'}</p></div></div>
      ) : (
        <div className="work-list">
          {incoming.map((doc) => (
            <WorkCard
              key={doc.document_id}
              kicker={doc.document_id}
              title={doc.title || doc.type || 'Folder'}
              meta={doc.last_office_name ? `From ${doc.last_office_name}` : 'On the way'}
              pill="Arriving"
              tone="warn"
              verb="Receive"
              onOpen={() => navigate(`/documents?id=${encodeURIComponent(doc.document_id)}`)}
            />
          ))}
        </div>
      )}
    </section>
  )
  const deskPanel = (
    <section className="workspace-panel">
      <div className="workspace-panel__head"><h3>At your office</h3><span>{!data ? '—' : onDesk.length} {onDesk.length === 1 ? 'folder' : 'folders'}</span></div>
      {loading && !data ? (
        <LifeSkeleton rows={3} label="Loading desk" />
      ) : !data && error ? (
        <div className="workspace-empty"><span className="workspace-empty__icon"><SfIcon name="archive" size={24} /></span><div><strong>Desk unavailable</strong><p>Retry to load the folders at your office.</p></div></div>
      ) : onDesk.length === 0 ? (
        <div className="workspace-empty"><span className="workspace-empty__icon"><SfIcon name="archive" size={24} /></span><div><strong>{stale ? 'Previously loaded desk is empty' : 'Your desk is clear'}</strong><p>{stale ? 'Current folders have not been verified.' : 'Registered folders at your office will appear here.'}</p></div></div>
      ) : (
        <div className="work-list">
          {onDesk.map((doc) => (
            <WorkCard
              key={doc.document_id}
              kicker={doc.document_id}
              title={doc.title || doc.type || 'Folder'}
              meta={doc.type}
              pill="On desk"
              tone="info"
              verb="Send"
              onOpen={() => navigate(`/documents?id=${encodeURIComponent(doc.document_id)}`)}
            />
          ))}
        </div>
      )}
    </section>
  )

  return (
    <div className="home-dashboard desk-workspace">
      <Overview title="Dashboard" />
      {error ? <div className="error" role="alert">
        <strong>{data ? 'Refresh failed' : 'Dashboard unavailable'}</strong>
        <p>{error}</p>
        <p>{data ? 'Showing previously loaded data; counts and folders may be out of date.' : 'Office counts and folders could not be checked.'}</p>
        <button type="button" className="btn-secondary" disabled={loading} onClick={() => setRetry((value) => value + 1)}>{loading ? 'Retrying…' : 'Retry'}</button>
      </div> : null}
      {loading && data && !error ? <p className="hint" role="status">Refreshing dashboard. Showing previously loaded data; counts and folders may be out of date.</p> : null}

      {data ? <HomeMetrics items={[
        { label: 'Received', value: received, detail: 'Today' },
        { label: 'Sent', value: sent, detail: 'Today' },
        { label: 'On desk', value: active, detail: 'Right now' },
      ]} /> : null}
      <HomeTaskLinks registration />

      <div className={`workspace-queues${arriving ? " workspace-queues--arriving" : ""}`}>
        {arriving ? incomingPanel : deskPanel}
        {arriving ? deskPanel : incomingPanel}
      </div>
    </div>
  )
}
