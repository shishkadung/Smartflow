import { useEffect, useMemo, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { LifeEmpty, Overview } from '../components/ui.jsx'

export default function AdminThresholdsPage() {
  const [offices, setOffices] = useState([])
  const [officeId, setOfficeId] = useState('')
  const [docType, setDocType] = useState('')
  const [hours, setHours] = useState('48')
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  async function load() {
    setLoading(true)
    setError('')
    try {
      const d = await smartflow.adminOffices()
      const list = d.offices || []
      setOffices(list)
      setOfficeId((prev) => prev || (list[0] ? String(list[0].office_id) : ''))
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not load thresholds')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  const selected = useMemo(
    () => offices.find((o) => String(o.office_id) === String(officeId)),
    [offices, officeId],
  )
  const thresholds = selected?.thresholds || []

  async function onSave(e) {
    e.preventDefault()
    setSaving(true)
    setError('')
    setOk('')
    try {
      await smartflow.updateThreshold({
        office_id: Number(officeId),
        document_type: docType.trim(),
        max_hours: Number(hours),
      })
      setOk('Threshold saved.')
      setDocType('')
      await load()
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not save threshold')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="sf-life">
      <Overview
        title="Thresholds"
        body="Max hours per office and document type."
      />
      {error ? <div className="error">{error}</div> : null}
      {ok ? <div className="ok">{ok}</div> : null}
      {loading ? <p className="muted">Loading…</p> : null}

      <form className="card sf-life__panel form-card" onSubmit={onSave}>
        <label className="field">
          <span>Office</span>
          <select value={officeId} onChange={(e) => setOfficeId(e.target.value)} required>
            {offices.map((o) => (
              <option key={o.office_id} value={o.office_id}>
                {o.office_name} ({o.office_code})
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span>Document type</span>
          <input
            value={docType}
            onChange={(e) => setDocType(e.target.value)}
            placeholder="e.g. Disbursement Voucher"
            required
          />
        </label>
        <label className="field">
          <span>Max hours</span>
          <input
            type="number"
            min="1"
            value={hours}
            onChange={(e) => setHours(e.target.value)}
            required
          />
        </label>
        <button className="btn btn--navy" type="submit" disabled={saving || !officeId}>
          {saving ? 'Saving…' : 'Save threshold'}
        </button>
      </form>

      <div className="card sf-life__panel">
        <h3 className="section-title">Current thresholds</h3>
        {!selected || thresholds.length === 0 ? (
          <LifeEmpty icon="thresholds" tone="ok">No thresholds for this office yet.</LifeEmpty>
        ) : (
          <ul className="admin-threshold-list">
            {thresholds.map((t, i) => (
              <li key={`${t.document_type}-${i}`}>
                <strong>{t.document_type}</strong>
                <span className="muted">{t.max_hours} hours at this desk</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}
