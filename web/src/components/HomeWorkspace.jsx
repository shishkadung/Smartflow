import { Link, useOutletContext } from 'react-router-dom'
import { SfIcon } from '../icons.jsx'
import { movementScanSubtitle } from '../tracking.js'
import { StatusPill } from './ui.jsx'

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

/** Latest scans at the office today. Staff see the folder name; the head sees the tracking ID, as on the phone. */
export function HomeActivity({ title, caption, rows, onOpen, limit = 5, named = false }) {
  const shown = (rows || []).slice(0, limit)
  if (shown.length === 0) return null
  return <section className="workspace-panel home-activity">
    <div className="workspace-panel__head"><h3>{title}</h3></div>
    {caption ? <p className="muted home-activity__caption">{caption}</p> : null}
    <ul className="home-activity__list">
      {shown.map((m, index) => {
        const id = m.document_id || ''
        const name = named && m.title ? m.title : id
        return <li key={`${id}-${m.scanned_at}-${index}`}>
          <button type="button" className="home-activity__row" disabled={!id} onClick={() => onOpen(id)}>
            <StatusPill tone={m.status === 'OUT' ? 'neutral' : 'ok'}>{m.status === 'OUT' ? 'SENT' : 'IN'}</StatusPill>
            <span className="home-activity__copy">
              <strong>{name}</strong>
              {named && m.title ? <span>{id}</span> : null}
              <span>{movementScanSubtitle(m)}</span>
            </span>
          </button>
        </li>
      })}
    </ul>
  </section>
}

/** When the dashboard last loaded; after a failed refresh it says so, so old figures are not read as current. */
export function HomeUpdated({ at, failed = false }) {
  if (!at) return null
  const clock = at.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
  return <p className="hint home-updated" role="status">{failed ? 'Last successful update' : 'Updated'} {clock}</p>
}
