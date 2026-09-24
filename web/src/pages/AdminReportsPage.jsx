import { useEffect, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, Overview } from '../components/ui.jsx'

function pct(bucket) {
  if (bucket == null) return '—'
  if (typeof bucket === 'object' && bucket.percent != null) return `${Math.round(bucket.percent)}%`
  return String(bucket)
}

export default function AdminReportsPage() {
  const { user } = useAuth()
  const [month, setMonth] = useState(() => new Date().toISOString().slice(0, 7))
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [copied, setCopied] = useState(false)

  async function load() {
    setError('')
    try {
      const res = await smartflow.reportsSummary(user.office_id, month)
      setData(res)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not load custody summary')
    }
  }

  useEffect(() => { load() }, [month, user.office_id])

  function copySummary() {
    const c = data?.compliance || {}
    const text = [
      `Custody support summary · ${month}`,
      `Office: ${user.office_name} (${user.office_code})`,
      `On-time handoffs: ${pct(c.on_time ?? c.completed_on_time)}`,
      `Unforwarded OUT: ${pct(c.unforwarded)}`,
      `Delayed: ${pct(c.delayed)}`,
      '',
      'Source: SmartFlow scan logs (custody). Not a COA financial package.',
    ].join('\n')
    navigator.clipboard?.writeText(text)
    setCopied(true)
    setTimeout(() => setCopied(false), 1500)
  }

  const compliance = data?.compliance || {}

  return (
    <div className="sf-life">
      <Overview
        title="Custody support summary"
        body="Monthly handoff metrics from scan logs — not a COA financial review."
        actions={(
          <button type="button" className="btn sf-life__cta" onClick={copySummary} disabled={!data}>
            {copied ? 'Copied' : 'Copy summary'}
          </button>
        )}
      />
      {error ? <div className="error">{error}</div> : null}
      <div className="toolbar">
        <div className="field" style={{ marginBottom: 0, minWidth: 180 }}>
          <label>Month</label>
          <input type="month" value={month} onChange={(e) => setMonth(e.target.value)} />
        </div>
      </div>
      <div className="stats sf-life__stats">
        <div className="stat stat--ok">
          <b>{pct(compliance.on_time ?? compliance.completed_on_time)}</b>
          <span>On time</span>
        </div>
        <div className="stat stat--warn">
          <b>{pct(compliance.unforwarded)}</b>
          <span>Unforwarded</span>
        </div>
        <div className="stat stat--bad">
          <b>{pct(compliance.delayed)}</b>
          <span>Delayed</span>
        </div>
      </div>
      <div className="card sf-life__panel">
        <h3 className="section-title">By office</h3>
        {(data?.office_totals || []).length === 0 ? (
          <LifeEmpty icon="coa">No office totals for this month.</LifeEmpty>
        ) : (
          (data?.office_totals || []).map((row) => (
            <div key={row.office_id || row.office_code} className="list-item list-item--static">
              <strong>{row.office_name || row.office_code}</strong>
              <span className="muted">Processed {row.docs_processed ?? row.processed ?? '—'}</span>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
