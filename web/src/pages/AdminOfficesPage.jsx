import { useAuth } from '../auth.jsx'
import { Link } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { ApiError } from '../api.js'
import { LifeEmpty, Overview } from '../components/ui.jsx'

export default function AdminOfficesPage() {
  const { smartflow } = useAuth()
  const [offices, setOffices] = useState([])
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [updated, setUpdated] = useState(null)
  const [retry, setRetry] = useState(0)

  useEffect(() => {
    let cancelled = false
    // oxlint-disable-next-line react/set-state-in-effect -- Keep the last office rules visible while verifying this read.
    setLoading(true)
    smartflow.adminOffices()
      .then((d) => {
        if (!cancelled) { setOffices(d.offices || []); setError(''); setUpdated(new Date()) }
      })
      .catch((e) => {
        if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load offices')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [smartflow, retry])

  return (
    <div className="sf-life offices-page">
      <Overview
        title="Offices"
        actions={<div className="row-btns"><button type="button" className="btn-secondary" disabled={loading} onClick={() => setRetry(value => value + 1)}>{loading ? 'Refreshing…' : 'Refresh offices'}</button><Link className="btn-secondary" to="/admin/thresholds">Manage thresholds</Link></div>}
      />
      {error ? <div className="error" role="alert"><strong>{updated ? 'Office refresh failed' : 'Offices unavailable'}</strong><p>{error}</p>{updated ? <p>Previously loaded office rules may be out of date.</p> : null}<button type="button" className="btn-secondary" disabled={loading} onClick={() => setRetry(value => value + 1)}>{loading ? 'Retrying…' : 'Retry offices'}</button></div> : null}
      {loading ? <p className="muted" role="status">{updated ? 'Refreshing offices. Previously loaded rules may be out of date.' : 'Loading offices…'}</p> : null}
      {updated ? <p className="muted">{loading || error ? 'Last successful update' : 'Updated'} {updated.toLocaleTimeString()}</p> : null}
      {!loading && !error && offices.length === 0 ? (
        <LifeEmpty icon="offices">No offices configured.</LifeEmpty>
      ) : null}
      {offices.length ? (
        <div className="card sf-life__panel admin-office-table-wrap">
          <table className="admin-office-table">
            <colgroup><col /><col /><col /><col /><col /></colgroup>
            <thead>
              <tr>
                <th id="office-limits-office" scope="col">Office</th>
                <th id="office-limits-type" scope="col">Document type</th>
                <th id="office-limits-processing" scope="col" className="admin-office-table__number-heading">Processing<span>hours</span></th>
                <th id="office-limits-receipt" scope="col" className="admin-office-table__number-heading">Record receipt<span>hours</span></th>
                <th id="office-limits-actions" scope="col"><span className="sr-only">Actions</span></th>
              </tr>
            </thead>
            {offices.map((o, officeIndex) => {
              const code = String(o.office_code || '').toUpperCase()
              const thresholds = o.thresholds || []
              const rows = thresholds.length ? thresholds : [null]
              const officeHeader = `office-limits-${officeIndex}`
              return (
                <tbody key={o.office_id || code}>
                  {rows.map((rule, ruleIndex) => {
                    const ruleHeader = `${officeHeader}-rule-${ruleIndex}`
                    return (
                      <tr key={rule?.document_type || 'no-rules'}>
                        {ruleIndex === 0 ? (
                          <th id={officeHeader} scope="rowgroup" rowSpan={rows.length} headers="office-limits-office" className="admin-office-table__office">
                            <span className="admin-office-table__name">{o.office_name || code}</span>
                            <span className="admin-office-table__code">{code || '?'}</span>
                          </th>
                        ) : null}
                        {rule ? <>
                          <th id={ruleHeader} scope="row" headers={`${officeHeader} office-limits-type`} className="admin-office-table__type">{rule.document_type}</th>
                          <td headers={`${officeHeader} ${ruleHeader} office-limits-processing`} className="admin-office-table__number"><span className="admin-office-table__mobile-label" aria-hidden="true">Processing hours</span>{rule.max_hours}</td>
                          <td headers={`${officeHeader} ${ruleHeader} office-limits-receipt`} className="admin-office-table__number"><span className="admin-office-table__mobile-label" aria-hidden="true">Record receipt hours</span>{rule.out_unconfirmed_hours ?? 24}</td>
                        </> : <td colSpan={3} headers={officeHeader} className="admin-office-table__empty muted">No custom alert rules configured.</td>}
                        {ruleIndex === 0 ? (
                          <td rowSpan={rows.length} headers={`${officeHeader} office-limits-actions`} className="admin-office-table__action"><Link to={`/admin/thresholds?office=${encodeURIComponent(o.office_id)}`} aria-label={`${thresholds.length ? 'Edit' : 'Add'} limits for ${o.office_name || code}`}>{thresholds.length ? 'Edit limits' : 'Add limits'} ›</Link></td>
                        ) : null}
                      </tr>
                    )
                  })}
                </tbody>
              )
            })}
          </table>
        </div>
      ) : null}
    </div>
  )
}
