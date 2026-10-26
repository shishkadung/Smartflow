import { useEffect, useState } from 'react'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, LifeSkeleton, Segmented, StatusPill } from './ui.jsx'
import { barFraction, barValueLabel, formatHours, monthLabel, sortPerformanceOffices, trendLabel } from '../report-metrics.js'
import { beginScopedRead, failScopedRead, scopedReadView } from '../scoped-read.js'
import './department-performance.css'

const WINDOWS = [{ value: 3, label: '3 months' }, { value: 6, label: '6 months' }, { value: 12, label: '12 months' }]

function visitsLine(totals) {
  if (!totals.visits) return 'No office visits in this window'
  const average = totals.avg_hours == null ? 'No folder forwarded yet' : `${formatHours(totals.avg_hours)} on average before forwarding`
  return `${average} · ${totals.visits} visits · ${totals.late} late (${totals.late_percent}%)`
}

export default function DepartmentPerformance() {
  const { user, smartflow } = useAuth()
  const [months, setMonths] = useState(6)
  const [state, setState] = useState(null)
  const [retry, setRetry] = useState(0)
  const key = JSON.stringify([user.id, months])
  const { data, error, loading } = scopedReadView(state, key)

  useEffect(() => {
    let cancelled = false
    // oxlint-disable-next-line react/set-state-in-effect -- Retain only the same account/window snapshot while the current read is verified.
    setState(previous => beginScopedRead(previous, key))
    smartflow.departmentPerformance(months)
      .then(result => { if (!cancelled) setState({ key, data: result, error: '', loading: false, updated: new Date() }) })
      .catch(e => { if (!cancelled) setState(previous => failScopedRead(previous, key, e instanceof ApiError ? e.message : 'Could not load department performance')) })
    return () => { cancelled = true }
  }, [user.id, months, key, retry, smartflow])

  return <DepartmentPerformanceContent data={data} error={error} loading={loading} months={months} onMonths={setMonths} onRetry={() => setRetry(value => value + 1)} />
}

function monthSummary(month) {
  return `${monthLabel(month.month)}: ${month.avg_hours == null ? 'no forwarded folders' : formatHours(month.avg_hours)}${month.slow ? ', slow' : ''}`
}

/** Average hours per month with the number on each bar; the dashed line marks the default desk limit when the report provides it. */
function MonthBars({ office, scale, limit }) {
  const description = `Average hours per month. ${office.months.map(monthSummary).join('; ')}.${limit ? ` The dashed line is the ${limit} h default desk limit.` : ''}`
  return <div className={`department-performance__bars${limit ? ' has-limit' : ''}`} role="img" aria-label={description} style={limit ? { '--limit': limit / scale } : undefined}>
    {limit ? <span className="department-performance__limit"><em>{limit} h</em></span> : null}
    {office.months.map((month, index) => {
      const fraction = barFraction(month.avg_hours, scale)
      const slow = month.slow ? 'is-slow' : undefined
      return <span key={month.month} className="department-performance__bar" style={{ '--n': index }} title={`${monthSummary(month)}, ${month.late} of ${month.visits} visits late`}>
        <span className="department-performance__track">
          <i className={slow} style={{ '--v': fraction }} />
          {month.avg_hours == null ? null : <b className={slow} style={{ '--v': fraction }}>{barValueLabel(month.avg_hours)}</b>}
        </span>
        <small>{monthLabel(month.month, 'short')}</small>
      </span>
    })}
  </div>
}

export function DepartmentPerformanceContent({ data, error, loading, months, onMonths, onRetry }) {
  const offices = data ? sortPerformanceOffices(data.offices) : []
  const configuredLimit = Number(data?.rules?.default_desk_limit_hours)
  const limit = configuredLimit > 0 ? configuredLimit : null
  const scale = Math.max(1, limit ?? 0, ...offices.flatMap(office => office.months.map(month => Number(month.avg_hours) || 0)))
  return <div className="card sf-life__panel department-performance">
    <div className="department-performance__head">
      <h3 className="section-title">Department performance</h3>
      <Segmented value={months} onChange={onMonths} options={WINDOWS} />
    </div>
    {error ? <div className="error" role="alert"><strong>{data ? 'Department performance refresh failed' : 'Department performance unavailable'}</strong><p>{error}</p>{data ? <p>Showing the previously loaded {data.window.months} month view; it may be out of date.</p> : <p>The comparison between offices could not be verified.</p>}<button type="button" className="btn-secondary" disabled={loading} onClick={onRetry}>Retry department performance</button></div> : null}
    {loading && !data ? <LifeSkeleton rows={3} label="Loading department performance" /> : null}
    {data ? <>
      <p className="muted">{monthLabel(data.window.start_month)} to {monthLabel(data.window.end_month)} · each month is measured at its own end · {data.municipal.totals.visits} office visits in total</p>
      {data.municipal.totals.visits === 0 ? <LifeEmpty icon="coa">No office visits were recorded in this window.</LifeEmpty> : <>
        {data.bottlenecks.length ? <div className="department-performance__flag" role="status">
          <strong>{data.bottlenecks.length === 1 ? 'Recurring bottleneck' : 'Recurring bottlenecks'}</strong>
          <ul>{data.bottlenecks.map(item => <li key={item.office_id}><strong>{item.office_name} ({item.office_code})</strong>: slow in {item.slow_months} of {item.active_months} months · {item.late_percent}% of visits late</li>)}</ul>
        </div> : <p className="muted">No office was slow in {data.rules.recurring_slow_months} or more months in this window.</p>}
        <p className="muted department-performance__legend">Each bar is a month's average hours before forwarding, with the number on it; orange marks a slow month, meaning at least {data.rules?.slow_month_late_percent ?? 25}% of its visits ran past their limit.{limit ? ` The dashed line is the ${limit} h default desk limit; some folder types have their own limit.` : ''}</p>
        <div className="list-item list-item--static"><strong>All offices</strong><span className="muted">{visitsLine(data.municipal.totals)}</span></div>
        <ol className="department-performance__list">
          {offices.map(office => <li key={office.office_id} className="department-performance__row">
            <div className="department-performance__summary">
              <div className="department-performance__title">
                <strong>{office.office_name}</strong><span className="department-performance__code">{office.office_code}</span>
                {office.bottleneck.recurring ? <StatusPill tone="warn">Recurring bottleneck</StatusPill> : null}
              </div>
              <p className="muted">{visitsLine(office.totals)}</p>
              <p className="muted">{trendLabel(office.trend)}</p>
            </div>
            <MonthBars office={office} scale={scale} limit={limit} />
            <details>
              <summary>Month by month</summary>
              <div className="department-performance__scroll"><table>
                <caption className="visually-hidden">{office.office_name} month by month</caption>
                <thead><tr><th scope="col">Month</th><th scope="col">Visits</th><th scope="col">Forwarded</th><th scope="col">Average hours</th><th scope="col">Late</th><th scope="col">Late share</th></tr></thead>
                <tbody>{office.months.map(month => <tr key={month.month}>
                  <th scope="row">{monthLabel(month.month)}{month.slow ? ' · slow' : ''}</th><td>{month.visits}</td><td>{month.forwarded}</td><td>{month.avg_hours == null ? '—' : month.avg_hours}</td><td>{month.late}</td><td>{month.late_percent == null ? '—' : `${month.late_percent}%`}</td>
                </tr>)}</tbody>
              </table></div>
              {office.types.length ? <p className="muted">Folder types with the most late visits: {office.types.filter(type => type.late > 0).slice(0, 3).map(type => `${type.type} (${type.late} late of ${type.visits})`).join('; ') || 'none late'}.</p> : null}
            </details>
          </li>)}
        </ol>
      </>}
      <details className="report-basis"><summary>How these are counted</summary><p>{data.basis}</p></details>
    </> : null}
  </div>
}
