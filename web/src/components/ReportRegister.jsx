import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../auth.jsx'
import { formatWhen } from '../tracking.js'
import { reportPeriodQuery, reportViewParams } from '../report-navigation.js'
import { LifeEmpty, LifeSkeleton, Segmented } from './ui.jsx'
import './report-register.css'

const labels = { on_time: 'On time / in process', unforwarded: 'Awaiting receipt', delayed: 'Late receipt' }

export default function ReportRegister({ view, onChange, offices = [], revision, enabled = true, asOf, movementWatermark, correctionWatermark }) {
  const { smartflow } = useAuth()
  const [snapshot, setSnapshot] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [retry, setRetry] = useState(0)
  const [search, setSearch] = useState(view.q)
  const query = { ...reportPeriodQuery(view), ...(asOf ? { as_of: asOf } : {}), ...(movementWatermark != null ? { movement_watermark: movementWatermark } : {}), ...(correctionWatermark != null ? { correction_watermark: correctionWatermark } : {}), scope: view.scope, classification: view.classification, ...(view.office_id ? { office_id: view.office_id } : {}), q: view.q, page: view.page, page_size: 25 }
  const key = JSON.stringify(query)
  const data = snapshot?.key === key ? snapshot.data : null
  const returnTo = `/admin/reports?${reportViewParams(view)}`

  useEffect(() => {
    // oxlint-disable-next-line react/set-state-in-effect -- Back/forward navigation restores the committed search.
    setSearch(view.q)
  }, [view.q])

  useEffect(() => {
    let active = true
    // oxlint-disable-next-line react/set-state-in-effect -- A changed query starts a new server read with its own loading state.
    setLoading(true)
    setError('')
    if (!enabled) { setLoading(false); return undefined }
    smartflow.reportsRegister(JSON.parse(key))
      .then(result => { if (active) setSnapshot({ key, data: result }) })
      .catch(cause => { if (active) setError(cause.message || 'Could not load the custody register.') })
      .finally(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [smartflow, key, retry, revision, enabled])

  function change(changes) { onChange({ ...changes, page: 1 }) }

  return <section className="card sf-life__panel report-register" aria-labelledby="custody-register-heading">
    <div className="report-register__heading"><h3 className="section-title" id="custody-register-heading" tabIndex={-1}>Folder register</h3>{data && !loading && !error ? <span className="muted">{data.total} {data.total === 1 ? 'folder' : 'folders'}</span> : null}</div>
    <Segmented value={view.scope} onChange={scope => change({ scope, classification: 'all' })} options={[
      { value: 'activity', label: 'Period activity' }, { value: 'outstanding', label: 'Outstanding transfers' },
    ]} />
    <p className="muted report-register__explanation">{view.scope === 'outstanding'
      ? 'Transfers still awaiting a recorded receipt at the reporting cutoff, including sends from earlier periods. These folders can also appear in Period activity.'
      : 'Folders with a recorded handoff or registration in this period. Custody below is shown as of the reporting cutoff; open tracking for the latest status.'}</p>
    <form className="report-register__controls" onSubmit={event => { event.preventDefault(); change({ q: search.trim() }) }}>
      <label className="field report-register__search">Find a folder<input type="search" value={search} maxLength={200} onChange={event => setSearch(event.target.value)} placeholder="Tracking ID, title or type" /></label>
      <button type="submit" className="btn-secondary">Search</button>
      <label className="field">Custody office at cutoff<select value={view.office_id} onChange={event => change({ office_id: event.target.value })}><option value="">All offices</option>{offices.map(office => <option key={office.office_id} value={office.office_id}>{office.office_name || office.office_code}</option>)}</select></label>
      {view.scope === 'activity' ? <label className="field">Classification<select value={view.classification} onChange={event => change({ classification: event.target.value })}><option value="all">All classifications</option>{Object.entries(labels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label> : null}
      {view.q || view.office_id || view.classification !== 'all' ? <button type="button" className="btn-ghost" onClick={() => { setSearch(''); change({ q: '', office_id: '', classification: 'all' }) }}>Clear filters</button> : null}
    </form>
    {!enabled ? <p className="muted">Load a valid report period to view its folder register.</p> : error ? <div className="error" role="alert">{data ? 'Refresh failed. Previously loaded register may be stale.' : 'Folder register unavailable.'} {error}<button type="button" className="btn-secondary" onClick={() => setRetry(value => value + 1)}>Retry register</button></div> : null}
    {loading ? <LifeSkeleton rows={3} label="Loading custody register" /> : null}
    {enabled && data && !loading ? <>
      <p className="muted report-register__cutoff">As of {formatWhen(data.as_of || data.period_end)} · {data.timezone || 'Municipal timezone'}{error ? ' · Previously loaded data' : ''}</p>
      {!data.documents?.length ? error ? <p className="muted">The previous read returned no rows. Current folder status could not be verified.</p> : data.total > 0 ? <LifeEmpty icon="history" action={<button type="button" className="btn-secondary" onClick={() => onChange({ page: 1 })}>Go to first page</button>}>This page is no longer available. Return to the first page of these results.</LifeEmpty> : <LifeEmpty icon="history">{view.q || view.office_id || view.classification !== 'all' ? 'No folders match these filters.' : view.scope === 'outstanding' ? 'No outstanding transfers at this reporting cutoff.' : 'No recorded folder activity in this period.'}</LifeEmpty> : <ReportRegisterRows rows={data.documents} returnTo={returnTo} />}
      <div className="report-register__paging"><span>{data.total === 0 ? '0 folders' : `Page ${data.page} of ${data.total_pages} · ${data.total} ${data.total === 1 ? 'folder' : 'folders'}`}</span><div><button type="button" className="btn-secondary" disabled={loading || !!error || data.page <= 1} onClick={() => onChange({ page: data.page - 1 })}>Previous</button><button type="button" className="btn-secondary" disabled={loading || !!error || data.page >= data.total_pages} onClick={() => onChange({ page: data.page + 1 })}>Next</button></div></div>
    </> : null}
  </section>
}

export function ReportRegisterRows({ rows, returnTo }) {
  const link = (path, id) => `${path}?${new URLSearchParams({ id, report_return: returnTo })}`
  return <table className="report-register__table"><thead><tr><th scope="col">Folder</th><th scope="col">Custody at cutoff</th><th scope="col">Recorded evidence</th><th scope="col">Tracking</th></tr></thead><tbody>{rows.map(row => <tr key={row.document_id}>
    <td data-label="Folder"><strong>{row.title}</strong><span className="muted">{row.document_id} · {row.type}</span><span>{labels[row.classification] || 'Classification unavailable'}</span>{row.carried_forward ? <span className="report-register__carry">Sent before this period</span> : null}</td>
    <td data-label="Custody at cutoff"><strong>{row.current_status === 'OUT' ? 'Receipt not recorded' : 'Received at office'}</strong><span>{row.current_status === 'OUT' ? `From ${row.current_office_name || 'Office unavailable'} → ${row.destination_office_name || 'Destination not recorded'}` : row.current_office_name || 'Office unavailable'}</span>{row.current_status === 'OUT' && row.receipt_wait_hours != null ? <span className="muted">{Math.floor(row.receipt_wait_hours)} calendar hours since sending</span> : null}</td>
    <td data-label="Recorded evidence"><span>{formatWhen(row.last_scanned_at)} · {row.recorded_by || 'Recorder not recorded'}</span><details><summary>Receipt and send evidence</summary><p>Last received: {row.last_received_at ? `${formatWhen(row.last_received_at)} · ${row.received_by || 'Recorder not recorded'}` : 'Not recorded'}</p><p>Last sent: {row.last_sent_at ? `${formatWhen(row.last_sent_at)} · ${row.sent_by || 'Recorder not recorded'}` : 'Not recorded'}</p><p>{row.movement_count} recorded {row.movement_count === 1 ? 'movement' : 'movements'} through cutoff. Full history retains counts, notes and corrections.</p></details></td>
    <td data-label="Tracking"><Link className="linkish" aria-label={`Track folder ${row.document_id}`} to={link('/documents', row.document_id)}>Track folder</Link><Link className="linkish" aria-label={`Full history of ${row.document_id}`} to={link('/history', row.document_id)}>Full history</Link></td>
  </tr>)}</tbody></table>
}
