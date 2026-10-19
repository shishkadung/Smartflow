import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useLocation, useSearchParams } from 'react-router-dom'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, LifeSkeleton, Modal, Overview, StatusPill } from '../components/ui.jsx'
import { documentRequestCategoriesForOffice, documentTypesForOffice, formatWhen, statusLabel } from '../tracking.js'
import { useLiveRefresh } from '../live-refresh.js'
import CreationRecovery from '../components/CreationRecovery.jsx'
import { createdRequestNavigation, requestReturnPath, requestViewFromSearch, requestViewParams } from '../request-navigation.js'
import { requestReturnPath as validRequestPath } from '../custody-actions.js'
import '../requests-clarity.css'
import { beginScopedRead, failScopedRead, scopedReadView } from '../scoped-read.js'

function todayPlus(days) {
  const d = new Date()
  d.setDate(d.getDate() + days)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function toneForStatus(status) {
  if (status === 'approved') return 'info'
  if (status === 'fulfilled') return 'ok'
  if (status === 'pending') return 'warn'
  if (status === 'rejected') return 'bad'
  return 'neutral'
}

const isDisbursement = (req) => req?.document_category === 'disbursement'
const isHandler = (req, user) => user.role === 'admin' || Number(req?.handler_office?.office_id) === Number(user.office_id)
const canClose = (req, user) => isDisbursement(req)
  ? user.role === 'admin' || user.office_code === 'TRE'
  : isHandler(req, user)
const requestTypeLabel = (req) => req.document_category === 'disbursement' ? 'Disbursement / DV'
  : req.document_category === 'budget' ? 'Budget'
    : req.document_category === 'general' ? 'General pull request' : 'Others'

function useDesktopWorkspace() {
  const [desktop, setDesktop] = useState(() => typeof window !== 'undefined' && window.matchMedia('(min-width: 1101px)').matches)
  useEffect(() => {
    const media = window.matchMedia('(min-width: 1101px)')
    const update = () => setDesktop(media.matches)
    media.addEventListener('change', update)
    return () => media.removeEventListener('change', update)
  }, [])
  return desktop
}

function requestActionsFor(req, user) {
  const actions = []
  if (req?.status === 'pending' && isHandler(req, user)) actions.push('approve', 'reject')
  if (req?.status === 'approved' && canClose(req, user)) actions.push('fulfill')
  if (Number(req?.requester?.user_id) === Number(user.id) && ['pending', 'approved'].includes(req?.status)) actions.push('cancel')
  return actions
}

function requestNextStepCue(req, user) {
  if (req?.status === 'pending') return isHandler(req, user) ? 'Needs your decision' : 'Waiting for the receiving office'
  if (req?.status === 'approved') {
    if (isDisbursement(req)) return canClose(req, user) ? 'Record payment release when paid' : 'Waiting for Treasury to record release'
    return canClose(req, user) ? 'Close when the work is complete' : 'In progress'
  }
  return ''
}

export function RequestActions({ req, user, saving, verifying = false, onAction }) {
  const actions = requestActionsFor(req, user)
  if (!actions.length) return null
  const locked = saving || verifying
  return <div className="row-btns request-actions">
    {actions.includes('approve') ? <>
      <button type="button" className="btn" disabled={locked} onClick={() => onAction(req, 'approve')}>{saving ? 'Saving…' : 'Accept request'}</button>
      <button type="button" className="btn-danger" disabled={locked} onClick={() => onAction(req, 'reject')}>Decline</button>
    </> : null}
    {actions.includes('fulfill') ? (
      <button type="button" className="btn" disabled={locked} onClick={() => onAction(req, 'fulfill')}>
        {isDisbursement(req) ? 'Mark payment released' : 'Close request'}
      </button>
    ) : null}
    {actions.includes('cancel') ? (
      <button type="button" className="btn-ghost" disabled={locked} onClick={() => onAction(req, 'cancel')}>Cancel request</button>
    ) : null}
  </div>
}

export function RequestDetails({ req, user, saving = false, onLink, onNew, returnTo, returnState }) {
  const handler = isHandler(req, user)
  const linked = req.related_document_id
  const types = documentTypesForOffice(user.office_code)
  const folderPath = `/documents?id=${encodeURIComponent(linked || '')}`
  const historyPath = `/history?id=${encodeURIComponent(linked || '')}`
  const folderState = { requestReturnTo: returnTo || requestReturnPath({}, req.id), requestCode: req.request_code, ...(returnState ? { requestReturnState: returnState } : {}) }
  const advice = req.status === 'pending'
    ? (handler ? 'Read the full purpose before accepting or declining this request.' : 'Waiting for the receiving office to review your request.')
    : req.status === 'approved'
      ? (isDisbursement(req) ? 'Accounting has accepted the request. Treasury marks payment released after the payment is actually released.' : handler ? 'Complete the requested work, then close this ticket. Record any physical folder handoff separately in Documents.' : 'The handling office accepted your request. It remains active until the requested work is complete.')
      : req.status === 'rejected'
        ? 'Read the decision notes below. Submit a new request if the purpose or supporting information needs correction.'
        : req.status === 'fulfilled'
          ? (isDisbursement(req) ? 'Payment release was recorded. The linked folder journey remains available.' : 'This request is closed. Its notes and folder journey remain available.')
          : 'This request was cancelled.'
  return <>
    <div className="request-card__top">
      <strong>{req.request_code}</strong>
      <StatusPill tone={toneForStatus(req.status)}>{statusLabel(req.status, req.document_category)}</StatusPill>
    </div>
    {req.is_overdue ? <p className="error">Overdue — required by {req.required_by_display || req.required_by}. This request is still awaiting completion.</p> : null}
    <section className="request-purpose" aria-label="Full request purpose"><h4>Purpose</h4><p>{req.purpose}</p></section>
    <div className="request-next-step">
      <h4>{['pending', 'approved'].includes(req.status) ? 'Next step' : 'Outcome'}</h4><p>{advice}</p>
      {req.status === 'approved' && handler && !linked ? <>
        <p className="hint">If this request involves a physical folder, select an existing folder{user.role === 'staff' ? ' or register the folder already at your office' : ''}. Linking does not close the request or record a handoff.</p>
        <div className="row-btns">
          <button type="button" className="btn-secondary" disabled={saving} onClick={() => onLink?.(req)}>Select existing folder</button>
          {user.role === 'staff' && types.length && Number(req.handler_office?.office_id) === Number(user.office_id) ? <Link className="btn-ghost" aria-disabled={saving} onClick={(event) => { if (saving) event.preventDefault() }} to={`/register?request_id=${req.id}`}>Register folder</Link> : null}
        </div>
      </> : null}
      {req.status === 'rejected' && Number(req.requester?.user_id) === Number(user.id) ? <button type="button" className="btn-secondary" disabled={saving} onClick={onNew}>New request</button> : null}
    </div>
    <dl className="request-details">
      <div><dt>Requested by</dt><dd>{req.requester?.name || req.requester?.username || '—'}<br />{req.requester?.office_name || req.requester?.office_code || '—'}</dd></div>
      <div><dt>Handled by</dt><dd>{req.handler_office?.office_name || req.handler_office?.office_code || '—'}</dd></div>
      <div><dt>Request type</dt><dd>{requestTypeLabel(req)}</dd></div>
      <div><dt>Required by</dt><dd>{req.required_by_display || req.required_by || '—'}</dd></div>
      <div><dt>Submitted</dt><dd>{formatWhen(req.created_at) || '—'}</dd></div>
      <RequestDecisionHistory request={req} />
      {linked ? <div className="request-details__wide"><dt>Linked folder</dt><dd><Link to={folderPath} state={folderState} aria-disabled={saving} onClick={(event) => { if (saving) event.preventDefault() }}>{linked} · Open in Documents</Link><br /><Link className="linkish" to={historyPath} aria-disabled={saving} onClick={(event) => { if (saving) event.preventDefault() }}>View custody history</Link></dd></div> : null}
    </dl>
  </>
}

export function RequestDecisionHistory({ request: req }) {
  const terminal = req.status === 'fulfilled' || req.status === 'cancelled'
  const legacy = req.review_notes_kind === 'legacy' || (terminal && !req.review_notes_kind && req.fulfilled_notes == null && req.cancelled_notes == null)
  const actor = person => person?.name || person?.username || 'Actor not recorded'
  const personLine = person => `${actor(person)}${person?.office_name || person?.office_code ? ` · ${person.office_name || person.office_code}` : ''}`
  const record = (title, notes, person, at, unknown = false, review = false) => <div className="request-details__wide request-details__notes">
    <dt>{title}</dt><dd>{notes || 'No notes recorded.'}<p className="muted">{review ? 'Reviewed' : 'Recorded'} · {personLine(person)} · {formatWhen(at) || 'Time not recorded'}</p>{unknown ? <p className="muted">This older record does not separate initial review from the final outcome. The notes and recorded metadata may refer to either stage.</p> : null}</dd>
  </div>
  return <>
    {legacy ? record('Existing recorded notes', req.review_notes, req.reviewer, req.reviewed_at, true) : req.reviewed_at || req.reviewer || req.review_notes
      ? record(req.status === 'rejected' ? 'Reason for declining' : 'Review notes', req.review_notes, req.reviewer, req.reviewed_at, false, true)
      : <div><dt>Review</dt><dd>No review recorded.</dd></div>}
    {req.status === 'fulfilled' ? record(isDisbursement(req) ? 'Payment release notes' : 'Closing notes', req.fulfilled_notes, req.fulfiller, req.fulfilled_at) : null}
    {req.status === 'cancelled' ? record('Cancellation notes', req.cancelled_notes, req.canceller, req.cancelled_at) : null}
  </>
}

export function RequestDetailPanel({ req, selectedId, user, busy, loading, error, onClose, onAction, onNew, returnTo, returnState, fresh = true, onRetry }) {
  return <section className="card sf-life__panel request-workspace__detail" id="request-workspace-detail" aria-label="Request details">
    <div className="request-workspace__heading">
      <h3 className="section-title">Request details</h3>
      {selectedId ? <button type="button" className="btn-ghost" disabled={busy} onClick={onClose}>Clear selection</button> : null}
    </div>
    <div className="request-workspace__body" role="region" aria-label="Request information" tabIndex={0}>
      {selectedId && !fresh ? <div className={error ? 'error' : 'hint'} role="status">{error ? `Latest request details unavailable. ${error}` : 'Checking the latest details. Actions unlock when this finishes.'}{onRetry && error ? <button type="button" className="btn-secondary" disabled={loading || busy} onClick={onRetry}>Retry request details</button> : null}</div> : null}
      {req ? <RequestDetails req={req} user={user} saving={busy || !fresh} onLink={(request) => onAction(request, 'link')} onNew={onNew} returnTo={returnTo} returnState={returnState} /> : selectedId ? loading ? <LifeSkeleton rows={3} label="Loading request" /> : <p className="muted" role="status">{error || 'This request is unavailable in your inbox or My requests.'}</p> : error ? <p className="muted" role="status">Load the requests before selecting a ticket to review.</p> : <LifeEmpty icon="requests">Select a request to read its full purpose, review notes, and next step.</LifeEmpty>}
    </div>
    {requestActionsFor(req, user).length ? <div className="request-workspace__actions"><RequestActions req={req} user={user} saving={busy} verifying={!fresh} onAction={onAction} /></div> : null}
  </section>
}

function FolderSelector({ req, user, value, onChange, disabled }) {
  const { smartflow } = useAuth()
  const category = req.document_category
  const id = req.id
  const handlerOffice = Number(req.handler_office?.office_id)
  const municipal = user.role === 'admin' && handlerOffice !== Number(user.office_id)
  const [documents, setDocuments] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [retry, setRetry] = useState(0)
  useEffect(() => {
    let cancelled = false
    smartflow.officeDocuments(undefined, municipal ? { scope: 'municipal', current_office_id: handlerOffice } : {}).then((data) => {
      if (!cancelled) setDocuments((data.documents || []).filter((doc) => category === 'budget'
        ? doc.type === 'Approved Budget'
        : category === 'disbursement' ? doc.type === 'Disbursement Voucher'
          : category !== 'other' || String(doc.type).startsWith('Others:')))
    }).catch((e) => { if (!cancelled) setError(e.message || 'Could not load office folders.') })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [id, category, retry, municipal, handlerOffice, smartflow])
  return <div className="field request-link-field">
    <label htmlFor="request-folder">{municipal ? `Folder at ${req.handler_office?.office_name || req.handler_office?.office_code || 'the handling office'}` : 'Folder from your office'}</label>
    {loading ? <p className="muted" role="status">Loading matching folders…</p> : error ? <div className="error" role="alert">{error} <button type="button" className="btn-ghost" onClick={() => { setLoading(true); setError(''); setRetry((v) => v + 1) }}>Try again</button></div> : <>
      <select id="request-folder" value={value} disabled={disabled || !documents.length} onChange={(e) => onChange(e.target.value)}>
        <option value="">{documents.length ? 'Select a folder' : 'No matching folders in your office'}</option>
        {documents.map((doc) => <option key={doc.id} value={doc.id}>{doc.id} · {doc.title}{doc.reference_no ? ` · ${doc.reference_no}` : ''}</option>)}
      </select>
      {!documents.length ? <p className="hint">Register a folder only if it is already on your desk. Requests without a physical folder can be closed with notes.</p> : null}
    </>}
  </div>
}

export default function RequestsPage() {
  const { user, smartflow } = useAuth()
  const location = useLocation()
  const [params, setParams] = useSearchParams()
  const query = params.toString()
  const view = useMemo(() => requestViewFromSearch(query), [query])
  const { tab, filter: inboxFilter, q: search, page, id: selectedId } = view
  const desktop = useDesktopWorkspace()
  const revision = useLiveRefresh()
  const loadSequence = useRef(0)
  const mutation = useRef(false)
  const listKey = useMemo(() => JSON.stringify([user.id, user.office_id, tab, inboxFilter, search, page]), [user.id, user.office_id, tab, inboxFilter, search, page])
  const [listState, setListState] = useState(null)
  const listView = scopedReadView(listState, listKey)
  const inbox = listView.data?.inbox || []
  const outbox = listView.data?.outbox || []
  const listMeta = listView.data?.meta || { inbox: {}, outbox: {} }
  const error = listView.error
  const loading = !listView.data && listView.loading
  const updated = listView.updated
  const detailKey = useMemo(() => JSON.stringify([user.id, user.office_id, selectedId]), [user.id, user.office_id, selectedId])
  const [detailState, setDetailState] = useState(null)
  const detailView = scopedReadView(detailState, detailKey)
  const selected = detailView.data
  const detailFresh = Boolean(selected) && !detailView.loading && !detailView.error
  const [ok, setOk] = useState('')
  const [showCreate, setShowCreate] = useState(false)
  const creationView = useRef(null)
  const [dialog, setDialog] = useState(null)
  const [notes, setNotes] = useState('')
  const [relatedId, setRelatedId] = useState('')
  const [saving, setSaving] = useState(false)
  const [noticeOpen, setNoticeOpen] = useState(false)
  const [actionError, setActionError] = useState('')

  const categories = useMemo(
    () => documentRequestCategoriesForOffice(user.office_code),
    [user.office_code],
  )

  const load = useCallback(async () => {
    const sequence = ++loadSequence.current
    setListState(previous => beginScopedRead(previous, listKey))
    try {
      const filters = { page, q: search, ...(inboxFilter === 'overdue' ? { overdue: 1 } : {}) }
      const status = ['active', 'past', 'pending'].includes(inboxFilter) ? inboxFilter : undefined
      const [inData, outData] = await Promise.all([
        smartflow.documentRequestsList('inbox', status, { ...filters, page: tab === 'inbox' ? page : 1 }),
        smartflow.documentRequestsList('outbox', status, { ...filters, page: tab === 'outbox' ? page : 1 }),
      ])
      if (sequence !== loadSequence.current) return
      setListState({ key: listKey, data: { inbox: inData.requests || [], outbox: outData.requests || [], meta: { inbox: inData, outbox: outData } }, updated: new Date(), error: '', loading: false })
    } catch (e) {
      if (sequence === loadSequence.current) setListState(previous => failScopedRead(previous, listKey, e instanceof ApiError ? e.message : 'Could not load requests'))
    }
  }, [page, search, inboxFilter, tab, listKey, smartflow])

  const detailSequence = useRef(0)
  const loadSelected = useCallback(async () => {
    const sequence = ++detailSequence.current
    if (!selectedId) return
    setDetailState(previous => beginScopedRead(previous, detailKey))
    try {
      const results = await Promise.all([
        smartflow.documentRequestsList('inbox', undefined, { id: selectedId }),
        smartflow.documentRequestsList('outbox', undefined, { id: selectedId }),
      ])
      if (sequence !== detailSequence.current) return
      const request = results.flatMap(data => data.requests || []).find(row => String(row.id) === selectedId) || null
      setDetailState({ key: detailKey, data: request, error: request ? '' : 'This request is unavailable in your inbox or My requests.', loading: false, updated: new Date() })
    } catch (e) {
      if (sequence === detailSequence.current) setDetailState(previous => failScopedRead(previous, detailKey, e instanceof ApiError ? e.message : 'Could not load this request.'))
    }
  }, [selectedId, detailKey, smartflow])

  useEffect(() => {
    // oxlint-disable-next-line react/set-state-in-effect -- Remote refresh updates state after the response and preserves form input.
    if (!saving) load()
    const sequence = loadSequence
    return () => { sequence.current++ }
  }, [load, revision, saving, user.office_id, user.id])

  useEffect(() => {
    // oxlint-disable-next-line react/set-state-in-effect -- Exact-ticket freshness is independent from list availability and must be checked before decisions.
    if (!saving) loadSelected()
    const sequence = detailSequence
    return () => { sequence.current++ }
  }, [loadSelected, revision, saving])

  const detailsBusy = saving || Boolean(dialog) || noticeOpen || showCreate
  const dialogUnchanged = dialog && detailFresh && dialog.req.id === selected.id && dialog.req.status === selected.status && dialog.req.revision === selected.revision
  const returnTo = requestReturnPath({ ...view })
  const creationReturnTo = validRequestPath(location.state?.requestCreationReturnTo)
  const returnState = creationReturnTo ? { requestCreationReturnTo: creationReturnTo } : undefined
  function updateView(changes) {
    setParams(requestViewParams({ ...view, ...changes }), { state: returnState })
  }
  function openDetails(req) { if (!saving && !dialog && !noticeOpen) { setOk(''); setDetailState({ key: JSON.stringify([user.id, user.office_id, String(req.id)]), data: req, loading: true, error: '', updated: null }); if (String(req.id) === selectedId) loadSelected(); else updateView({ id: req.id }) } }
  function closeDetails() { if (!saving) { setDetailState(null); updateView({ id: '' }) } }
  function changeTab(value) { if (!saving && !dialog && !noticeOpen) { setDetailState(null); updateView({ tab: value, page: 1, id: '' }) } }
  function changeInboxFilter(value) { if (!saving && !dialog && !noticeOpen) { setDetailState(null); updateView({ filter: value, page: 1, id: '' }) } }
  function createFromRequest() { creationView.current = view; closeDetails(); setShowCreate(true) }

  function openCreatedRequest(result) {
    const target = createdRequestNavigation(result, creationView.current || view)
    setShowCreate(false)
    setDialog(null)
    setActionError('')
    setDetailState(null)
    setOk(`Request sent${result.request.request_code ? ` · ${result.request.request_code}` : ''}`)
    setParams(target.params, { state: target.state })
  }

  async function runUpdate(req, action, extra = {}) {
    if (mutation.current || !detailFresh || req.id !== selected.id) return
    mutation.current = true
    setOk('')
    setSaving(true)
    setActionError('')
    try {
      const data = await smartflow.documentRequestUpdate({
        request_id: req.id,
        action,
        expected_status: req.status,
        ...(req.revision ? { expected_revision: req.revision } : {}),
        ...extra,
      })
      if (data.request) {
        setDetailState({ key: detailKey, data: data.request, error: '', loading: false, updated: new Date() })
      }
      // Status changes can remove a row or shift paging. Retain the confirmed ticket, then rebuild the list/counts from the server.
      setListState({ key: listKey, data: null, updated: null, loading: true, error: '' })
      // Match the status labels shown on the ticket ("Accepted", "Closed") instead of the API's "approved"/"fulfilled" wording.
      setOk(
        action === 'reject'
          ? 'Declined — also notify the requester by phone or memo'
          : action === 'approve' ? 'Request accepted'
            : action === 'fulfill' ? (isDisbursement(req) ? 'Payment release recorded' : 'Request closed')
              : data.message || 'Updated',
      )
      setDialog(null)
      setNotes('')
      setRelatedId('')
      if (action === 'reject') setNoticeOpen(true)
      window.dispatchEvent(new Event('sf-refresh-requested'))
      await load()
      await loadSelected()
    } catch (e) {
      setActionError(e instanceof ApiError ? e.message : 'Could not update request')
      if (e instanceof ApiError && e.status === 409) {
        setDialog(null)
        await loadSelected()
        await load()
      }
    } finally {
      setSaving(false)
      mutation.current = false
    }
  }

  function openAction(req, action) {
    if (detailsBusy || !detailFresh) return
    setNotes('')
    setRelatedId(req.related_document_id || '')
    setActionError('')
    setDialog({ req, action })
  }

  async function confirmDialog() {
    if (!dialog || !dialogUnchanged) return
    const { req, action } = dialog
    if (action === 'reject' && !notes.trim()) {
      setActionError('Decline notes are required for the office record.')
      return
    }
    if (action === 'link' && !relatedId) { setActionError('Select a folder to link.'); return }
    await runUpdate(req, action, {
      ...(notes.trim() ? { review_notes: notes.trim() } : {}),
      // Accepting or cancelling never changes the folder link, so only link/close send it.
      ...(relatedId.trim() && (action === 'link' || action === 'fulfill') ? { related_document_id: relatedId.trim() } : {}),
    })
  }

  const rows = tab === 'inbox' ? inbox : outbox
  const meta = listMeta[tab]
  const total = meta.total ?? rows.length
  const currentPage = meta.page ?? page
  const pageSize = meta.page_size ?? 25
  const filterLabel = { active: 'Active requests', past: 'Past requests', overdue: 'Overdue active requests', pending: 'Pending review', all: 'All requests' }[inboxFilter]

  return (
    <div className={`sf-life requests-page requests-page--clear${showCreate ? ' requests-page--creating' : ''}`}>
      <Overview
        title="Requests"
        actions={updated ? <span className="requests-updated">{error ? 'Last successful update' : 'Updated'} <time dateTime={updated.toISOString()}>{updated.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</time></span> : undefined}
      />
      {error ? <div className="error" role="alert">{updated ? 'Requests may be out of date. ' : 'Requests unavailable. '}{error} <button type="button" className="btn-ghost" disabled={saving} onClick={load}>Retry</button></div> : null}
      {actionError && !dialog ? <div className="error" role="alert">{actionError}</div> : null}
      {ok ? <div className="ok" role="status">{ok}</div> : null}
      {creationReturnTo ? <Link className="linkish" to={creationReturnTo} aria-disabled={detailsBusy} onClick={event => { if (detailsBusy) event.preventDefault() }}>← Back to previous request view</Link> : null}

      <div className="toolbar request-toolbar" role="group" aria-label="Request controls">
        <button type="button" className="btn sf-life__cta request-toolbar__create" aria-expanded={showCreate} aria-controls={showCreate ? 'request-create-form' : undefined} disabled={saving || Boolean(dialog) || noticeOpen} onClick={() => { if (!showCreate) creationView.current = view; setShowCreate((v) => !v) }}>
          {showCreate ? 'Close form' : 'New request'}
        </button>
        <div className="segmented" role="group" aria-label="Request views">
          <button type="button" className={tab === 'inbox' ? 'is-active' : ''} aria-pressed={tab === 'inbox'} disabled={detailsBusy} onClick={() => changeTab('inbox')}>Inbox</button>
          <button type="button" className={tab === 'outbox' ? 'is-active' : ''} aria-pressed={tab === 'outbox'} disabled={detailsBusy} onClick={() => changeTab('outbox')}>My requests</button>
        </div>
        <label className="field request-toolbar__filters request-status-filter">Show
          <select aria-label="Request status" value={inboxFilter} disabled={detailsBusy} onChange={(event) => changeInboxFilter(event.target.value)}>
            <option value="active">Active requests</option>
            <option value="past">Past requests</option>
            <option value="overdue">Overdue active requests</option>
            <option value="all">All requests</option>
            <option value="pending">Pending review</option>
          </select>
        </label>
      </div>
      <p className="request-view-explanation">{tab === 'inbox' ? `Inbox: requests for ${user.office_name || 'your office'}${user.office_code === 'TRE' ? ', including accepted DV requests for payment-release recording' : ''}.` : 'My requests: tickets you created and sent to another office.'} {inboxFilter === 'active' ? 'Active includes pending and accepted work.' : inboxFilter === 'past' ? 'Past includes closed, declined and cancelled tickets.' : inboxFilter === 'overdue' ? 'Pending and accepted requests past their required-by date.' : ''}</p>
      <form className="toolbar request-search" role="search" onSubmit={(event) => { event.preventDefault(); if (!detailsBusy) updateView({ q: new FormData(event.currentTarget).get('q'), page: 1 }) }}>
        <div className="field"><label htmlFor="request-search">Search requests</label><input key={search} id="request-search" name="q" type="search" defaultValue={search} maxLength={200} placeholder="Request ID, purpose, or linked folder" disabled={detailsBusy} /></div>
        <button type="submit" className="btn-secondary" disabled={detailsBusy}>Search</button>
        {search ? <button type="button" className="btn-ghost" disabled={detailsBusy} onClick={() => updateView({ q: '', page: 1 })}>Clear search</button> : null}
      </form>

      {showCreate ? (
        <CreateRequestForm
          categories={categories}
          onDone={openCreatedRequest}
          onError={setActionError}
        />
      ) : null}

      <div className="request-workspace">
      <section className="card sf-life__panel request-workspace__list" aria-label={tab === 'inbox' ? 'Inbox requests' : 'My requests'}>
        <div className="request-workspace__list-heading"><h3 className="section-title">{filterLabel}</h3><span className="muted">{loading ? 'Loading…' : error && rows.length === 0 ? 'Unavailable' : `${total} ${total === 1 ? 'request' : 'requests'}`}</span></div>
        <div className="request-workspace__list-body" role="region" aria-label="Request results" tabIndex={0}>
        {loading ? <LifeSkeleton rows={3} label="Loading requests" /> : null}
        {!loading && !error && rows.length === 0 ? (
          <LifeEmpty icon="requests" tone="ok">
            {search ? 'No requests match this search in the selected view.' : inboxFilter === 'active' ? 'No active requests. Closed, declined and cancelled tickets are available under Past requests.' : inboxFilter === 'past' ? 'No closed, declined or cancelled requests in this view.' : inboxFilter === 'overdue' ? 'No overdue active requests in this view.' : inboxFilter === 'pending' ? 'No requests awaiting review.' : tab === 'outbox' ? 'You have not created any requests yet.' : 'No requests for this office yet.'}
          </LifeEmpty>
        ) : null}
        {rows.map((req) => (
          <article key={req.id} className={`request-card${String(req.id) === selectedId ? ' is-selected' : ''}`}>
            <button type="button" className="request-card__open" disabled={saving || Boolean(dialog) || noticeOpen} aria-pressed={String(req.id) === selectedId} aria-controls={desktop ? 'request-workspace-detail' : undefined} onClick={() => openDetails(req)}>
            <span className="request-card__top">
              <span className="request-card__code">{req.request_code}</span>
              <StatusPill tone={toneForStatus(req.status)}>{statusLabel(req.status, req.document_category)}</StatusPill>
            </span>
            <span className="request-card__summary">{req.purpose}</span>
            <span className="request-card__meta">
              <span>{tab === 'inbox' ? `From ${req.requester?.office_code || '—'}` : `To ${req.handler_office?.office_code || '—'}`}</span>
              <span>·</span>
              <span>{requestTypeLabel(req)}</span>
            </span>
            {requestNextStepCue(req, user) ? <span className="request-card__next">{requestNextStepCue(req, user)}</span> : null}
            {req.required_by ? <span className={`request-card__deadline${req.is_overdue ? ' is-overdue' : ''}`}>Required by {req.required_by_display || req.required_by}{req.is_overdue ? ` · awaiting ${req.status === 'approved' ? 'completion' : 'review'}` : ''}</span> : null}
            {req.related_document_id ? <span className="request-card__linked">Linked: {req.related_document_id}</span> : null}
            </button>
          </article>
        ))}
        {total > pageSize ? <div className="row-btns" aria-label="Request pages">
          <button type="button" className="btn-secondary" disabled={detailsBusy || loading || currentPage <= 1} onClick={() => updateView({ page: currentPage - 1 })}>Previous</button>
          <span className="muted">Page {currentPage} of {Math.ceil(total / pageSize)}</span>
          <button type="button" className="btn-secondary" disabled={detailsBusy || loading || !meta.has_more} onClick={() => updateView({ page: currentPage + 1 })}>Next</button>
        </div> : null}
        </div>
      </section>
      {desktop ? <RequestDetailPanel req={selected} selectedId={selectedId} user={user} busy={detailsBusy} loading={detailView.loading} error={detailView.error} fresh={detailFresh} onRetry={loadSelected} onClose={closeDetails} onAction={openAction} onNew={createFromRequest} returnTo={returnTo} returnState={returnState} /> : null}
      </div>
      <p className="request-custody-note">A request is a ticket for work. Accepting or linking it does not receive, send or complete the physical folder.</p>

      <Modal open={!desktop && Boolean(selectedId) && !dialog && !noticeOpen && !showCreate} title="Request details" onClose={closeDetails}
        footer={requestActionsFor(selected, user).length ? <RequestActions req={selected} user={user} saving={detailsBusy} verifying={!detailFresh} onAction={openAction} /> : null}>
        {creationReturnTo ? <Link className="linkish" to={creationReturnTo} aria-disabled={saving} onClick={event => { if (saving) event.preventDefault() }}>← Back to previous request view</Link> : null}
        {actionError ? <div className="error" role="alert">{actionError}</div> : null}
        {!detailFresh ? <div className={detailView.error ? 'error' : 'hint'} role="status">{detailView.error || 'Checking the latest details. Actions unlock when this finishes.'}{detailView.error ? <button type="button" className="btn-secondary" disabled={detailView.loading || saving} onClick={loadSelected}>Retry request details</button> : null}</div> : null}
        {selected ? <RequestDetails req={selected} user={user} saving={detailsBusy || !detailFresh} onLink={(req) => openAction(req, 'link')}
          onNew={createFromRequest} returnTo={returnTo} returnState={returnState} /> : detailView.loading ? <LifeSkeleton rows={3} label="Loading request" /> : null}
      </Modal>

      <Modal
        open={!!dialog}
        title={dialog?.action === 'approve' ? 'Accept request' : dialog?.action === 'cancel' ? 'Cancel request' : dialog?.action === 'reject' ? 'Decline request' : dialog?.action === 'link' ? 'Link existing folder' : isDisbursement(dialog?.req) ? 'Mark payment released' : 'Close request'}
        onClose={() => { if (!saving) setDialog(null) }}
        footer={(
          <>
            <button type="button" className="btn-secondary" disabled={saving} onClick={() => setDialog(null)}>{dialog?.action === 'cancel' ? 'Keep request' : 'Cancel'}</button>
            <button type="button" className={dialog?.action === 'reject' || dialog?.action === 'cancel' ? 'btn-danger' : 'btn'} disabled={saving || !dialogUnchanged || (dialog?.action === 'link' && !relatedId)} onClick={confirmDialog}>
              {saving
                ? 'Saving…'
                : dialog?.action === 'approve'
                  ? 'Accept request'
                  : dialog?.action === 'cancel'
                    ? 'Cancel request'
                    : dialog?.action === 'reject'
                  ? 'Decline'
                  : dialog?.action === 'link'
                    ? 'Link folder'
                  : String(dialog?.req?.document_category || '').toLowerCase() === 'disbursement'
                    ? 'Mark payment released'
                    : 'Close request'}
            </button>
          </>
        )}
      >
        {actionError ? <div className="error" role="alert">{actionError}</div> : null}
        {!dialogUnchanged && !saving ? <p className="error" role="status">{detailView.loading ? 'Verifying this request. Wait before confirming.' : 'This request changed or could not be verified. Cancel and review the latest details before deciding.'}</p> : null}
        {dialog?.action === 'link' ? <FolderSelector req={dialog.req} user={user} value={relatedId} onChange={setRelatedId} disabled={saving} /> : null}
        {dialog?.action === 'approve' ? <p>Accepting records your office&apos;s review. It does not receive, send or complete the physical folder.</p> : null}
        {dialog?.action === 'cancel' ? <p>Cancelling closes this ticket for both offices and cannot be undone. It records no physical handoff.</p> : null}
        {dialog?.action === 'fulfill' ? <>
          <p>{isDisbursement(dialog.req) ? 'Confirm only after Treasury has actually released the payment.' : 'Confirm that the requested work is complete. Closing this ticket does not record a physical handoff.'}</p>
          {dialog.req.related_document_id ? <p className="hint">Linked folder: {dialog.req.related_document_id}</p> : <p className="hint">No folder linked. If a folder is involved, cancel and select or register it from Request details first.</p>}
        </> : null}
        {dialog?.action !== 'link' ? <div className="field">
          <label>{dialog?.action === 'reject' ? 'Decline notes (required)' : dialog?.action === 'approve' ? 'Review notes (optional)' : dialog?.action === 'cancel' ? 'Cancellation notes (optional)' : 'Closing notes (optional)'}</label>
          <textarea rows={3} value={notes} disabled={saving} onChange={(e) => { setNotes(e.target.value); if (actionError) setActionError('') }} required={dialog?.action === 'reject'} />
        </div> : null}
        {dialog?.action === 'reject' ? (
          <p className="hint" style={{ margin: 0 }}>
            A separate notice (phone call or memo) to the requester is also required.
          </p>
        ) : null}
      </Modal>

      <Modal
        open={noticeOpen}
        title="Separate notice required"
        onClose={() => setNoticeOpen(false)}
        footer={(
          <button type="button" className="btn" onClick={() => setNoticeOpen(false)}>OK</button>
        )}
      >
        <p style={{ margin: 0 }}>
          Per Municipal Accountant practice, also inform the requester outside the app
          (phone call or memo). In-app status alone is not enough.
        </p>
      </Modal>
    </div>
  )
}

function CreateRequestForm({ categories, onDone, onError }) {
  const { user, smartflow } = useAuth()
  const [kind, setKind] = useState('access')
  const [category, setCategory] = useState(categories[0]?.value || 'budget')
  const [purpose, setPurpose] = useState('')
  const [requiredBy, setRequiredBy] = useState(todayPlus(7))
  const [offices, setOffices] = useState([])
  const [targetOfficeId, setTargetOfficeId] = useState('')
  const [loading, setLoading] = useState(false)
  const [officesLoading, setOfficesLoading] = useState(true)
  const [officesError, setOfficesError] = useState('')
  const [officesRetry, setOfficesRetry] = useState(0)
  const submitting = useRef(false)

  useEffect(() => {
    let cancelled = false
    smartflow.offices().then((d) => {
      if (!cancelled) setOffices((d.offices || []).filter((o) => Number(o.id) !== Number(user.office_id)))
    }).catch((e) => { if (!cancelled) setOfficesError(e.message || 'Could not load receiving offices.') })
      .finally(() => { if (!cancelled) setOfficesLoading(false) })
    return () => { cancelled = true }
  }, [user.office_id, officesRetry, smartflow])

  async function submit(e) {
    e.preventDefault()
    if (submitting.current) return
    submitting.current = true
    setLoading(true)
    onError('')
    try {
      const result = await smartflow.documentRequestCreate({
        request_kind: kind,
        document_category: kind === 'access' ? category : 'general',
        purpose: purpose.trim(),
        required_by: requiredBy,
        ...(kind === 'pull' || category === 'other'
          ? { target_office_id: Number(targetOfficeId) }
          : {}),
      })
      await onDone(result)
      window.dispatchEvent(new Event('sf-refresh-requested'))
    } catch (err) {
      onError(err.message || 'Could not create request')
    } finally {
      setLoading(false)
      submitting.current = false
    }
  }

  return (
    <form className="form-card" id="request-create-form" onSubmit={submit}>
      <h3 className="section-title">New document request</h3>
      <CreationRecovery kind="request" onRecovered={onDone} />
      <div className="form-grid">
        <div className="field">
          <label>Kind</label>
          <select value={kind} disabled={loading} onChange={(e) => setKind(e.target.value)}>
            <option value="access">By type (Budget / DV / Others)</option>
            <option value="pull">From office (pull)</option>
          </select>
        </div>
        {kind === 'access' ? (
          <div className="field">
            <label>Document type</label>
            {categories.length === 0 ? (
              <p className="muted">No access types for your office — use From office instead.</p>
            ) : (
              <select value={category} disabled={loading} onChange={(e) => setCategory(e.target.value)}>
                {categories.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            )}
          </div>
        ) : null}
        {kind === 'pull' || category === 'other' ? (
          <div className="field">
            <label>Target office</label>
            <select value={targetOfficeId} disabled={loading || officesLoading || Boolean(officesError)} onChange={(e) => setTargetOfficeId(e.target.value)} required>
              <option value="">Select office</option>
              {offices.map((o) => <option key={o.id} value={o.id}>{o.name} ({o.code})</option>)}
            </select>
            {officesLoading ? <p className="muted" role="status">Loading offices…</p> : null}
            {officesError ? <div className="error" role="alert">{officesError} <button type="button" className="btn-ghost" onClick={() => { setOfficesLoading(true); setOfficesError(''); setOfficesRetry((value) => value + 1) }}>Try again</button></div> : null}
          </div>
        ) : null}
      </div>
      <div className="field">
        <label>Purpose</label>
        <textarea value={purpose} disabled={loading} onChange={(e) => setPurpose(e.target.value)} required rows={3} />
      </div>
      <div className="field">
        <label>Required by</label>
        <input type="date" value={requiredBy} min={todayPlus(0)} disabled={loading} onChange={(e) => setRequiredBy(e.target.value)} required />
      </div>
      <button className="btn" type="submit" disabled={loading || (kind === 'access' && categories.length === 0) || ((kind === 'pull' || category === 'other') && (!targetOfficeId || officesLoading || Boolean(officesError)))}>
        {loading ? 'Sending…' : 'Send request'}
      </button>
    </form>
  )
}
