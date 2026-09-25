import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, Overview, statTone } from '../components/ui.jsx'

export default function HeadAnalyticsPage() {
  const { user } = useAuth()
  const [month, setMonth] = useState(() => new Date().toISOString().slice(0, 7))
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError('')
    smartflow.headAnalytics(user.office_id, month)
      .then((d) => { if (!cancelled) setData(d) })
      .catch((e) => {
        if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load analytics')
      })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [user.office_id, month])

  const stats = data?.stats || {}
  const slow = data?.slow_documents || []
  const onTime = stats.on_time_percent ?? 0
  const unforwarded = stats.unforwarded_percent ?? 0
  const delayed = stats.delayed_percent ?? 0

  return (
    <div className="sf-life">
      <Overview
        title="Analytics"
        body="On-time rate and slow documents for your office."
      />
      <label className="field analytics-month">
        <span>Month</span>
        <input type="month" value={month} onChange={(e) => setMonth(e.target.value)} />
      </label>
      {error ? <div className="error">{error}</div> : null}
      {loading ? <p className="muted">Loading…</p> : null}
      {!loading && data ? (
        <>
          <div className="stats sf-life__stats">
            <div className={statTone(onTime, 'stat--in')}>
              <b>{onTime}%</b>
              <span>On time</span>
            </div>
            <div className={statTone(unforwarded, 'stat--hours')}>
              <b>{unforwarded}%</b>
              <span>Unforwarded</span>
            </div>
            <div className={statTone(delayed, 'stat--overdue')}>
              <b>{delayed}%</b>
              <span>Delayed</span>
            </div>
          </div>
          <div className="card sf-life__panel">
            <h3 className="section-title">Office summary</h3>
            <p className="muted">{user.office_name} ({user.office_code}) · {data.month || month}</p>
            <p className="muted">{stats.processed ?? 0} documents touched · {stats.late_count ?? 0} exceeded the desk limit</p>
          </div>
          <div className="card sf-life__panel">
            <h3 className="section-title">Slow documents</h3>
            {slow.length === 0 ? (
              <LifeEmpty icon="alerts" tone="ok">No slow documents. Processed folders met the desk limit this month.</LifeEmpty>
            ) : (
              <div className="alert-log">
                {slow.slice(0, 5).map((d) => (
                  <Link
                    key={d.document_id}
                    className="alert-log__row"
                    to={`/history?id=${encodeURIComponent(d.document_id || '')}`}
                  >
                    <div className="alert-log__main">
                      <strong>{d.document_id}</strong>
                      <span className="muted">{d.hours ?? 0} hours at this desk</span>
                    </div>
                  </Link>
                ))}
              </div>
            )}
          </div>
        </>
      ) : null}
    </div>
  )
}
