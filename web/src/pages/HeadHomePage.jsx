import { useLiveRefresh } from '../live-refresh.js'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, LifeSkeleton, Overview, Segmented, WorkCard } from '../components/ui.jsx'
import { HomeMetrics, HomeTaskLinks } from '../components/HomeWorkspace.jsx'

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
  const [filter, setFilter] = useState('all')
  const [sort, setSort] = useState('hoursDesc')
  const [query, setQuery] = useState('')

  useEffect(() => {
    if (hash !== '#office-queue') return undefined
    const node = document.getElementById('office-queue')
    node?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    return undefined
  }, [hash, data])

  const stats = data?.stats || {}
  const queue = data?.queue || emptyQueue

  function awaitingReceive(item) {
    const meta = String(item.meta || '').toLowerCase()
    return item.last_status === 'OUT' && meta.includes('awaiting receive')
  }

  const visible = useMemo(() => {
    const q = query.trim().toUpperCase()
    const list = queue.filter((item) => {
      const status = String(item.status_label || '').trim().toLowerCase()
      if (filter === 'in_office' && status !== 'in_office') return false
      if (filter === 'overdue' && status !== 'overdue') return false
      if (filter === 'forwarded' && !awaitingReceive(item)) return false
      if (q) {
        const id = String(item.document_id || item.id || '').toUpperCase()
        const title = String(item.title || '').toUpperCase()
        if (!id.includes(q) && !title.includes(q)) return false
      }
      return true
    })
    list.sort((a, b) => {
      if (sort === 'id') {
        return String(a.document_id || '').localeCompare(String(b.document_id || ''))
      }
      const ha = Number(a.hours_pending) || 0
      const hb = Number(b.hours_pending) || 0
      return sort === 'hoursAsc' ? ha - hb : hb - ha
    })
    return list
  }, [queue, filter, sort, query])

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
              onChange={setFilter}
              options={[
                { value: 'all', label: 'All' },
                { value: 'in_office', label: 'In office' },
                { value: 'overdue', label: 'Overdue' },
                { value: 'forwarded', label: 'Awaiting receive' },
              ]}
            />
          </div>
          <div className="field head-queue-controls__find">
            <label htmlFor="head-queue-search">Find in queue</label>
            <input id="head-queue-search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Tracking ID or title" />
          </div>
          <div className="field head-queue-controls__sort">
            <label htmlFor="head-queue-sort">Sort</label>
            <select id="head-queue-sort" value={sort} onChange={(e) => setSort(e.target.value)}>
              <option value="hoursDesc">Longest wait</option>
              <option value="hoursAsc">Shortest wait</option>
              <option value="id">Tracking ID</option>
            </select>
          </div>
        </div>
        {!error && queue.length === 0 ? (
          <LifeEmpty icon="custodyLog" tone="ok">No documents in the office queue.</LifeEmpty>
        ) : null}
        {queue.length > 0 && visible.length === 0 ? (
          <LifeEmpty icon="custodyLog" action={<button type="button" className="btn-secondary" onClick={() => { setFilter('all'); setQuery('') }}>Show all</button>}>
            No documents in this filter.
          </LifeEmpty>
        ) : null}
        {visible.length > 0 ? (
          <div className="work-list">
            {visible.map((doc) => {
              const docId = doc.document_id || doc.id
              const status = String(doc.status_label || '').trim().toLowerCase()
              const waiting = awaitingReceive(doc)
              // Use the server's classification: completed or elsewhere-held folders must not read as "In office".
              const tone = status === 'overdue' ? 'bad' : waiting ? 'warn' : status === 'completed' ? 'ok' : status === 'in_office' ? 'info' : 'neutral'
              const pill = status === 'overdue' ? 'Overdue' : waiting ? 'Awaiting receive' : status === 'completed' ? 'Completed' : status === 'in_office' ? 'In office' : (doc.status_pill || 'On time')
              const hours = Number(doc.hours_pending)
              const wait = Number.isFinite(hours) && hours > 0 ? `${hours}h waiting` : 'Just recorded'
              return (
                <WorkCard
                  key={docId}
                  kicker={docId}
                  title={doc.title || doc.type || 'Folder'}
                  meta={wait}
                  pill={pill}
                  tone={tone}
                  verb="Open"
                  onOpen={() => navigate(`/documents?id=${encodeURIComponent(docId)}`)}
                />
              )
            })}
          </div>
        ) : null}
      </div>
      : null}
    </div>
  )
}
