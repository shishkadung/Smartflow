import { Link, useOutletContext } from 'react-router-dom'
import { SfIcon } from '../icons.jsx'

export function HomeMetrics({ items }) {
  return <div className="workspace-metrics" aria-label="Office summary">
    {items.map(item => {
      const contents = <><strong>{item.value ?? '—'}</strong><span className="workspace-metric__copy"><span className="workspace-metric__label">{item.label}</span><span className="workspace-metric__detail">{item.detail}</span></span></>
      const className = `workspace-metric${item.alert && Number(item.value) > 0 ? ' workspace-metric--alert' : ''}`
      return item.to ? <Link key={item.label} className={className} to={item.to}>{contents}</Link>
        : <div key={item.label} className={className}>{contents}</div>
    })}
  </div>
}

export function HomeTaskLinks({ registration = false }) {
  const summary = useOutletContext() || {}
  const { pendingRequests, overdueRequests = 0, requestError = false } = summary
  const status = requestError ? 'Status unavailable · open to retry' : pendingRequests == null ? 'Checking office requests…'
    : `${pendingRequests} pending · ${overdueRequests} overdue`
  return <div className="home-task-links">
    <Link className="navigation-row" to="/requests">
      <SfIcon name="inbox" size={22} />
      <span className="navigation-row__copy"><strong>Requests</strong><span className={requestError || overdueRequests > 0 ? 'navigation-row__status--overdue' : undefined}>{status}</span></span>
      <SfIcon name="back" size={20} className="navigation-row__chevron" />
    </Link>
    {registration ? <Link className="navigation-row" to="/register">
      <SfIcon name="folderAdd" size={22} />
      <span className="navigation-row__copy"><strong>Register folder</strong><span>For a folder already at your office</span></span>
      <SfIcon name="back" size={20} className="navigation-row__chevron" />
    </Link> : null}
  </div>
}
