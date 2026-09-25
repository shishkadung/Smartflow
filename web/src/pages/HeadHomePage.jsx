import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, LifeSkeleton, Overview, Segmented, statTone } from '../components/ui.jsx'

export default function HeadHomePage() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [filter, setFilter] = useState('all')
  const [sort, setSort] = useState('hoursDesc')
  const [query, setQuery] = useState('')
  const [copied, setCopied] = useState('')

  useEffect(() => {
    let cancelled = false
    smartflow.headDashboard(user.office_id)
      .then((d) => { if (!cancelled) setData(d) })
      .catch((e) => { if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load office queue') })
    return () => { cancelled = true }
  }, [user.office_id])

  const stats = data?.stats || {}
  const queue = data?.queue || []
  const loading = !data && !error

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
    <div className="sf-life">
      <Overview
        title="Office overview"
        body="Snapshot of folders at your office."
      />
      {error ? <div className="error">{error}</div> : null}
      <div className="stats sf-life__stats">
        <div className={statTone(stats.in_office, 'stat--desk')}>
          <b>{stats.in_office ?? '—'}</b>
          <span>In office</span>
        </div>
        <div className={statTone(stats.overdue, 'stat--overdue')}>
          <b>{stats.overdue ?? '—'}</b>
          <span>Overdue</span>
        </div>
        <div className={statTone(stats.avg_hours, 'stat--hours')}>
          <b>{stats.avg_hours ?? '—'}</b>
          <span>Avg hours</span>
        </div>
      </div>
      <div className="card sf-life__panel">
        <h3 className="section-title">Queue</h3>
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
        <div className="history-side" style={{ marginTop: 10 }}>
          <div className="field" style={{ marginBottom: 0 }}>
            <label>Find in queue</label>
            <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Tracking ID or title" />
          </div>
          <div className="field" style={{ marginBottom: 0 }}>
            <label>Sort</label>
            <select value={sort} onChange={(e) => setSort(e.target.value)}>
              <option value="hoursDesc">Longest wait</option>
              <option value="hoursAsc">Shortest wait</option>
              <option value="id">Tracking ID</option>
            </select>
          </div>
        </div>
        {loading ? <LifeSkeleton rows={3} label="Loading queue" /> : null}
        {!loading && queue.length === 0 ? (
          <LifeEmpty icon="custodyLog" tone="ok">No documents in the office queue.</LifeEmpty>
        ) : null}
        {!loading && queue.length > 0 && visible.length === 0 ? (
          <LifeEmpty icon="custodyLog" action={<button type="button" className="btn-secondary" onClick={() => { setFilter('all'); setQuery('') }}>Show all</button>}>
            No documents in this filter.
          </LifeEmpty>
        ) : null}
        {visible.length > 0 ? (
          <ul className="history-picks">
            {visible.map((doc) => {
              const docId = doc.document_id || doc.id
              return (
                <li key={docId}>
                  <button type="button" onClick={() => navigate(`/history?id=${docId}`)}>
                    <strong>{docId}</strong>
                    <span>{doc.title || doc.type}</span>
                    <span>{doc.status_label || doc.current_status || ''}</span>
                    {doc.hours_pending != null ? <span>{doc.hours_pending}h</span> : null}
                  </button>
                  <button
                    type="button"
                    className="btn-ghost"
                    onClick={async () => {
                      try {
                        await navigator.clipboard.writeText(docId)
                        setCopied(docId)
                      } catch {
                        setCopied('')
                      }
                    }}
                  >
                    {copied === docId ? 'Copied' : 'Copy ID'}
                  </button>
                </li>
              )
            })}
          </ul>
        ) : null}
      </div>
    </div>
  )
}
