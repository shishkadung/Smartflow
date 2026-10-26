import { useLiveRefresh } from '../live-refresh.js'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, LifeSkeleton, Overview, Segmented, WorkCard } from '../components/ui.jsx'
import { HomeMetrics, HomeTaskLinks } from '../components/HomeWorkspace.jsx'
import { QUEUE_PAGE_SIZE, filterQueue, queueCounts, queueState, waitLabel } from '../head-queue.js'
import { scrollBehavior } from '../motion.js'

const emptyQueue = []

export default function HeadHomePage() {
  const revision = useLiveRefresh()
  const { user, smartflow } = useAuth()
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [retry, setRetry] = useState(0)

  useEffect(() => {
    let cancelled = false
    // oxlint-disable-next-line react/set-state-in-effect -- Track the dashboard refresh while retaining its last successful data.
    setLoading(true)
    smartflow.headDashboard(user.office_id)
      .then((d) => { if (!cancelled) { setData(d); setError('') } })
      .catch((e) => { if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load office queue') })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [user.office_id, revision, retry, smartflow])

  return <HeadDashboardContent data={data} error={error} loading={loading} onRetry={() => setRetry((value) => value + 1)} />
}

export function HeadDashboardContent({ data, error, loading, onRetry }) {
  const navigate = useNavigate()
  const { hash } = useLocation()
  const [filter, setFilter] = useState('active')
  const [sort, setSort] = useState('attention')
  const [query, setQuery] = useState('')
  const [limit, setLimit] = useState(QUEUE_PAGE_SIZE)

  useEffect(() => {
    if (hash !== '#office-queue') return undefined
    const node = document.getElementById('office-queue')
    node?.scrollIntoView({ behavior: scrollBehavior(), block: 'start' })
    return undefined
  }, [hash, data])

  const stats = data?.stats || {}
  const queue = data?.queue || emptyQueue
  const counts = useMemo(() => queueCounts(queue), [queue])
  const matches = useMemo(() => filterQueue(queue, { filter, query, sort }), [queue, filter, query, sort])
  const visible = matches.slice(0, limit)
  // A different view starts again at the first page.
  const choose = (setter) => (value) => { setter(value); setLimit(QUEUE_PAGE_SIZE) }
  const showAll = () => { setFilter('all'); setQuery(''); setLimit(QUEUE_PAGE_SIZE) }
  const searchEverywhere = () => { setFilter('all'); setLimit(QUEUE_PAGE_SIZE) }

  return (
    <div className="sf-life home-dashboard">
      <Overview
        title="Dashboard"
      />
      {error ? <div className="error" role="alert">
        <strong>{data ? 'Refresh failed' : 'Dashboard unavailable'}</strong>
        <p>{error}</p>
        {data ? <p>Showing previously loaded data; counts may be out of date.</p> : <p>Office counts and queue could not be checked.</p>}
        <button type="button" className="btn-secondary" disabled={loading} onClick={onRetry}>{loading ? 'Retrying…' : 'Try again'}</button>
      </div> : null}
      {data ? <HomeMetrics items={[
        { label: 'In office', value: stats.in_office, detail: 'Current custody' },
        { label: 'Overdue', value: stats.overdue, detail: Number(stats.overdue) > 0 ? 'Needs follow-up · view' : 'Needs follow-up', alert: true, ...(Number(stats.overdue) > 0 ? { to: '/documents?overdue=1' } : {}) },
        { label: 'Avg hours', value: stats.avg_hours, detail: 'Processing time' },
      ]} /> : null}
      <HomeTaskLinks />
      {loading && !data ? <LifeSkeleton rows={3} label="Loading queue" /> : null}
      {data ?
      <div className="card sf-life__panel" id="office-queue">
        <h3 className="section-title">Queue</h3>
        <div className="head-queue-controls">
          <div className="toolbar">
            <Segmented
              value={filter}
              onChange={choose(setFilter)}
              options={[
                { value: 'active', label: 'Active', badge: counts.active },
                { value: 'overdue', label: 'Overdue', badge: counts.overdue },
                { value: 'in_office', label: 'In office', badge: counts.in_office },
                { value: 'awaiting', label: 'Awaiting receive', badge: counts.awaiting },
                { value: 'completed', label: 'Completed', badge: counts.completed },
                { value: 'all', label: 'All' },
              ]}
            />
          </div>
          <div className="field head-queue-controls__find">
            <label htmlFor="head-queue-search">Find in queue</label>
            <input id="head-queue-search" value={query} onChange={(e) => choose(setQuery)(e.target.value)} placeholder="Tracking ID or title" />
          </div>
          <div className="field head-queue-controls__sort">
            <label htmlFor="head-queue-sort">Sort</label>
            <select id="head-queue-sort" value={sort} onChange={(e) => choose(setSort)(e.target.value)}>
              <option value="attention">Needs attention first</option>
              <option value="hoursDesc">Longest wait</option>
              <option value="hoursAsc">Shortest wait</option>
              <option value="id">Tracking ID</option>
            </select>
          </div>
        </div>
        {!error && queue.length === 0 ? (
          <LifeEmpty icon="custodyLog" tone="ok">No documents in the office queue.</LifeEmpty>
        ) : null}
        {queue.length > 0 && matches.length === 0 ? (
          query.trim() && filter !== 'all' ? (
            <LifeEmpty icon="custodyLog" action={<><button type="button" className="btn-secondary" onClick={searchEverywhere}>Search all folders</button><button type="button" className="btn-secondary" onClick={() => choose(setQuery)('')}>Clear search</button></>}>
              Nothing matches “{query.trim()}” in this view.
            </LifeEmpty>
          ) : filter === 'active' && !query.trim() ? (
            <LifeEmpty icon="custodyLog" tone="ok" action={<button type="button" className="btn-secondary" onClick={() => choose(setFilter)('completed')}>Show completed</button>}>
              No active documents. Finished folders are under Completed.
            </LifeEmpty>
          ) : (
            <LifeEmpty icon="custodyLog" action={<button type="button" className="btn-secondary" onClick={showAll}>Show all</button>}>
              No documents in this filter.
            </LifeEmpty>
          )
        ) : null}
        {visible.length > 0 ? (
          <>
          <div className="work-list">
            {visible.map((doc) => {
              const docId = doc.document_id || doc.id
              const state = queueState(doc)
              // Use the server's classification: completed or elsewhere-held folders must not read as "In office".
              const tone = state === 'overdue' ? 'bad' : state === 'awaiting' ? 'warn' : state === 'completed' ? 'ok' : state === 'in_office' ? 'info' : 'neutral'
              const pill = state === 'overdue' ? 'Overdue' : state === 'awaiting' ? 'Awaiting receive' : state === 'completed' ? 'Completed' : state === 'in_office' ? 'In office' : (doc.status_pill || 'On time')
              return (
                <WorkCard
                  key={docId}
                  kicker={docId}
                  title={doc.title || doc.type || 'Folder'}
                  meta={waitLabel(doc)}
                  pill={pill}
                  tone={tone}
                  verb="Open"
                  onOpen={() => navigate(`/documents?id=${encodeURIComponent(docId)}`)}
                />
              )
            })}
          </div>
          {matches.length > visible.length ? (
            <div className="head-queue-more">
              <span className="muted" role="status">Showing {visible.length} of {matches.length}</span>
              <button type="button" className="btn-secondary" onClick={() => setLimit((value) => value + QUEUE_PAGE_SIZE)}>Show {Math.min(QUEUE_PAGE_SIZE, matches.length - visible.length)} more</button>
            </div>
          ) : null}
          </>
        ) : null}
      </div>
      : null}
    </div>
  )
}
