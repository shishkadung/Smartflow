import { useAuth } from '../auth.jsx'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { ApiError } from '../api.js'
import { LifeEmpty, LifeSkeleton, Overview } from '../components/ui.jsx'

export default function AdminThresholdsPage() {
  const { smartflow } = useAuth()
  // The Offices page links here with ?office=<id> so the matching office is already selected.
  const [params] = useSearchParams()
  const requestedOffice = params.get('office') || ''
  const [offices, setOffices] = useState(null)
  const [officeId, setOfficeId] = useState('')
  const [docType, setDocType] = useState('')
  const [hours, setHours] = useState('48')
  const [receiptHours, setReceiptHours] = useState('24')
  const [loadError, setLoadError] = useState('')
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    setLoadError('')
    try {
      const d = await smartflow.adminOffices()
      const list = d.offices || []
      setOffices(list)
      const requested = list.find((o) => String(o.office_id) === requestedOffice)
      setOfficeId((prev) => prev || (requested ? String(requested.office_id) : list[0] ? String(list[0].office_id) : ''))
    } catch (e) {
      setLoadError(e instanceof ApiError ? e.message : 'Could not load thresholds')
    } finally {
      setLoading(false)
    }
  }, [smartflow, requestedOffice])

  // oxlint-disable-next-line react/set-state-in-effect -- Load authoritative rules before enabling the editor.
  useEffect(() => { load() }, [load])

  const selected = useMemo(
    () => offices?.find((o) => String(o.office_id) === String(officeId)),
    [offices, officeId],
  )
  const thresholds = selected?.thresholds || []
  const editing = thresholds.find(rule => rule.document_type.toLowerCase() === docType.trim().toLowerCase())

  function editRule(rule) {
    setDocType(rule.document_type)
    setHours(String(rule.max_hours))
    setReceiptHours(String(rule.out_unconfirmed_hours ?? 24))
    setOk('')
    setError('')
  }

  function newRule() {
    setDocType('')
    setHours('48')
    setReceiptHours('24')
    setOk('')
    setError('')
  }

  async function onSave(e) {
    e.preventDefault()
    if (saving || loading || loadError || !selected) return
    setSaving(true)
    setError('')
    setOk('')
    try {
      await smartflow.updateThreshold({
        office_id: Number(officeId),
        document_type: docType.trim(),
        max_hours: Number(hours),
        out_unconfirmed_hours: Number(receiptHours),
      })
      setOk('Thresholds saved.')
      await load()
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not save thresholds')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="sf-life thresholds-page">
      <Overview
        title="Thresholds"
      />
      {loadError ? <div className="error" role="alert"><strong>{offices ? 'Refresh failed' : 'Thresholds unavailable'}</strong><p>{loadError}</p>{offices ? <p>Previously loaded rules may be out of date. Reload them before saving.</p> : null}<button type="button" className="btn-secondary" disabled={loading || saving} onClick={load}>Retry thresholds</button></div> : null}
      {error ? <div className="error" role="alert">{error}</div> : null}
      {ok ? <div className="ok" role="status">{ok}</div> : null}
      {loading && !offices ? <LifeSkeleton rows={3} label="Loading thresholds" /> : null}
      {offices ? <>
      <label className="field threshold-office">
        <span>Office</span>
        <select value={officeId} onChange={e => { setOfficeId(e.target.value); newRule() }} disabled={saving || loading} required>
          {offices.map(o => <option key={o.office_id} value={o.office_id}>{o.office_name} ({o.office_code})</option>)}
        </select>
      </label>
      <div className="admin-grid">
      <div className="card sf-life__panel threshold-panel threshold-rules">
        <div className="clarity-panel-heading threshold-panel-heading"><div><h3 className="section-title">Current rules</h3><p className="muted finishing-section-lead">{selected?.office_name} · {thresholds.length} custom {thresholds.length === 1 ? 'rule' : 'rules'}</p></div><button type="button" className="btn-secondary" disabled={saving || loading} onClick={newRule}>Add a rule</button></div>
        {thresholds.length === 0 ? <LifeEmpty icon="thresholds">No custom rules for this office. Default limits are 48 processing hours and 24 hours to record receipt.</LifeEmpty> : <ul className="admin-threshold-list">
          {thresholds.map(rule => <li key={rule.document_type} className={editing === rule ? 'is-editing' : ''}>
            <div className="threshold-rule-copy"><strong>{rule.document_type}</strong><span>{rule.max_hours} hours at the office</span><span>{rule.out_unconfirmed_hours ?? 24} hours to record receipt after sending</span></div>
            <button type="button" className="btn-secondary" disabled={saving || loading} onClick={() => editRule(rule)}>Edit<span className="visually-hidden"> {rule.document_type}</span></button>
          </li>)}
        </ul>}
      </div>
      <form className="card sf-life__panel form-card threshold-panel" onSubmit={onSave}>
        <div className="clarity-panel-heading threshold-panel-heading"><div>
          <h3 className="section-title">{editing ? `Edit ${editing.document_type}` : 'Add a time-limit rule'}</h3>
          <p className="muted finishing-section-lead">Set processing and receipt limits separately for {selected?.office_name || 'the selected office'}.</p>
        </div></div>
        <fieldset disabled={saving || loading || Boolean(loadError)} className="threshold-fields">
        <label className="field">
          <span>Document type</span>
          <input
            value={docType}
            onChange={e => {
              const matching = thresholds.find(rule => rule.document_type.toLowerCase() === e.target.value.trim().toLowerCase())
              if (matching) editRule(matching)
              else setDocType(e.target.value)
            }}
            placeholder="e.g. Disbursement Voucher"
            list="threshold-document-types"
            maxLength={50}
            required
          />
          <datalist id="threshold-document-types">{[...new Set(['Disbursement Voucher', 'Approved Budget', ...thresholds.map(rule => rule.document_type)])].map(type => <option value={type} key={type} />)}</datalist>
        </label>
        <label className="field">
          <span>Processing hours at the office</span>
          <input
            type="number"
            min="1"
            max="720"
            step="1"
            value={hours}
            onChange={(e) => setHours(e.target.value)}
            required
          />
          <span className="field-help">Calendar hours from receipt to an overdue alert. 48 hours = 2 days. 1–720 hours.</span>
        </label>
        <label className="field">
          <span>Hours to record receipt after sending</span>
          <input type="number" min="1" max="168" step="1" value={receiptHours} onChange={e => setReceiptHours(e.target.value)} required />
          <span className="field-help">Calendar hours from this office’s send to a missing-receipt alert. 1–168 hours.</span>
        </label>
        </fieldset>
        <button className="btn btn--navy" type="submit" disabled={saving || loading || Boolean(loadError) || !officeId}>
          {saving ? 'Saving…' : editing ? 'Save changes' : 'Save thresholds'}
        </button>
      </form>
      </div>
      </> : null}
    </div>
  )
}
