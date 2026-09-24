import { useEffect, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { DocTable, LifeEmpty, Overview, Segmented, StatusPill } from '../components/ui.jsx'

export default function AdminQrMonitorPage() {
  const [rows, setRows] = useState([])
  const [exceptions, setExceptions] = useState([])
  const [outcome, setOutcome] = useState('all')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    setError('')
    try {
      const [scans, ex] = await Promise.all([
        smartflow.auditScans({ hours: 48, outcome, limit: 200 }),
        smartflow.auditExceptions(48),
      ])
      setRows(scans.events || scans.scans || scans.logs || [])
      setExceptions(ex.exceptions || ex.items || [])
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not load QR monitor')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [outcome])

  return (
    <div className="sf-life">
      <Overview
        title="QR scan monitor"
        body="Accepted and rejected scan events from the last 48 hours."
      />
      {error ? <div className="error">{error}</div> : null}
      <div className="toolbar">
        <Segmented
          value={outcome}
          onChange={setOutcome}
          options={[
            { value: 'all', label: 'All' },
            { value: 'accepted', label: 'Accepted' },
            { value: 'rejected', label: 'Rejected' },
          ]}
        />
      </div>
      <div className="admin-grid">
        <div className="card sf-life__panel">
          <h3 className="section-title">Custody exceptions</h3>
          {exceptions.length === 0 && !loading ? (
            <LifeEmpty icon="coaSupport" tone="ok">No exceptions in the last 48h.</LifeEmpty>
          ) : null}
          {exceptions.map((ex, i) => (
            <div key={ex.document_id || i} className="pending-card">
              <strong>{ex.document_id || ex.title || 'Exception'}</strong>
              <span className="muted">{ex.detail || ex.message || ex.kind}</span>
            </div>
          ))}
        </div>
        <div className="card sf-life__panel">
          <h3 className="section-title">Scan events</h3>
          {loading ? <p className="muted">Loading…</p> : null}
          {!loading && rows.length === 0 ? (
            <LifeEmpty icon="qrMonitor">No scan events.</LifeEmpty>
          ) : (
            <DocTable
              columns={[
                { key: 'created_at', label: 'When', render: (r) => r.created_at || r.scanned_at || '—' },
                { key: 'document_id', label: 'Doc' },
                {
                  key: 'outcome',
                  label: 'Outcome',
                  render: (r) => (
                    <StatusPill tone={String(r.outcome || '').includes('reject') ? 'bad' : 'ok'}>
                      {r.outcome || '—'}
                    </StatusPill>
                  ),
                },
                { key: 'message', label: 'Detail', render: (r) => r.message || r.reason || r.event_type },
              ]}
              rows={rows}
            />
          )}
        </div>
      </div>
    </div>
  )
}
