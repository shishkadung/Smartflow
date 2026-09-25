import { useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { parseTrackingId } from '../tracking.js'
import { LifeEmpty, LifeSkeleton, Overview, Segmented } from '../components/ui.jsx'
import { SfIcon } from '../icons.jsx'

function statusPill(status) {
  const s = String(status || '').toUpperCase()
  if (s === 'OUT') return <span className="pill pill--sent">Sent</span>
  if (s === 'IN') return <span className="pill pill--in">Received</span>
  return null
}

export default function HistoryPage() {
  const { user } = useAuth()
  const [params] = useSearchParams()
  const [id, setId] = useState(params.get('id') || '')
  const [rows, setRows] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [desk, setDesk] = useState([])
  const [today, setToday] = useState([])
  const [deskError, setDeskError] = useState('')
  const [todayFilter, setTodayFilter] = useState('all')
  const [doc, setDoc] = useState(null)
  const [recent, setRecent] = useState(() => {
    try {
      return JSON.parse(sessionStorage.getItem('sf_recent_ids') || '[]')
    } catch {
      return []
    }
  })

  useEffect(() => {
    let cancelled = false
    smartflow.dashboardStats(user.office_id)
      .then((d) => {
        if (cancelled) return
        setDesk(d.active_documents || [])
        setToday(d.recent_movements || [])
      })
      .catch((e) => {
        if (!cancelled) setDeskError(e instanceof ApiError ? e.message : 'Could not load office log')
      })
    return () => { cancelled = true }
  }, [user.office_id])

  const todayRows = useMemo(() => {
    if (todayFilter === 'all') return today
    return today.filter((m) => String(m.status || '').toUpperCase() === todayFilter)
  }, [today, todayFilter])

  async function load(tracking) {
    setError('')
    setLoading(true)
    try {
      const code = parseTrackingId(tracking) || String(tracking || '').trim().toUpperCase()
      if (!code) return
      const [data, shown] = await Promise.all([
        smartflow.documentMovements(code),
        smartflow.documentShow(code).catch(() => null),
      ])
      setRows(data.movements || [])
      setDoc(shown?.document || null)
      setRecent((prev) => {
        const next = [code, ...prev.filter((item) => item !== code)].slice(0, 5)
        sessionStorage.setItem('sf_recent_ids', JSON.stringify(next))
        return next
      })
    } catch (err) {
      setRows(null)
      setDoc(null)
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
        body="Office log and a full trail for any tracking ID."
      />
      <div className="desk-grid desk-grid--lookup">
        <div className="history-side">
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

        {recent.length > 0 ? (
          <div className="card sf-life__panel">
            <h3 className="section-title">Recent IDs</h3>
            <ul className="history-picks">
              {recent.map((code) => (
                <li key={code}>
                  <button type="button" onClick={() => { setId(code); load(code) }}>
                    <strong>{code}</strong>
                  </button>
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <div className="card sf-life__panel">
          <h3 className="section-title">Still on desk</h3>
          {deskError ? <div className="error">{deskError}</div> : null}
          {desk.length === 0 ? (
            <LifeEmpty icon="custodyLog">No folders IN at this office right now.</LifeEmpty>
          ) : (
            <ul className="history-picks">
              {desk.map((doc) => {
                const docId = doc.document_id || doc.id
                return (
                  <li key={docId}>
                    <button type="button" onClick={() => { setId(docId); load(docId) }}>
                      <strong>{docId}</strong>
                      <span>{doc.title || doc.type || 'Folder'}</span>
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </div>

        <div className="card sf-life__panel">
          <h3 className="section-title">Today</h3>
          <Segmented
            value={todayFilter}
            onChange={setTodayFilter}
            options={[
              { value: 'all', label: 'All' },
              { value: 'IN', label: 'Received' },
              { value: 'OUT', label: 'Sent' },
            ]}
          />
          {todayRows.length === 0 ? (
            <LifeEmpty icon="history">No scans in this filter today.</LifeEmpty>
          ) : (
            <ul className="history-picks">
              {todayRows.map((m) => (
                <li key={m.id || `${m.document_id}-${m.scanned_at}`}>
                  <button type="button" onClick={() => { setId(m.document_id); load(m.document_id) }}>
                    {statusPill(m.status)}
                    <strong>{m.document_id}</strong>
                    <span>{m.title || m.office_name || ''}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
        </div>
        <div className="card desk-panel sf-life__panel">
          <h3 className="section-title">Movements</h3>
          {doc ? (
            <div className="register-success" style={{ marginBottom: 12 }}>
              <p className="register-kv"><span>Title</span><strong>{doc.title}</strong></p>
              <p className="register-kv"><span>Type</span><strong>{doc.type}</strong></p>
              <p className="register-kv"><span>Origin</span><strong>{doc.origin_office_name}</strong></p>
              {doc.due_at_display && doc.due_at_display !== '—' ? (
                <p className="register-kv"><span>Due</span><strong>{doc.due_at_display}</strong></p>
              ) : null}
            </div>
          ) : null}
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
              No movements for this ID.
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
