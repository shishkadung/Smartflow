import { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { QRCodeSVG } from 'qrcode.react'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { documentTypesForOffice, OTHER_DOCUMENT_TYPE } from '../tracking.js'
import { LifeEmpty, Modal, Overview } from '../components/ui.jsx'

const OFFICE_TIPS = {
  ENG: 'Register your DV packet here. If you asked Budget for a file, use Document request — then Scan IN when it arrives (do not register as DV).',
  BUD: 'After approving a budget request, register Approved Budget, then OUT → ACC.',
  HR: 'Physical payroll folders are not registered in Phase 1. Accounting prepares payroll; HR supports plantilla.',
  ACC: 'After supporting-doc check, Mark OUT → Treasury. Do not treat Scan IN as payment approval.',
  TRE: 'Scan IN from Accounting, then OUT → Mayor. After Mayor returns the folder, Scan IN and release the check.',
  MAY: 'Scan IN when Treasury delivers the DV. After signature, Mark OUT back to Treasury.',
}

function officeTip(code) {
  return OFFICE_TIPS[String(code || '').toUpperCase()]
    || 'Folder must be on your desk. To ask another office for files, use Document requests first.'
}

function shortQrExpiry(iso) {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return String(iso).slice(0, 10)
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

export default function RegisterPage() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const types = useMemo(() => documentTypesForOffice(user.office_code), [user.office_code])
  const isHead = user.role === 'head'

  const [title, setTitle] = useState('')
  const [type, setType] = useState(types[0] || '')
  const [otherName, setOtherName] = useState('')
  const [comment, setComment] = useState('')
  const [reference, setReference] = useState('')
  const [payee, setPayee] = useState('')
  const [fundSource, setFundSource] = useState('')
  const [dueDate, setDueDate] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [created, setCreated] = useState(null)
  const [copyNote, setCopyNote] = useState('')
  const [dupMatches, setDupMatches] = useState(null)

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
    setTitle('')
    setOtherName('')
    setComment('')
    setReference('')
    setPayee('')
    setFundSource('')
    setDueDate('')
    setType(types[0] || '')
    setError('')
  }

  function registerAnother() {
    setCreated(null)
    setCopyNote('')
    clearForm()
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
      type: savedType,
      origin_office_id: user.office_id,
      description: comment.trim() || undefined,
      reference_no: reference.trim() || undefined,
      payee: payee.trim() || undefined,
      fund_source: fundSource.trim() || undefined,
      due_at: dueDate || undefined,
    })
    setCreated(data.document)
  }

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    if (title.trim().length < 3) {
      setError('Enter at least 3 characters for the document title.')
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

  if (types.length === 0) {
    return (
      <div className="sf-life">
        <Overview title="Register" body="Only when the folder is already in your custody." />
        <div className="card sf-life__panel">
          <LifeEmpty icon="register">
            No document types for your office. Pilot offices only — ENG, BUD, ACC, TRE, and MAY.
          </LifeEmpty>
          <p className="muted">{officeTip(user.office_code)}</p>
        </div>
      </div>
    )
  }

  if (created) {
    const id = created.id || ''
    const qrPayload = (created.qr_payload || '').trim() || id
    const dueDisplay = created.due_at_display
    const initialIn = created.initial_in_recorded === true
    const statusLine = initialIn
      ? `Registered at ${user.office_name} and marked IN at your desk.`
      : isHead
        ? `Registered at ${user.office_name}. Assign a clerk to attach the QR and scan handoffs.`
        : `Registered at ${user.office_name}. Scan IN on the Scanner tab when the folder is ready.`

    return (
      <div className="sf-life">
        <Overview title="Register" body={id || 'Document registered'} />
        <div className="register-layout">
          <div className="card sf-life__panel register-success">
            <p className="register-success__id">{id}</p>
            <p className="muted">{statusLine}</p>
            <p className="register-kv"><span>Title</span><strong>{created.title}</strong></p>
            <p className="register-kv"><span>Type</span><strong>{created.type}</strong></p>
            <p className="register-kv"><span>Origin</span><strong>{user.office_name}</strong></p>
            {dueDisplay ? <p className="register-kv"><span>Due</span><strong>{dueDisplay}</strong></p> : null}
            <h3 className="section-title">Do these next</h3>
            <p className="muted">Print → attach → Scan OUT when the folder leaves your desk.</p>
            <ol className="register-steps">
              <li>Print &amp; attach the QR label</li>
              <li>{isHead ? 'Staff: Mark OUT on Scanner when forwarding' : 'Mark OUT on Scanner when you forward'}</li>
              <li>Next office Marks IN on arrival</li>
            </ol>
            {!isHead ? (
              <button className="btn" type="button" onClick={() => navigate('/scan')}>Open Scanner</button>
            ) : null}
            <button className="btn-secondary" type="button" onClick={registerAnother}>
              Register another document
            </button>
            <div className="register-success__links">
              <button type="button" className="btn-ghost" onClick={() => copyText(id, 'Tracking ID copied')}>Copy ID</button>
              <button
                type="button"
                className="btn-ghost"
                onClick={() => copyText(smartflow.qrLabelUrl(id), 'Print link copied — open in Chrome on a PC to print the label.')}
              >
                Copy print link
              </button>
              <Link className="btn-ghost" to="/">Back to Home</Link>
            </div>
            {copyNote ? <p className="ok">{copyNote}</p> : null}
          </div>
          <div className="card sf-life__panel register-qr register-qr--ready">
            <h3 className="section-title">Print this secured QR on the folder label</h3>
            <div className="qr-box qr-box--ready">
              <QRCodeSVG value={qrPayload} size={200} />
            </div>
            {created.qr_expires_at ? (
              <p className="muted">Signed label · valid until {shortQrExpiry(created.qr_expires_at)}</p>
            ) : null}
            <a className="btn as-link" href={smartflow.qrLabelUrl(id)} target="_blank" rel="noreferrer">Open printable label</a>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="sf-life">
      <Overview
        title="Register"
        body="Only when the folder is already in your custody."
      />
      <div className="register-layout">
        <form className="form-card sf-life__panel" onSubmit={onSubmit}>
          <h3 className="section-title">Folder details</h3>
          <p className="muted profile-card-lead">{officeTip(user.office_code)}</p>
          {error ? <div className="error" role="alert">{error}</div> : null}
          <div className="form-grid">
            <div className="field">
              <label>Origin office</label>
              <input value={`${user.office_name} (${user.office_code})`} readOnly />
            </div>
            <div className="field">
              <label>Document title</label>
              <input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                required
                minLength={3}
                placeholder="e.g. Disbursement Voucher - Road Repair Phase 1"
              />
            </div>
            <div className="field">
              <label>Document type</label>
              {types.length === 1 ? (
                <input value={types[0]} readOnly />
              ) : (
                <select value={type} onChange={(e) => setType(e.target.value)}>
                  {types.map((t) => <option key={t} value={t}>{t}</option>)}
                </select>
              )}
            </div>
            {type === OTHER_DOCUMENT_TYPE ? (
              <div className="field">
                <label>Others</label>
                <input
                  value={otherName}
                  onChange={(e) => setOtherName(e.target.value)}
                  required
                  minLength={3}
                  placeholder="What is this folder?"
                />
              </div>
            ) : null}
            <div className="field">
              <label>Comment (optional)</label>
              <textarea
                value={comment}
                onChange={(e) => setComment(e.target.value)}
                rows={3}
                placeholder="Notes for the next office or for your logbook"
              />
            </div>
            <p className="muted profile-card-lead register-logbook-note">
              Logbook fields (optional). Mirror municipal logbook — reference, payee, fund source.
            </p>
            <div className="field">
              <label>Reference / DV no.</label>
              <input
                value={reference}
                onChange={(e) => setReference(e.target.value)}
                placeholder="LGU reference number"
              />
            </div>
            <div className="field">
              <label>Payee</label>
              <input value={payee} onChange={(e) => setPayee(e.target.value)} />
            </div>
            <div className="field">
              <label>Fund source</label>
              <input
                value={fundSource}
                onChange={(e) => setFundSource(e.target.value)}
                placeholder="e.g. MOOE, PS"
              />
            </div>
            <div className="field">
              <label>Target due date (optional)</label>
              <input
                type="date"
                value={dueDate}
                min={new Date().toISOString().slice(0, 10)}
                onChange={(e) => setDueDate(e.target.value)}
              />
              <p className="muted profile-readonly__hint">Pick a date — or leave blank for pilot thresholds.</p>
            </div>
          </div>
          <button className="btn" type="submit" disabled={loading || title.trim().length < 3}>
            {loading ? 'Registering…' : 'Register & get QR ID'}
          </button>
          {formDirty && !loading ? (
            <button className="btn-ghost" type="button" onClick={clearForm}>Clear form</button>
          ) : null}
        </form>
        <div className="card sf-life__panel register-qr">
          <h3 className="section-title">QR preview</h3>
          <LifeEmpty icon="register">
            QR appears here after you register.
          </LifeEmpty>
        </div>
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
