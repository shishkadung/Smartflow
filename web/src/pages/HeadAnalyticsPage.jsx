import { useLiveRefresh } from '../live-refresh.js'
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, LifeSkeleton, Overview, statTone } from '../components/ui.jsx'
import { beginScopedRead, failScopedRead, scopedReadView } from '../scoped-read.js'
import { reportPeriodBounds } from '../tracking.js'

export default function HeadAnalyticsPage() {
  const revision = useLiveRefresh()
  const { user, smartflow } = useAuth()
  const [month, setMonth] = useState(() => reportPeriodBounds().maxMonth)
  const [state, setState] = useState(null)
  const [retry, setRetry] = useState(0)
  const key = JSON.stringify([user.id, user.office_id, month])
  const { data, error, loading } = scopedReadView(state, key)

  useEffect(() => {
    let cancelled = false
    // oxlint-disable-next-line react/set-state-in-effect -- Retain only the same office/month snapshot while the current read is verified.
    setState(previous => beginScopedRead(previous, key))
    smartflow.headAnalytics(user.office_id, month)
      .then((data) => { if (!cancelled) setState({ key, data, error: '', loading: false, updated: new Date() }) })
      .catch((e) => {
        if (!cancelled) setState(previous => failScopedRead(previous, key, e instanceof ApiError ? e.message : 'Could not load analytics'))
      })
    return () => { cancelled = true }
  }, [user.office_id, month, revision, key, retry, smartflow])

  return <HeadAnalyticsContent user={user} month={month} onMonth={setMonth} data={data} error={error} loading={loading} onRetry={() => setRetry(value => value + 1)} />
}

export function HeadAnalyticsContent({ user, month, onMonth, data, error, loading, onRetry }) {
  const stats = data?.stats || {}
  const slow = data?.slow_documents || []
  const onTime = stats.on_time_percent ?? 0
  const unforwarded = stats.unforwarded_percent ?? 0
  const delayed = stats.delayed_percent ?? 0

  return (
    <div className="sf-life">
      <Overview
        title="Analytics"
        actions={!error ? <button type="button" className="btn-secondary" disabled={loading} onClick={onRetry}>Refresh analytics</button> : null}
      />
      <label className="field analytics-month">
        <span>Month</span>
        <input type="month" value={month} onChange={(e) => onMonth(e.target.value)} />
      </label>
      {error ? <div className="error" role="alert"><strong>{data ? 'Analytics refresh failed' : 'Analytics unavailable'}</strong><p>{error}</p>{data ? <p>Showing previously loaded analytics for {data.month || month}; it may be out of date.</p> : null}<button type="button" className="btn-secondary" disabled={loading} onClick={onRetry}>Retry analytics</button></div> : null}
      {loading && !data ? <LifeSkeleton rows={3} label="Loading analytics" /> : null}
      {data ? (
        <>
          <p className="analytics-summary"><strong>{user.office_name} ({user.office_code}) · {data.month || month}</strong><span className="muted">{stats.processed ?? 0} documents touched · {stats.late_count ?? 0} exceeded the desk limit</span></p>
          <div className="stats sf-life__stats">
            <div className={statTone(onTime, 'stat--in')}>
              <b>{onTime}%</b>
              <span>On time</span>
              <span className="meter meter--ok" aria-hidden><span style={{ width: `${Math.min(100, Number(onTime) || 0)}%` }} /></span>
            </div>
            <div className={statTone(unforwarded, 'stat--hours')}>
              <b>{unforwarded}%</b>
              <span>Unforwarded</span>
              <span className="meter meter--warn" aria-hidden><span style={{ width: `${Math.min(100, Number(unforwarded) || 0)}%` }} /></span>
            </div>
            <div className={statTone(delayed, 'stat--overdue')}>
              <b>{delayed}%</b>
              <span>Delayed</span>
              <span className="meter meter--bad" aria-hidden><span style={{ width: `${Math.min(100, Number(delayed) || 0)}%` }} /></span>
            </div>
          </div>
          <div className="card sf-life__panel">
            <h3 className="section-title">Slow documents <span className="muted">(open a folder to review it)</span></h3>
            {slow.length === 0 && (error || loading) ? <p className="muted">Slow-folder status is not currently verified.</p> : slow.length === 0 ? (
              <LifeEmpty icon="alerts" tone="ok">No slow documents. Processed folders met the desk limit this month.</LifeEmpty>
            ) : (
              <div className="alert-log">
                {slow.slice(0, 5).map((d) => (
                  <Link
                    key={d.document_id}
                    className="alert-log__row"
                    to={`/documents?id=${encodeURIComponent(d.document_id || '')}`}
                  >
                    <div className="alert-log__main">
                      <strong>{d.document_id}</strong>
                    </div>
                    <span className="analytics-slow__hours">{d.hours ?? 0} hours at this desk</span>
                    <span className="analytics-slow__chevron" aria-hidden="true">›</span>
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
