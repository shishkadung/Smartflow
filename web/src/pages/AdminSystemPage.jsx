import { useEffect, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { LifeEmpty, Overview, StatusPill, statTone } from '../components/ui.jsx'

export default function AdminSystemPage() {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [loadedAt, setLoadedAt] = useState(null)

  async function load() {
    setLoading(true)
    setError('')
    try {
      const d = await smartflow.systemStatus()
      setData(d)
      setLoadedAt(new Date())
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not load system status')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  const st = data?.status || {}
  const ops = data?.operations || {}
  const users = data?.users || {}
  const apiOk = String(st.api || '').startsWith('On')

  return (
    <div className="sf-life">
      <Overview
        title="System"
        body="API and database health."
      />
      {error ? <div className="error">{error}</div> : null}
      <button type="button" className="btn btn-secondary" onClick={load} disabled={loading}>
        {loading ? 'Refreshing…' : 'Refresh status'}
      </button>
      {loadedAt ? (
        <p className="muted admin-home__sync">
          Updated {loadedAt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
        </p>
      ) : null}

      {loading && !data ? <p className="muted">Loading…</p> : null}
      {!loading && !data && !error ? (
        <LifeEmpty icon="system">Status unavailable.</LifeEmpty>
      ) : null}

      {data ? (
        <>
          <div className="card sf-life__panel admin-system-row">
            <div>
              <strong>API / PHP</strong>
              <p className="muted">{st.api || '—'}</p>
              <p className="muted">{st.php_version || ''}</p>
            </div>
            <StatusPill tone={apiOk ? 'ok' : 'bad'}>{apiOk ? 'online' : 'offline'}</StatusPill>
          </div>
          <div className="card sf-life__panel">
            <strong>MySQL</strong>
            <p className="muted">
              {st.mysql_version || '—'} · {st.documents ?? 0} documents in DB
            </p>
          </div>
          {users ? (
            <div className="card sf-life__panel">
              <strong>Accounts on duty</strong>
              <p className="muted">
                {users.clerks ?? 0} clerks · {users.heads ?? 0} heads · {users.accountants ?? 0} admin
              </p>
            </div>
          ) : null}
          <div className="stats sf-life__stats">
            <div className={statTone(users.active ?? ops.pending_signups ?? 0, 'stat--desk')}>
              <b>{users.active ?? ops.pending_signups ?? 0}</b>
              <span>Active users</span>
            </div>
            <div className={statTone(ops.movements_today ?? 0, 'stat--in')}>
              <b>{ops.movements_today ?? 0}</b>
              <span>Scans today</span>
            </div>
          </div>
          <div className="card sf-life__panel">
            <strong>Flagged documents</strong>
            <p className="muted">{ops.flagged_total ?? 0} total in system</p>
          </div>
        </>
      ) : null}
    </div>
  )
}
