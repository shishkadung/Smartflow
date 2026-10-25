import { useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import DocumentQr from '../components/DocumentQr.jsx'
import DocumentSummary from '../components/DocumentSummary.jsx'
import { emptyInventory, FolderInventoryEditor, readInventory } from '../components/FolderContents.jsx'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { documentTypesForOffice, OTHER_DOCUMENT_TYPE } from '../tracking.js'
import { LifeEmpty, LifeSkeleton, Modal, Overview } from '../components/ui.jsx'
import CreationRecovery from '../components/CreationRecovery.jsx'
import { SfIcon } from '../icons.jsx'

const OFFICE_TIPS = {
  ENG: 'Register your DV packet here. If you asked Budget for a file, use New request in Requests — then Scan IN when it arrives (do not register as DV).',
  BUD: 'After approving a budget request, register Approved Budget, then OUT → ACC.',
  HR: 'Physical payroll folders are not registered in Phase 1. Accounting prepares payroll; HR supports plantilla.',
  ACC: 'Accounting does not originate project DVs — register a DV only if it arrived without a QR label. After supporting-doc check, Mark OUT → Treasury.',
  TRE: 'Scan IN from Accounting, then OUT → Mayor. After Mayor returns the folder, Scan IN and release the check.',
  MAY: 'Scan IN when Treasury delivers the DV. After signature, Mark OUT back to Treasury.',
}

function officeTip(code) {
  return OFFICE_TIPS[String(code || '').toUpperCase()]
    || 'Folder must be on your desk. To ask another office for files, send a request in Requests first.'
}

function shortQrExpiry(iso) {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return String(iso).slice(0, 10)
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

export default function RegisterPage() {
  const { user, smartflow, openPrintableLabel } = useAuth()
  const [params, setParams] = useSearchParams()
  const requestId = params.get('request_id') || ''
  const types = useMemo(() => documentTypesForOffice(user.office_code), [user.office_code])

  const [title, setTitle] = useState('')
  const [inventory, setInventory] = useState(emptyInventory)
  const [type, setType] = useState(types[0] || '')
  const [otherName, setOtherName] = useState('')
  const [comment, setComment] = useState('')
  const [reference, setReference] = useState('')
  const [payee, setPayee] = useState('')
  const [fundSource, setFundSource] = useState('')
  const [receivedFrom, setReceivedFrom] = useState('')
  const [offices, setOffices] = useState([])
  const [officeError, setOfficeError] = useState('')
  const [officeRetry, setOfficeRetry] = useState(0)
  const [dueDate, setDueDate] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [created, setCreated] = useState(null)
  const [copyNote, setCopyNote] = useState('')
  const [printing, setPrinting] = useState(false)
  const [dupMatches, setDupMatches] = useState(null)
  const [requestState, setRequestState] = useState({ id: '', request: null, error: '', loading: false })
  const [requestRetry, setRequestRetry] = useState(0)
  const validRequestId = /^[1-9]\d*$/.test(requestId)
  const linkedRequest = requestState.id === requestId ? requestState.request : null
  const requestLoading = validRequestId && (requestState.id !== requestId || requestState.loading)
  const requestError = requestId && !validRequestId
    ? 'This request link is invalid. Open the request and choose Register folder again.'
    : requestState.id === requestId ? requestState.error : ''

  useEffect(() => {
    let cancelled = false
    if (!requestId || !validRequestId) return
    smartflow.documentRequestsList('inbox', 'approved', { id: requestId }).then((data) => {
      if (cancelled) return
      const req = (data.requests || []).find((row) => String(row.id) === requestId)
      if (req?.status !== 'approved') throw new Error('The request must still be accepted before registering its folder.')
      if (!req || Number(req.handler_office?.office_id) !== Number(user.office_id)) {
        throw new Error('Only the handling office can register a folder for this accepted request.')
      }
      if (req.related_document_id) throw new Error(`This request already links to ${req.related_document_id}. Open that folder instead of registering another.`)
      const suggestedType = req.document_category === 'budget' ? 'Approved Budget'
        : req.document_category === 'disbursement' ? 'Disbursement Voucher' : OTHER_DOCUMENT_TYPE
      if (!types.includes(suggestedType)) throw new Error('Your office cannot register the document type for this request. Select an existing folder from Request details instead.')
      setRequestState({ id: requestId, request: req, error: '', loading: false })
      setTitle(String(req.purpose || '').slice(0, 200))
      setComment(`For ${req.request_code}: ${req.purpose || ''}`)
      setType(suggestedType)
    }).catch((e) => { if (!cancelled) setRequestState({ id: requestId, request: null, error: e.message || 'Could not load this request.', loading: false }) })
    return () => { cancelled = true }
  }, [requestId, validRequestId, requestRetry, types, user.office_id, smartflow])

  const isDv = type === 'Disbursement Voucher'
  const needsReference = isDv || type === 'Approved Budget'
  const needsReceivedFrom = isDv && String(user.office_code || '').toUpperCase() === 'ACC'

  useEffect(() => {
    if (!needsReceivedFrom || offices.length) return
    smartflow.offices()
      .then((d) => { setOffices((d.offices || []).filter((o) => o.id !== user.office_id)); setOfficeError('') })
      .catch((e) => setOfficeError(e.message || 'Could not load sender offices.'))
  }, [needsReceivedFrom, offices.length, user.office_id, officeRetry, smartflow])

  const formDirty = Boolean(
    title.trim()
    || otherName.trim()
    || comment.trim()
    || reference.trim()
    || payee.trim()
    || fundSource.trim()
    || dueDate,
  )

  function clearForm() {
    setInventory(emptyInventory())
    setTitle('')
    setOtherName('')
    setComment('')
    setReference('')
    setPayee('')
    setFundSource('')
    setReceivedFrom('')
    setDueDate('')
    setType(linkedRequest?.document_category === 'budget' ? 'Approved Budget' : linkedRequest?.document_category === 'disbursement' ? 'Disbursement Voucher' : linkedRequest ? OTHER_DOCUMENT_TYPE : types[0] || '')
    setError('')
  }

  function registerAnother() {
    setCreated(null)
    setCopyNote('')
    setParams({})
    clearForm()
    setType(types[0] || '')
  }

  async function copyText(text, note) {
    try {
      await navigator.clipboard.writeText(text)
      setCopyNote(note)
    } catch {
      setCopyNote('Could not copy. Select the text and copy it manually.')
    }
  }

  async function createFolder() {
    const savedType = type === OTHER_DOCUMENT_TYPE ? `Others: ${otherName.trim()}` : type
    const data = await smartflow.createDocument({
      title: title.trim(),
      folder_inventory: readInventory(inventory),
      type: savedType,
      origin_office_id: user.office_id,
      description: comment.trim() || undefined,
      reference_no: reference.trim() || undefined,
      payee: payee.trim() || undefined,
      fund_source: fundSource.trim() || undefined,
      received_from_office_id: needsReceivedFrom ? Number(receivedFrom) : undefined,
      due_at: dueDate || undefined,
      ...(linkedRequest ? { request_id: linkedRequest.id } : {}),
    })
    setCreated(data.document)
  }

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    if (requestId && (!linkedRequest || requestLoading)) {
      setError('Load the accepted request before registering its folder.')
      return
    }
    if (title.trim().length < 3 || title.trim().length > 200) {
      setError('Use 3 to 200 characters for the document title.')
      return
    }
    if (!type) {
      setError('Choose a document type.')
      return
    }
    if (type === OTHER_DOCUMENT_TYPE && otherName.trim().length < 3) {
      setError('Name the folder under Others (at least 3 characters).')
      return
    }
    if (needsReference && !reference.trim()) {
      setError('Enter the reference number from the logbook.')
      return
    }
    if (isDv && (!payee.trim() || !fundSource.trim())) {
      setError('Payee and fund source are required for a Disbursement Voucher.')
      return
    }
    if (needsReceivedFrom && !receivedFrom) {
      setError('Choose the office that sent this DV folder to Accounting.')
      return
    }

    try { readInventory(inventory) } catch (err) { setError(err.message); return }
    setLoading(true)
    try {
      const ref = reference.trim()
      if (ref) {
        try {
          const found = await smartflow.findByReference(ref)
          const matches = found.matches || []
          if (matches.length) {
            setDupMatches(matches)
            setLoading(false)
            return
          }
        } catch {
          // Same as mobile: a lookup failure does not block registration.
        }
      }
      await createFolder()
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not register')
    } finally {
      setLoading(false)
    }
  }

  async function registerAnyway() {
    setDupMatches(null)
    setError('')
    setLoading(true)
    try {
      await createFolder()
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not register')
    } finally {
      setLoading(false)
    }
  }

  if (user.role !== 'staff') {
    return <div className="sf-life register-page">
      <Overview title="Register" body="Office staff register physical folders held by their office." />
      <div className="card sf-life__panel"><p>Heads and administrators monitor custody. Use Documents to review folders and their history.</p><Link className="btn-secondary" to="/documents">Open Documents</Link></div>
    </div>
  }

  if (types.length === 0) {
    return (
      <div className="sf-life register-page">
        <Overview title="Register" />
        <div className="card sf-life__panel">
          <LifeEmpty icon="register">
            No document types for your office. Pilot offices only — ENG, BUD, ACC, TRE, and MAY.
          </LifeEmpty>
          <p className="muted">{officeTip(user.office_code)}</p>
        </div>
      </div>
    )
  }

  if (requestId && !created && (requestLoading || !linkedRequest)) {
    return <div className="sf-life register-page">
      <Overview title="Register folder for request" body="The folder must already be on your desk." />
      <div className="card sf-life__panel">
        {requestLoading ? <LifeSkeleton rows={3} label="Loading accepted request" /> : <>
          <p className="error" role="alert">{requestError || 'Could not load this request.'}</p>
          {validRequestId ? <button type="button" className="btn-secondary" onClick={() => { setRequestState((state) => ({ ...state, loading: true })); setRequestRetry((value) => value + 1) }}>Try again</button> : null}
        </>}
        <Link className="btn-ghost" to={`/requests?id=${encodeURIComponent(requestId)}`}>Back to request</Link>
      </div>
    </div>
  }

  if (created) {
    const id = created.id || ''
    const qrPayload = (created.qr_payload || '').trim() || id
    const initialIn = created.initial_in_recorded === true
    const statusLine = initialIn
      ? `Initial IN recorded at ${user.office_name} during registration. No extra scan is needed for registration.`
      : `Folder saved. Open the folder to verify its current custody before the next handoff.`
    // Creation recovery can replay after later handoffs; show registration evidence, not inferred current custody.
    const registrationSummary = {
      id, title: created.title, type: created.type, reference_no: created.reference_no,
      origin_office_name: user.office_name, due_at_display: created.due_at_display,
      folder_inventory: created.folder_inventory, contents_status: created.contents_status,
    }

    return (
      <div className="sf-life register-page">
        <Overview title="Folder registered" body={statusLine} />
        <div className="register-layout">
          <div className="card sf-life__panel register-success">
            <DocumentSummary document={registrationSummary} />
            {linkedRequest ? <p className="ok">Linked to {linkedRequest.request_code}. The request remains accepted until its work is complete.</p> : null}
            <div className="register-success__actions">
            <Link className="btn as-link" to={`/documents?id=${encodeURIComponent(id)}`}>Open folder</Link>
            <button className="btn-secondary" type="button" onClick={registerAnother}>
              Register another folder
            </button>
            {linkedRequest ? <Link className="btn-secondary" to={`/requests?id=${linkedRequest.id}`}>Open linked request</Link> : null}
            </div>
            <details className="register-guidance"><summary>How to hand over this folder</summary><ol className="register-steps"><li>Open the document in SmartFlow</li><li>Forward (OUT) and choose the receiving office</li><li>Receiving office opens Incoming and confirms receipt (IN)</li></ol></details>
            <div className="register-success__links">
              <button type="button" className="btn-ghost" onClick={() => copyText(id, 'Tracking ID copied')}>Copy ID</button>
              <button
                type="button"
                className="btn-ghost"
                onClick={() => copyText(smartflow.documentUrl(id), 'Document link copied. Sign in to SmartFlow to open it.')}
              >
                Copy document link
              </button>
              <Link className="btn-ghost" to="/">Back to Dashboard</Link>
            </div>
            {copyNote ? <p className="ok">{copyNote}</p> : null}
            {error ? <p className="error" role="alert">{error}</p> : null}
          </div>
          <div className="card sf-life__panel register-qr register-qr--ready">
            <h3 className="section-title">Folder label</h3>
            <p className="muted finishing-section-lead">Save or print this label when needed. The QR is a shortcut for looking up the folder.</p>
            <div className="qr-box qr-box--ready">
              <DocumentQr id={id} payload={qrPayload} showId={false} />
            </div>
            {created.qr_expires_at ? (
              <p className="muted">Signed label · valid until {shortQrExpiry(created.qr_expires_at)}</p>
            ) : null}
            <button className="btn" type="button" disabled={printing} onClick={async () => {
              setPrinting(true)
              setError('')
              try { await openPrintableLabel(id) } catch (err) { setError(err.message || 'Could not open the printable label.') }
              finally { setPrinting(false) }
            }}>{printing ? 'Preparing label…' : 'Print / Save QR label'}</button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="sf-life register-page">
      <Overview
        title="Register folder"
      />
      <CreationRecovery kind="document" onRecovered={(data) => { setCreated(data.document); setError('') }} />
      {linkedRequest ? <div className="request-next-step"><h4>For {linkedRequest.request_code}</h4><p>{linkedRequest.purpose}</p><p className="hint">Register the folder already on your desk. Its QR and this request will be linked together.</p><Link to={`/requests?id=${linkedRequest.id}`}>Back to request</Link></div> : null}
      <div className="register-layout register-layout--entry">
        <aside className="card sf-life__panel register-qr register-guidance-panel" aria-label="Registration guidance">
          <h3 className="section-title">Before you register</h3>
          <p className="muted finishing-section-lead">{officeTip(user.office_code)}</p>
          <ol className="register-guidance-list"><li>Check that the folder is physically at your office.</li><li>Copy its logbook details and count the actual pages.</li><li>Register to record IN at your office and create its tracking ID and QR label.</li></ol>
          <p className="register-guidance-note">Already has a SmartFlow label? <Link to="/scan">Look up the folder</Link> to record its next handoff.</p>
          <p className="muted finishing-section-lead">To ask another office for a folder, <Link to="/requests">create a request</Link>.</p>
        </aside>
        <form className="form-card sf-life__panel" onSubmit={onSubmit}>
          <div className="finishing-form-intro"><h3 className="section-title">Folder on your desk</h3><p className="muted">The folder must already be at your office.</p></div>
          {error ? <div className="error" role="alert">{error}</div> : null}
          {needsReceivedFrom && officeError ? <div className="error" role="alert">{officeError}<button type="button" className="btn-secondary" onClick={() => { setOfficeError(''); setOfficeRetry(value => value + 1) }}>Retry sender offices</button></div> : null}
          <fieldset className="finishing-form-section">
          <legend>Folder identity</legend>
          <div className="form-grid">
            <div className="profile-readonly__row register-office-context" role="group" aria-labelledby="register-origin-label">
              <span id="register-origin-label"><SfIcon name="lock" size={16} />Registering office</span>
              <strong>{user.office_name} ({user.office_code})</strong>
            </div>
            <div className="field">
              <label htmlFor="register-title">Folder title</label>
              <input
                id="register-title"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                required
                minLength={3}
                maxLength={200}
                placeholder="e.g. Disbursement Voucher - Road Repair Phase 1"
              />
            </div>
            <div className="field">
              <label htmlFor="register-type">Document type</label>
              {types.length === 1 ? (
                <input id="register-type" value={types[0]} readOnly />
              ) : (
                <select id="register-type" value={type} disabled={loading || Boolean(linkedRequest)} onChange={(e) => setType(e.target.value)}>
                  {types.map((t) => <option key={t} value={t}>{t}</option>)}
                </select>
              )}
            </div>
            {type === OTHER_DOCUMENT_TYPE ? (
              <div className="field">
                <label htmlFor="register-other-name">Name of other folder type</label>
                <input
                  id="register-other-name"
                  value={otherName}
                  onChange={(e) => setOtherName(e.target.value)}
                  required
                  minLength={3}
                  placeholder="What is this folder?"
                />
              </div>
            ) : null}
          </div>
          </fieldset>
          <fieldset className="finishing-form-section">
            <legend>Logbook details</legend>
            <p className="muted finishing-section-lead">
              {isDv
                ? 'Logbook fields (required for DV). Mirror municipal logbook — reference, payee, fund source.'
                : needsReference
                  ? 'Logbook fields. Reference no. is required; payee and fund source are optional.'
                  : 'Logbook fields (optional). Mirror municipal logbook — reference, payee, fund source.'}
            </p>
            <div className="form-grid">
            {needsReceivedFrom ? (
              <div className="field">
                <label htmlFor="register-received-from">Received from office (required)</label>
                <select id="register-received-from" value={receivedFrom} onChange={(e) => setReceivedFrom(e.target.value)} required>
                  <option value="">Select office</option>
                  {offices.map((o) => <option key={o.id} value={o.id}>{o.name} ({o.code})</option>)}
                </select>
                <p className="muted profile-readonly__hint">
                  Accounting does not originate project DVs. Register only a DV folder that arrived without a QR label.
                </p>
              </div>
            ) : null}
            <div className="field">
              <label htmlFor="register-reference">Reference / DV no.{needsReference ? ' (required)' : ''}</label>
              <input
                id="register-reference"
                value={reference}
                onChange={(e) => setReference(e.target.value)}
                placeholder="LGU reference number"
                required={needsReference}
              />
            </div>
            <div className="field">
              <label htmlFor="register-payee">Payee{isDv ? ' (required)' : ''}</label>
              <input id="register-payee" value={payee} onChange={(e) => setPayee(e.target.value)} required={isDv} />
            </div>
            <div className="field">
              <label htmlFor="register-fund-source">Fund source{isDv ? ' (required)' : ''}</label>
              <input
                id="register-fund-source"
                value={fundSource}
                onChange={(e) => setFundSource(e.target.value)}
                placeholder="e.g. MOOE, PS"
                required={isDv}
              />
            </div>
          </div>
          </fieldset>
          <FolderInventoryEditor value={inventory} onChange={setInventory} disabled={loading} />
          <fieldset className="finishing-form-section">
            <legend>Notes and deadline</legend>
            <div className="form-grid">
            <div className="field">
              <label htmlFor="register-comment">Comment (optional)</label>
              <textarea id="register-comment" value={comment} onChange={(e) => setComment(e.target.value)} rows={3} placeholder="Notes for the next office or for your logbook" />
            </div>
            <div className="field">
              <label htmlFor="register-due-date">Target due date (optional)</label>
              <input
                id="register-due-date"
                type="date"
                value={dueDate}
                min={new Date().toISOString().slice(0, 10)}
                onChange={(e) => setDueDate(e.target.value)}
              />
              <p className="muted profile-readonly__hint">Pick a date — or leave blank for pilot thresholds.</p>
            </div>
          </div>
          </fieldset>
          <div className="register-submit-actions">
          <button className="btn" type="submit" disabled={loading || title.trim().length < 3 || (requestId && !linkedRequest)}>
            {loading ? 'Registering…' : 'Register folder'}
          </button>
          {formDirty && !loading ? (
            <button className="btn-ghost" type="button" onClick={clearForm}>Clear form</button>
          ) : null}
          </div>
        </form>
      </div>

      <Modal
        open={Boolean(dupMatches)}
        title="Reference already used"
        onClose={() => setDupMatches(null)}
        footer={(
          <div className="row-btns">
            <button type="button" className="btn-secondary" onClick={() => setDupMatches(null)}>Cancel</button>
            <button type="button" className="btn" onClick={registerAnyway} disabled={loading}>
              {loading ? 'Registering…' : 'Register anyway'}
            </button>
          </div>
        )}
      >
        <p className="muted">
          “{reference.trim()}” was used by {dupMatches?.length === 1 ? 'this document' : 'these documents'}:
        </p>
        <ul className="register-dupes">
          {(dupMatches || []).map((m) => (
            <li key={m.id}>{m.id} · {m.type} · {m.origin_office_code}</li>
          ))}
        </ul>
        <p className="muted">Register a new tracking ID anyway, or cancel and verify first.</p>
      </Modal>
    </div>
  )
}
