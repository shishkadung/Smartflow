import { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { parseTrackingId } from '../tracking.js'
import { LifeEmpty, LifeSkeleton, Overview } from '../components/ui.jsx'
import { SfIcon } from '../icons.jsx'

function statusPill(status) {
  const s = String(status || '').toUpperCase()
  if (s === 'OUT') return <span className="pill pill--sent">Sent</span>
  if (s === 'IN') return <span className="pill pill--in">Received</span>
  return null
}

export default function HistoryPage() {
  const [params] = useSearchParams()
  const [id, setId] = useState(params.get('id') || '')
  const [rows, setRows] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function load(tracking) {
    setError('')
    setLoading(true)
    try {
      const code = parseTrackingId(tracking) || String(tracking || '').trim().toUpperCase()
      const data = await smartflow.documentMovements(code)
      setRows(data.movements || [])
    } catch (err) {
      setRows(null)
      setError(err instanceof ApiError ? err.message : 'Could not load history')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    const preset = params.get('id')
    if (preset) {
      setId(preset)
      load(preset)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params])

  return (
    <div className="sf-life">
      <Overview
        title="History"
        body="Look up every IN and OUT scan by tracking ID."
      />
      <div className="desk-grid desk-grid--lookup">
        <form
          className="form-card sf-life__panel"
          onSubmit={(e) => {
            e.preventDefault()
            load(id)
          }}
        >
          <h3 className="section-title">Look up trail</h3>
          <div className="field">
            <label>Document ID</label>
            <input value={id} onChange={(e) => setId(e.target.value)} placeholder="DOC-2026-000001" />
          </div>
          <button className="btn sf-life__cta" type="submit" disabled={loading}>
            <SfIcon name="history" size={18} />
            {loading ? 'Loading…' : 'Show trail'}
          </button>
        </form>
        <div className="card desk-panel sf-life__panel">
          <h3 className="section-title">Movements</h3>
          {error ? <div className="error">{error}</div> : null}
          {loading ? (
            <LifeSkeleton rows={3} label="Loading trail" />
          ) : !rows ? (
            <LifeEmpty icon="history">Enter a tracking ID to see the custody trail.</LifeEmpty>
          ) : rows.length === 0 ? (
            <LifeEmpty
              icon="history"
              tone="warn"
              action={(
                <Link className="btn-secondary as-link sf-life__empty-cta" to="/scan">
                  Open Scanner
                </Link>
              )}
            >
              No scans yet.
            </LifeEmpty>
          ) : (
            <ul className="timeline">
              {rows.map((m) => (
                <li key={m.id}>
                  <strong>{statusPill(m.status)} {m.office_name}</strong>
                  <div className="muted">
                    {m.scanned_at} · {m.user_name}
                    {m.destination_office_name ? ` → ${m.destination_office_name}` : ''}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  )
}
