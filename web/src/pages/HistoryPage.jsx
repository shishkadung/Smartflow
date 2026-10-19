import { useCallback, useEffect, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { ApiError } from '../api.js'
import { UserAvatar } from '../components/UserAvatar.jsx'
import { useAuth } from '../auth.jsx'
import { formatWhen, movementNote, parseTrackingId } from '../tracking.js'
import { LifeEmpty, LifeSkeleton, Overview, Segmented } from '../components/ui.jsx'
import { SfIcon } from '../icons.jsx'
import { useLiveRefresh } from '../live-refresh.js'

function localDate() {
  const date = new Date()
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

function trailEvents(doc, rows) {
  const events = []
  const registered = doc?.registered_by
  if (registered?.name) {
    events.push({
      key: 'registered',
      at: registered.registered_at || '',
      title: registered.office_name ? `Registered at ${registered.office_name}` : 'Registered',
      name: registered.name,
      avatar: registered.avatar_url,
      kind: 'registered',
    })
  }
  for (const request of doc?.linked_requests || []) {
    if (!request?.user_name) continue
    events.push({
      key: `request-${request.id}`,
      at: request.created_at || '',
      title: request.purpose || 'Request',
      name: request.user_name,
      detail: request.office_name,
      avatar: request.avatar_url,
      kind: 'request',
    })
  }
  for (const movement of rows || []) {
    const status = String(movement.status || '').toUpperCase()
    const received = status === 'IN'
    const dest = movement.destination_office_name
    const { note } = movementNote(movement)
    events.push({
      key: `move-${movement.id}`,
      at: movement.scanned_at || '',
      title: received
        ? `Received at ${movement.office_name || 'office'}`
        : (dest ? `Sent to ${dest}` : `Sent from ${movement.office_name || 'office'}`),
      name: movement.user_name || movement.username || 'Staff',
      avatar: movement.avatar_url,
      note,
      kind: received ? 'in' : 'out',
    })
    for (const correction of movement.destination_corrections || []) events.push({
      key: `correction-${correction.id}`, at: correction.corrected_at,
      title: `Destination corrected: ${correction.previous_destination_office_name} → ${correction.destination_office_name}`,
      name: correction.corrected_by_name, detail: correction.corrected_by_office_name,
      note: correction.reason, kind: 'correction',
    })
  }
  const filed = doc?.filed_by
  if (filed?.filed_at) {
    events.push({
      key: 'filed',
      at: filed.filed_at,
      title: filed.office_name ? `Filed at ${filed.office_name}` : 'Filed',
      // Older filings may predate the recorded filer; keep the event rather than hiding a completed folder's last step.
      name: filed.name || 'Staff (name not recorded)',
      avatar: filed.avatar_url,
      note: 'Folder filed. The route is finished.',
      kind: 'filed',
    })
  }
  events.sort((a, b) => String(a.at).localeCompare(String(b.at)))
  return events
}

function statusPill(status) {
  const s = String(status || '').toUpperCase()
  if (s === 'OUT') return <span className="pill pill--sent">Sent</span>
  if (s === 'IN') return <span className="pill pill--in">Received</span>
  return null
}

export default function HistoryPage() {
  const { user, smartflow } = useAuth()
  const [params, setParams] = useSearchParams()
  const view = params.get('view') === 'office' ? 'office' : 'folder'
  const presetId = params.get('id') || ''
  const [id, setId] = useState(presetId)
  const [rows, setRows] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [activitySnapshot, setActivitySnapshot] = useState(null)
  const [todayFilter, setTodayFilter] = useState('all')
  const [activityDate, setActivityDate] = useState(localDate)
  const [activityPage, setActivityPage] = useState(1)
  const [activityLoading, setActivityLoading] = useState(true)
  const [activityError, setActivityError] = useState('')
  const [retryActivity, setRetryActivity] = useState(0)
  const revision = useLiveRefresh()
  const [doc, setDoc] = useState(null)
  const [summaryError, setSummaryError] = useState('')
  const resultRef = useRef(null)
  const loadVersion = useRef(0)
  const activityKey = `${user.office_id}:${activityDate}:${activityPage}:${todayFilter}`
  const activityMeta = activitySnapshot?.key === activityKey ? activitySnapshot.data : null

  useEffect(() => {
    if (view !== 'office') return undefined
    let cancelled = false
    // oxlint-disable-next-line react/set-state-in-effect -- A changed date/page needs a newly verified server log, never the previous query's rows.
    setActivityLoading(true)
    smartflow.officeMovements(user.office_id, { date: activityDate, page: activityPage, ...(todayFilter !== 'all' ? { status: todayFilter } : {}) })
      .then((data) => {
        if (cancelled) return
        setActivitySnapshot({ key: activityKey, data })
        setActivityError('')
      })
      .catch((e) => { if (!cancelled) setActivityError(e instanceof ApiError ? e.message : 'Could not load office activity') })
      .finally(() => { if (!cancelled) setActivityLoading(false) })
    return () => { cancelled = true }
  }, [user.office_id, activityDate, activityPage, todayFilter, revision, retryActivity, view, activityKey, smartflow])

  const todayRows = activityMeta?.movements || []
  const activityTotal = activityMeta?.total ?? todayRows.length
  const currentActivityPage = activityMeta?.page ?? activityPage
  const activityPageSize = activityMeta?.page_size ?? 25

  const load = useCallback(async (tracking) => {
    const code = parseTrackingId(tracking) || String(tracking || '').trim().toUpperCase()
    if (!code) { setError('Enter a tracking ID first.'); return }
    const version = ++loadVersion.current
    setError('')
    setSummaryError('')
    setRows(null)
    setDoc(null)
    setLoading(true)
    try {
      const [data, shown] = await Promise.all([
        smartflow.documentMovements(code),
        smartflow.documentShow(code).catch(err => ({ summaryError: err.message || 'Folder summary unavailable' })),
      ])
      if (version !== loadVersion.current) return
      setRows(data.movements || [])
      setDoc(shown?.document || null)
      setSummaryError(shown?.summaryError || '')
      resultRef.current?.focus({ preventScroll: true })
    } catch (err) {
      if (version !== loadVersion.current) return
      setRows(null)
      setDoc(null)
      setError(err instanceof ApiError ? err.message : 'Could not load history')
    } finally {
      if (version === loadVersion.current) setLoading(false)
    }
  }, [smartflow])

  useEffect(() => {
    if (presetId) {
      // oxlint-disable-next-line react/set-state-in-effect -- Synchronize a directly linked folder before fetching its authorized history.
      setId(presetId)
      load(presetId)
    }
  }, [presetId, load])

  useEffect(() => () => { loadVersion.current += 1 }, [])

  function changeView(nextView) {
    const next = new URLSearchParams(params)
    if (nextView === 'office') next.set('view', 'office')
    else next.delete('view')
    setParams(next, { replace: true })
  }

  function openFolder(code) {
    const clean = parseTrackingId(code) || String(code || '').trim().toUpperCase()
    if (!clean) return
    setId(clean)
    const next = new URLSearchParams(params)
    next.set('id', clean)
    next.delete('view')
    if (clean === presetId) load(clean)
    setParams(next)
  }

  return (
    <div className="sf-life history-page">
      <Overview
        title="History"
      />
      <div className="history-views"><Segmented value={view} onChange={changeView} options={[
        { value: 'folder', label: 'Folder history' }, { value: 'office', label: 'Office activity' },
      ]} /></div>
      {view === 'folder' ? <>
        <form
          className="card sf-life__panel history-lookup"
          onSubmit={(e) => {
            e.preventDefault()
            openFolder(id)
          }}
        >
          <label className="field">Tracking ID
            <input value={id} onChange={(e) => setId(e.target.value)} placeholder="DOC-2026-000001" required />
          </label>
          <button className="btn sf-life__cta" type="submit" disabled={loading}>
            <SfIcon name="history" size={18} />
            {loading ? 'Loading…' : 'View folder history'}
          </button>
        </form>

        <section className="card sf-life__panel history-result" ref={resultRef} tabIndex={-1} aria-label="Folder history">
          <h3 className="section-title">{doc?.title || 'Folder history'}</h3>
          {doc ? <div className="history-folder-summary">
            <strong>{doc.id || id}</strong>
            <span>{doc.trail_complete ? 'Completed' : doc.current_status === 'OUT' ? 'Receipt not recorded' : 'Current office'} · {doc.current_office_name || 'Office unavailable'}</span>
            {doc.current_status === 'OUT' && doc.destination_office_name ? <span>Sent to {doc.destination_office_name}</span> : null}
            {doc.due_at_display && doc.due_at_display !== '—' && !doc.trail_complete ? <span>Deadline · {doc.due_at_display}</span> : null}
            <details><summary>Folder details</summary><p>{doc.type} · Origin: {doc.origin_office_name}</p></details>
          </div> : null}
          {error ? <div className="error" role="alert">Folder history unavailable. {error}<button type="button" className="btn-secondary" disabled={loading} onClick={() => load(id)}>Retry folder history</button></div> : null}
          {summaryError && !loading ? <div className="error" role="alert">Folder summary unavailable. {summaryError}<button type="button" className="btn-secondary" onClick={() => load(id)}>Retry folder details</button></div> : null}
          {loading ? <LifeSkeleton rows={3} label="Loading folder history" /> : error ? null : !rows ? <LifeEmpty icon="history">Enter a tracking ID to see who received or sent the folder.</LifeEmpty> : rows.length === 0 && trailEvents(doc, rows).length === 0 ? <LifeEmpty icon="history">No recorded movements for this folder.</LifeEmpty> : <HistoryTimeline document={doc} movements={rows} />}
        </section>
      </> : <section className="card sf-life__panel history-office">
          <h3 className="section-title">{user.office_name || 'Your office'} activity</h3>
          <p className="muted">Complete daily log of recorded receipts and sends. Select a folder to open its history.</p>
          <div className="history-activity-controls"><label className="field">Date<input type="date" value={activityDate} onChange={(event) => { if (event.target.value) { setActivityDate(event.target.value); setActivityPage(1) } }} /></label>
          <Segmented
            value={todayFilter}
            onChange={(value) => { setTodayFilter(value); setActivityPage(1) }}
            options={[
              { value: 'all', label: 'All', badge: !activityError ? activityMeta?.stats?.total : null },
              { value: 'IN', label: 'Received', badge: !activityError ? activityMeta?.stats?.in_flow : null },
              { value: 'OUT', label: 'Sent', badge: !activityError ? activityMeta?.stats?.out_flow : null },
            ]}
          />
          </div>
          {activityError ? <div className="error" role="alert"><strong>{activityMeta ? 'Refresh failed' : 'Office activity unavailable'}</strong><p>{activityError}{activityMeta ? ' · Showing previously loaded activity; it may be out of date.' : ''}</p><button type="button" className="btn-secondary" onClick={() => setRetryActivity((value) => value + 1)}>Retry office activity</button></div> : null}
          {activityLoading ? <LifeSkeleton rows={3} label="Loading office activity" /> : null}
          {!activityLoading && !activityError ? <p className="muted">{activityTotal} {activityTotal === 1 ? 'movement' : 'movements'}</p> : null}
          {!activityLoading && !activityError && todayRows.length === 0 ? (
            <LifeEmpty icon="history">No office activity in this filter on {activityDate}.</LifeEmpty>
          ) : !activityLoading && activityMeta && todayRows.length ? (
            <ul className="history-picks">
              {todayRows.map((m) => (
                <li key={m.id || `${m.document_id}-${m.scanned_at}`}>
                  <button type="button" onClick={() => openFolder(m.document_id)}>
                    {statusPill(m.status)}
                    <strong>{m.document_id}</strong>
                    <span>{m.title || m.office_name || ''}</span>
                    <span>{formatWhen(m.scanned_at)} · {m.user_name || 'Staff'}</span>
                    {m.status === 'OUT' && m.destination_office_name ? <span>Sent to {m.destination_office_name}</span> : null}
                    {movementNote(m).note ? <span className="history-note">{movementNote(m).note}</span> : null}
                    {(m.destination_corrections || []).map(correction => <span className="history-note" key={correction.id}><strong>Destination corrected: {correction.previous_destination_office_name} → {correction.destination_office_name}</strong><br />{correction.reason}<br />{formatWhen(correction.corrected_at)} · {correction.corrected_by_name}</span>)}
                  </button>
                </li>
              ))}
            </ul>
          ) : null}
          {!activityError && activityTotal > activityPageSize ? <div className="row-btns" aria-label="Office activity pages">
            <button type="button" className="btn-secondary" disabled={activityLoading || currentActivityPage <= 1} onClick={() => setActivityPage(currentActivityPage - 1)}>Previous</button>
            <span className="muted">Page {currentActivityPage} of {Math.ceil(activityTotal / activityPageSize)}</span>
            <button type="button" className="btn-secondary" disabled={activityLoading || !activityMeta?.has_more} onClick={() => setActivityPage(currentActivityPage + 1)}>Next</button>
          </div> : null}
      </section>}
    </div>
  )
}

export function HistoryTimeline({ document, movements }) {
  return <ul className="timeline">
              {trailEvents(document, movements).map((event) => (
                <li key={event.key} className={`timeline__item timeline__item--${event.kind}`}>
                  <div className="timeline__copy">
                    <strong>{event.title}</strong>
                    <div className="timeline__person">
                      <UserAvatar
                        name={event.name}
                        user={event.avatar ? { avatar_url: event.avatar, name: event.name } : null}
                        size="xs"
                      />
                      <span>{event.detail ? `${event.name} · ${event.detail}` : event.name}</span>
                    </div>
                    {event.note ? <p className="timeline__note">{event.note}</p> : null}
                  </div>
                  <time className="muted">{formatWhen(event.at)}</time>
                </li>
              ))}
            </ul>
}
