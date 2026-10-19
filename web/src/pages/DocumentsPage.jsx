import { useEffect, useRef, useState } from 'react'
import { Link, useLocation, useSearchParams } from 'react-router-dom'

import { useAuth } from '../auth.jsx'
import { Overview, LifeEmpty } from '../components/ui.jsx'
import DocumentQr from '../components/DocumentQr.jsx'
import DocumentSummary from '../components/DocumentSummary.jsx'
import DocumentList from '../components/DocumentList.jsx'
import { SfIcon } from '../icons.jsx'
import DocumentJourney from '../components/DocumentJourney.jsx'
import DestinationCorrection from '../components/DestinationCorrection.jsx'
import { useFolderReceipt } from '../components/FolderContents.jsx'
import { documentQueue } from '../document-queue.js'
import { loadDocumentDetail } from '../document-detail.js'
import { useLiveRefresh } from '../live-refresh.js'
import { movementDestination } from '../tracking.js'
import FolderHandoff from '../components/FolderHandoff.jsx'
import { preferredForwardDestination, recordConfirmedFiling, recordConfirmedReceipt, requestReturnPath } from '../custody-actions.js'
import { beginScopedRead, failScopedRead, scopedReadView } from '../scoped-read.js'
import { useFolderFiling } from '../components/FolderFiling.jsx'

const trays = { incoming: 'Incoming', in_office: 'At your office', forwarded: 'Forwarded', completed: 'Completed' }

function nextMove(doc) {
  if (doc.tray === 'completed' && !doc.can_return_to_accounting) {
    return { tone: 'ok', title: 'Filed', body: 'The route is finished. The QR and the custody history stay available.' }
  }
  if (doc.can_return_to_accounting) {
    return { tone: 'ok', title: 'Filed at Treasury', body: 'The route is finished. Return it to Accounting only if the folder goes back.' }
  }
  if (doc.tray === 'incoming') {
    return { tone: 'warn', title: 'Receive it', body: 'The folder should be in your hands. Check it, then confirm. That records the handoff.' }
  }
  if (doc.can_file) {
    return { tone: 'info', title: 'No fixed route', body: 'Send it on if another office still needs it. File it here when the work is done.' }
  }
  if (doc.suggested_forward?.office_name) {
    return { tone: 'info', title: `Send to ${doc.suggested_forward.office_name}`, body: doc.suggested_forward.reason || 'Hand over the folder, then send. They will see it as incoming.' }
  }
  if (doc.tray === 'in_office') {
    return { tone: 'info', title: 'Send it', body: 'Choose the next office and hand over the folder. They will see it as incoming.' }
  }
  return { tone: 'neutral', title: 'Waiting on the next office', body: 'They still have to confirm they received it. Opening the QR does not mark it in.' }
}

export default function DocumentsPage() {
  const { user, smartflow } = useAuth()
  const location = useLocation()
  const [params, setParams] = useSearchParams()
  const selected = (params.get('id') || '').trim().toUpperCase()
  const municipal = user.role === 'admin'
  const overdueOnly = params.get('overdue') === '1'
  const officeId = municipal ? params.get('office_id') || '' : ''
  const [search, setSearch] = useState('')
  const listKey = JSON.stringify([user.id, user.office_id, municipal, officeId])
  const [listState, setListState] = useState(null)
  const listView = scopedReadView(listState, listKey)
  const documents = listView.data || []
  const updated = listView.updated
  const listError = listView.error
  const loading = !listView.data && listView.loading
  const [doc, setDoc] = useState(null)
  // A deep-linked folder opens its own tray so the list is not an unrelated empty Incoming view; an explicit ?tray= still wins.
  const linkedTray = selected && doc?.id === selected && Object.hasOwn(trays, doc.tray) && !(municipal && doc.tray === 'incoming') ? doc.tray : ''
  // With nothing chosen yet, open the first tray that has folders instead of an empty Incoming view; an explicit ?tray= always wins.
  const busyTray = !municipal && updated && !documents.some((d) => d.tray === 'incoming') ? ['in_office', 'forwarded', 'completed'].find((key) => documents.some((d) => d.tray === key)) : ''
  const tray = Object.hasOwn(trays, params.get('tray')) ? params.get('tray') : linkedTray || busyTray || (municipal ? 'in_office' : 'incoming')
  const readOnly = user.role !== 'staff' || doc?.read_only === true
  const [offices, setOffices] = useState([])
  const [officeError, setOfficeError] = useState('')
  const [officeRetry, setOfficeRetry] = useState(0)
  const [picked, setPicked] = useState('')
  const [pickedFor, setPickedFor] = useState('')
  const [isReturn, setIsReturn] = useState(false)
  const [returnReason, setReturnReason] = useState('')
  const [busy, setBusy] = useState(false)
  const [pending, setPending] = useState('')
  const [error, setError] = useState('')
  const [detailError, setDetailError] = useState('')
  const [note, setNote] = useState('')
  const [revision, setRevision] = useState(0)
  const liveRevision = useLiveRefresh()
  const [sort, setSort] = useState('urgency')
  const [detailFresh, setDetailFresh] = useState(false)
  const movement = useRef(null)
  const { requestReceipt, receiptDialog } = useFolderReceipt()
  const { requestFiling, filingDialog } = useFolderFiling()
  const detailRef = useRef(null)
  const listRef = useRef(null)
  const returningToList = useRef(false)

  function setFilters(changes, clearSelection = true) {
    const next = new URLSearchParams(params)
    if (clearSelection) next.delete('id')
    for (const [key, value] of Object.entries(changes)) {
      if (value) next.set(key, value)
      else next.delete(key)
    }
    setParams(next, { state: clearSelection || (changes.id && changes.id !== selected) ? null : location.state })
  }

  useEffect(() => {
    if (doc?.id && window.matchMedia('(max-width: 760px)').matches) {
      detailRef.current?.focus({ preventScroll: true })
      detailRef.current?.scrollIntoView({ block: 'start' })
    }
  }, [doc?.id])

  function closeDetails() {
    returningToList.current = true
    setFilters({ id: '' })
  }

  useEffect(() => {
    if (!selected && returningToList.current) {
      returningToList.current = false
      listRef.current?.focus()
    }
  }, [selected])

  useEffect(() => {
    let cancelled = false
    if (busy) return
    // oxlint-disable-next-line react/set-state-in-effect -- A retained list is usable only for the same authenticated office query.
    setListState(previous => beginScopedRead(previous, listKey))
    smartflow.officeDocuments(null, municipal ? { scope: 'municipal', current_office_id: officeId || undefined } : {})
      .then((data) => { if (!cancelled) setListState({ key: listKey, data: data.documents || [], updated: new Date(), loading: false, error: '' }) })
      .catch((e) => { if (!cancelled) setListState(previous => failScopedRead(previous, listKey, e.message || 'Could not load documents.')) })
    return () => { cancelled = true }
  }, [revision, liveRevision, user.office_id, municipal, officeId, busy, listKey, smartflow])

  useEffect(() => {
    // oxlint-disable-next-line react/set-state-in-effect -- A different folder must clear confirmation and action state before it can be edited.
    setDoc(null)
    movement.current = null
    setIsReturn(false)
    setReturnReason('')
    setPicked('')
    setPickedFor('')
    setDetailFresh(false)
    setDetailError('')
  }, [selected, user.office_id])

  useEffect(() => {
    let cancelled = false
    if (!selected || busy) return
    // oxlint-disable-next-line react/set-state-in-effect -- Disable custody writes until the current server snapshot is verified.
    setDetailFresh(false)
    if (selected) loadDocumentDetail(selected, municipal, smartflow)
      .then((data) => { if (!cancelled) {
        if (movement.current !== data.document.last_movement_id) { setPicked(''); setPickedFor(''); setIsReturn(false); setReturnReason('') }
        movement.current = data.document.last_movement_id
        setDoc({ ...data.document, read_only: data.read_only === true })
        setDetailFresh(true)
        setDetailError('')
      } })
      .catch((e) => { if (!cancelled) setDetailError(e.message) })
    return () => { cancelled = true }
  }, [selected, revision, liveRevision, user.office_id, municipal, busy, smartflow])

  useEffect(() => {
    let cancelled = false
    smartflow.offices().then((data) => { if (!cancelled) { setOffices(data.offices || []); setOfficeError('') } })
      .catch((e) => { if (!cancelled) setOfficeError(e.message || 'Could not load receiving offices.') })
    return () => { cancelled = true }
  }, [officeRetry, smartflow])

  async function move(status) {
    if (!doc || doc.id !== selected || busy || !detailFresh || readOnly) return
    setBusy(true)
    setPending(status)
    setError('')
    setNote('')
    try {
      const body = {
        document_id: doc.id, office_id: user.office_id, status,
        movement_source: 'system', expected_movement_id: doc.last_movement_id,
        ...(status === 'OUT' ? movementDestination({ destinationOfficeId: destination, isReturn, returnReason }) : {}),
      }
      const data = status === 'IN'
        ? await recordConfirmedReceipt(doc, requestReceipt, smartflow.recordMovement, body)
        : await smartflow.recordMovement(body)
      if (!data) return
      setNote(data.message)
      setRevision((r) => r + 1)
    } catch (e) {
      setError(e.message)
      // Recheck custody after stale or duplicate attempts without retrying the action.
      setRevision((r) => r + 1)
    } finally { setBusy(false); setPending('') }
  }

  async function fileFolder() {
    if (!doc || doc.id !== selected || busy || !detailFresh || !doc.can_file || readOnly) return
    setBusy(true)
    setPending('file')
    setError('')
    setNote('')
    try {
      const data = await recordConfirmedFiling(doc, requestFiling, smartflow.fileDocument)
      if (!data) return
      setNote(data.message || 'Filed. This folder is done.')
      setRevision((r) => r + 1)
    } catch (e) {
      setError(e.message)
      setRevision((r) => r + 1)
    } finally { setBusy(false); setPending('') }
  }

  const rows = documentQueue(documents, { tray, overdueOnly, officeId, search, sort })
  const overdueCount = documentQueue(documents, { tray, overdueOnly: true, officeId }).length
  const step = doc ? nextMove(doc) : null
  const custodyKey = doc ? `${doc.id}:${doc.last_movement_id ?? ''}` : ''
  const preferredId = preferredForwardDestination(doc, offices)
  const destination = pickedFor === custodyKey && custodyKey ? picked : preferredId
  const requestReturnTo = selected ? requestReturnPath(location.state?.requestReturnTo) : null
  const maySend = Boolean(doc && !readOnly && (doc.tray === 'in_office' || doc.can_return_to_accounting))
  return (
    <div className={`sf-life document-page${selected ? ' document-page--selected' : ''}`}>
      {receiptDialog}
      {filingDialog}
      <Overview title="Documents" body={readOnly ? 'Monitoring only' : undefined} />
      {error || listError ? <div className="error" role="alert">{error || listError}</div> : null}
      {officeError && !maySend ? <div className="error" role="alert">Receiving offices unavailable. {officeError}<button type="button" className="btn-secondary" disabled={busy} onClick={() => setOfficeRetry(value => value + 1)}>Retry receiving offices</button></div> : null}
      {note ? <div className="ok" role="status">{note}</div> : null}
      <div className="document-toolbar">
      <div className="document-trays" role="group" aria-label="Folder view">
        {Object.entries(trays).filter(([key]) => !municipal || key !== 'incoming').map(([key, label]) => (
          <button className={`document-tray${tray === key && !overdueOnly ? ' is-active' : ''}`} aria-pressed={tray === key && !overdueOnly} key={key} type="button" disabled={busy} onClick={() => setFilters({ tray: key, overdue: '' })}>
            <span>{municipal && key === 'in_office' ? 'At offices' : label}</span><span className="document-tray__count">{updated ? documents.filter((d) => d.tray === key).length : loading ? '…' : '—'}</span>
          </button>
        ))}
        <button className={`document-tray${overdueOnly ? ' is-active' : ''}`} type="button" aria-pressed={overdueOnly} disabled={busy} onClick={() => setFilters({ overdue: '1' })}>
          <span>Overdue</span><span className="document-tray__count">{updated ? overdueCount : loading ? '…' : '—'}</span>
        </button>
      </div>
        <button className="document-refresh" type="button" aria-label="Refresh documents" title="Refresh documents" disabled={busy || loading} onClick={() => { setError(''); setRevision((r) => r + 1) }}><SfIcon name="refresh" /></button>
      </div>
      <div className="document-controls">
        <div className="document-find-controls">
        <label className="document-search"><SfIcon name="search" /><input type="search" aria-label="Search documents" placeholder="Search ID, title or reference" value={search} onChange={(e) => setSearch(e.target.value)} /></label>
        {municipal ? <label className="field municipal-office-filter"><span className="document-filter-label">Current office</span><select aria-label="Current office" value={officeId} onChange={e => setFilters({ office_id: e.target.value })}>
          <option value="">All offices</option>{offices.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
        </select></label> : null}
        </div>
        <div className="queue-controls">
          {overdueOnly ? <span className="document-view-context">{municipal ? 'Overdue folders across offices and active trays.' : 'Overdue folders across all active trays.'}</span> : null}
          <label>Sort by <select aria-label="Queue order" value={sort} onChange={e => setSort(e.target.value)}><option value="urgency">Urgency</option><option value="waiting">Longest wait</option><option value="recent">Latest movement</option></select></label>
          <span className="muted" role="status">{updated ? listError ? 'Refresh failed · displayed folders may be out of date' : `Updated ${updated.toLocaleTimeString()}` : listError ? 'Documents unavailable' : 'Waiting for server'}</span>
        </div>
      </div>
      <div className={`document-workspace${selected ? ' document-workspace--selected' : ''}`}>
        <section className="card sf-life__panel document-list-panel" aria-label="Office documents" ref={listRef} tabIndex={-1}>
          {loading ? <p>Loading documents…</p> : listError && !updated ? <p className="muted">Documents unavailable. Use Refresh to try again.</p> : rows.length ? <DocumentList documents={rows} selected={selected} busy={busy} onSelect={id => { setError(''); setNote(''); setFilters({ id }, false) }} /> : <LifeEmpty icon="history">{search.trim() ? 'No folders match your search in this view.' : overdueOnly ? 'No overdue folders in this view.' : 'No folders in this tray.'}</LifeEmpty>}
        </section>
        <section className="card sf-life__panel document-detail-panel" id="document-details" aria-label="Document details" ref={detailRef} tabIndex={-1}>
          {requestReturnTo ? <Link className="linkish" aria-disabled={busy} to={requestReturnTo} state={{ requestCreationReturnTo: requestReturnPath(location.state?.requestReturnState?.requestCreationReturnTo) }} onClick={event => { if (busy) event.preventDefault() }}>← Back to request{location.state?.requestCode ? ` · ${location.state.requestCode}` : ''}</Link> : null}
          {selected ? <button className="btn-ghost document-back" type="button" disabled={busy} onClick={closeDetails}>Back to list</button> : null}
          {detailError ? <div className="error" role="alert">Folder details unavailable. {detailError}<button className="btn-secondary" type="button" disabled={busy} onClick={() => setRevision(value => value + 1)}>Retry folder details</button></div> : null}
          {!doc ? !detailError ? <p className="muted">{selected ? 'Loading folder details…' : municipal ? 'Select a folder to review its current office and history.' : 'Select a folder to see its next step.'}</p> : null : <>
            <DocumentSummary document={doc} />
            {!readOnly ? <div className={`next-step next-step--${step.tone}`}>
              <strong>{step.title}</strong>
              <p>{step.body}</p>
            </div> : <p className="hint">{doc.tray === 'elsewhere' ? 'Tracking view · this folder is outside your office tray. Its current holding or receiving office records the handoff.' : `${municipal ? 'Municipal' : 'Office'} oversight · office staff record physical handoffs.`}</p>}
            {!detailFresh ? <p className="error" role="status">Current custody is unverified. Actions stay disabled until the server confirms this record.</p> : null}
            {readOnly ? null : doc.tray === 'completed' && !doc.can_return_to_accounting ? <p className="ok">Filed. The route is finished.</p> : doc.tray === 'incoming' ? <div className="document-action">
              <button className="btn" type="button" disabled={busy || !detailFresh} onClick={() => move('IN')}>{pending === 'IN' ? 'Receiving…' : 'Receive (IN)'}</button>
            </div> : maySend ? <FolderHandoff document={doc} offices={offices} user={user} destination={destination} isReturn={isReturn} returnReason={returnReason} disabled={busy || !detailFresh} pending={pending}
              officeError={officeError} onRetryOffices={() => setOfficeRetry(value => value + 1)}
              onDestination={value => { setPicked(value); setPickedFor(custodyKey) }}
              onMode={value => { setIsReturn(value); setReturnReason(''); setPicked(value ? '' : preferredId); setPickedFor(custodyKey) }}
              onReason={setReturnReason} onSend={() => move('OUT')} onFile={fileFolder} /> : <p className="muted">Waiting for the next office to receive it.</p>}
            <DestinationCorrection document={doc} disabled={busy || !detailFresh} onChanged={result => { setNote(result.message || 'Destination correction recorded.'); setRevision(value => value + 1) }} />
            <details className="document-secondary document-history-disclosure"><summary>Custody history</summary><DocumentJourney document={doc} /></details>
            <Link className="linkish document-activity-link" to={`/history?id=${encodeURIComponent(doc.id)}`}>Open full activity history →</Link>
            {doc.qr_payload ? <details className="document-secondary document-qr-disclosure"><summary>QR label</summary><DocumentQr id={doc.id} payload={doc.qr_payload} showId={false} /></details> : null}
          </>}
        </section>
      </div>
    </div>
  )
}
