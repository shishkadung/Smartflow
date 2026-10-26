import { useEffect, useRef, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { Html5Qrcode } from 'html5-qrcode'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { clerkScanActions, isSignedQrPayload, parseTrackingId, movementDestination } from '../tracking.js'
import { Overview } from '../components/ui.jsx'
import QuickOpen from '../components/QuickOpen.jsx'
import { clearRecentDocs, loadRecentDocs, readClipboardText, rememberRecentDoc } from '../recent-docs.js'
import { SfIcon } from '../icons.jsx'
import { useFolderReceipt, FolderContentsSummary } from '../components/FolderContents.jsx'
import DestinationCorrection from '../components/DestinationCorrection.jsx'
import FolderHandoff from '../components/FolderHandoff.jsx'
import { preferredForwardDestination, recordConfirmedFiling, recordConfirmedReceipt, saveCustodyAndRefresh } from '../custody-actions.js'
import { useFolderFiling } from '../components/FolderFiling.jsx'

function officeShort(name) {
  const text = String(name || '').trim()
  return text ? text.replace(/\s+Office$/, '') : 'Unspecified office'
}

function custodySummary(doc, actions) {
  const status = String(doc?.current_status || '').toUpperCase()
  const here = officeShort(doc?.current_office_name)
  const dest = officeShort(doc?.destination_office_name)
  const hasDest = String(doc?.destination_office_name || '').trim() !== ''
  if (!status) return { route: 'Not received yet', label: 'Ready to receive', tone: 'warn' }
  if (status === 'OUT') {
    return {
      route: hasDest ? `${here} → ${dest}` : `OUT at ${here}`,
      label: actions?.canIn ? 'Ready to receive' : (hasDest ? `Waiting for ${dest}` : 'Waiting'),
      tone: 'warn',
    }
  }
  if (doc?.trail_complete) return { route: `At ${here}`, label: 'Completed', tone: 'ok' }
  return {
    route: `At ${here}`,
    label: actions?.canOut ? 'At this office' : 'In office',
    tone: actions?.canOut ? 'info' : 'neutral',
  }
}

function preferCamera() {
  if (typeof window === 'undefined') return false
  return !window.matchMedia('(min-width: 768px)').matches
}

async function stopScanner(scanner) {
  if (!scanner) return
  try {
    if (scanner.isScanning) await scanner.stop()
  } catch {
    /* already stopped */
  }
  try {
    scanner.clear()
  } catch {
    /* element may already be gone */
  }
}

export default function ScanPage() {
  const { requestReceipt, receiptDialog } = useFolderReceipt()
  const { requestFiling, filingDialog } = useFolderFiling()
  const { user, smartflow } = useAuth()
  const [params] = useSearchParams()
  const [raw, setRaw] = useState(params.get('id') || '')
  const [recent, setRecent] = useState(() => loadRecentDocs(user.id))
  const [doc, setDoc] = useState(null)
  const [detailFresh, setDetailFresh] = useState(false)
  const [detailError, setDetailError] = useState('')
  const [offices, setOffices] = useState([])
  const [qrPayload, setQrPayload] = useState('')
  const [scanStartedAt, setScanStartedAt] = useState(null)
  const [destId, setDestId] = useState('')
  const [isReturn, setIsReturn] = useState(false)
  const [returnReason, setReturnReason] = useState('')
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const [loading, setLoading] = useState(false)
  const [pending, setPending] = useState('')
  const [filing, setFiling] = useState(false)
  const [camNote, setCamNote] = useState('')
  const [camOn, setCamOn] = useState(preferCamera)
  const [fileBusy, setFileBusy] = useState(false)
  const [officeError, setOfficeError] = useState('')
  const [officeRetry, setOfficeRetry] = useState(0)
  const scannerRef = useRef(null)
  const fileInputRef = useRef(null)
  const readingFile = useRef(false)
  const lookingUp = useRef(false)
  const lastScanAt = useRef(0)

  useEffect(() => {
    smartflow.offices().then((d) => { setOffices(d.offices || []); setOfficeError('') }).catch((e) => setOfficeError(e.message || 'Could not load receiving offices.'))
  }, [officeRetry, smartflow])

  useEffect(() => {
    if (!ok || !detailFresh) return undefined
    const t = window.setTimeout(() => setOk(''), 4200)
    return () => window.clearTimeout(t)
  }, [ok, detailFresh])

  useEffect(() => {
    const preset = params.get('id')
    if (preset) lookup(preset)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (!camOn) return undefined

    let cancelled = false
    let decoded = false
    const elId = 'sf-reader'
    const host = document.getElementById(elId)
    if (host) host.innerHTML = ''

    const scanner = new Html5Qrcode(elId, { verbose: false })
    scannerRef.current = scanner

    ;(async () => {
      try {
        await scanner.start(
          { facingMode: 'environment' },
          {
            fps: 8,
            qrbox: (viewW, viewH) => {
              const side = Math.floor(Math.min(viewW, viewH) * 0.72)
              return { width: side, height: side }
            },
            aspectRatio: 3 / 4,
            disableFlip: true,
          },
          (text) => {
            const now = Date.now()
            if (cancelled || scannerRef.current !== scanner || decoded || readingFile.current || lookingUp.current || now - lastScanAt.current < 1600) return
            // A stationary label must not replace a reviewed folder or its open forms.
            // Starting the camera again explicitly permits the next lookup.
            decoded = true
            lastScanAt.current = now
            setCamOn(false)
            setCamNote('QR read. Review the result, or use the camera again for another label.')
            lookup(text)
          },
        )
        if (cancelled) {
          await stopScanner(scanner)
          return
        }
        if (!decoded) setCamNote('Point the camera at the folder label, or upload a QR photo.')
      } catch {
        if (cancelled) return
        setCamNote('Camera needs HTTPS or localhost. Upload a QR photo or paste the text instead.')
        setCamOn(false)
      }
    })()

    return () => {
      cancelled = true
      if (scannerRef.current === scanner) scannerRef.current = null
      void stopScanner(scanner)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [camOn])

  async function lookup(value, fromFile = false) {
    const trimmed = String(value || '').trim()
    if (!trimmed || lookingUp.current || (readingFile.current && !fromFile)) return
    lookingUp.current = true
    setLoading(true)
    setError('')
    setOk('')
    setDoc(null)
    setDetailFresh(false)
    setDetailError('')
    setIsReturn(false)
    setReturnReason('')
    try {
      let id = null
      let payload = ''
      if (isSignedQrPayload(trimmed)) {
        const verified = await smartflow.verifyQr(trimmed)
        id = verified.document_id
        payload = trimmed
      } else {
        id = parseTrackingId(trimmed)
      }
      if (!id) {
        throw new ApiError('Invalid tracking ID. Scan the secured SmartFlow QR or enter DOC-YYYY-######.')
      }
      const shown = await smartflow.documentShow(id)
      setDoc(shown.document)
      setDetailFresh(true)
      setRecent(rememberRecentDoc(user.id, id, shown.document?.title))
      setRaw(id)
      setQrPayload(payload)
      setScanStartedAt(new Date().toISOString())
      setDestId(preferredForwardDestination(shown.document, offices))
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Lookup failed')
    } finally {
      setLoading(false)
      lookingUp.current = false
    }
  }

  async function pasteLookup() {
    if (lookingUp.current || readingFile.current) return
    const clip = await readClipboardText()
    if (clip.error) { setError(clip.error); return }
    setRaw(clip.text)
    if (parseTrackingId(clip.text) || isSignedQrPayload(clip.text)) lookup(clip.text)
    else setError('That is not a tracking ID.')
  }

  async function retryFolderDetails() {
    if (!doc || lookingUp.current || filing || fileBusy) return
    lookingUp.current = true
    setLoading(true)
    setDetailFresh(false)
    setDetailError('')
    try {
      const shown = await smartflow.documentShow(doc.id)
      setDoc(shown.document)
      setDetailFresh(true)
      setError('')
      setScanStartedAt(new Date().toISOString())
      setDestId(preferredForwardDestination(shown.document, offices))
      setIsReturn(false)
      setReturnReason('')
    } catch (error) {
      setDetailError(error.message || 'Could not read the current folder details.')
    } finally {
      setLoading(false)
      lookingUp.current = false
    }
  }

  function confirmedSave(message) {
    setOk(message)
    setDetailFresh(false)
    setDetailError('')
  }

  function unverifiedDetails(error) {
    setDetailFresh(false)
    setDetailError(error.message || 'Could not read the current folder details.')
  }

  function stopCameraCapture() {
    const scanner = scannerRef.current
    scannerRef.current = null
    setCamOn(false)
    setCamNote('')
    void stopScanner(scanner)
  }

  async function onQrFileChange(e) {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file || readingFile.current || lookingUp.current || filing) return

    readingFile.current = true
    stopCameraCapture()
    setFileBusy(true)
    setError('')
    setOk('')
    let fileScanner
    try {
      const host = document.getElementById('sf-file-reader')
      if (host) host.innerHTML = ''
      fileScanner = new Html5Qrcode('sf-file-reader', { verbose: false })
      const text = await fileScanner.scanFile(file, false)
      if (!text?.trim()) {
        throw new ApiError('No QR code found in that image.')
      }
      setCamNote('QR read from uploaded image.')
      await lookup(text.trim(), true)
    } catch (err) {
      const msg = err instanceof ApiError
        ? err.message
        : 'Could not read a QR from that image. Use a clear photo of the folder label.'
      setError(msg)
    } finally {
      try {
        fileScanner?.clear()
      } catch {
        /* element may already be gone */
      }
      readingFile.current = false
      setFileBusy(false)
    }
  }

  async function fileFolder() {
    if (!doc || loading || filing || fileBusy || !detailFresh || user.role !== 'staff' || !doc.can_file) return
    const reviewed = { ...doc }
    lookingUp.current = true
    setFiling(true)
    setError('')
    setOk('')
    try {
      const current = await saveCustodyAndRefresh(
        () => recordConfirmedFiling(reviewed, requestFiling, smartflow.fileDocument),
        () => smartflow.documentShow(reviewed.id),
        result => confirmedSave(result.message || 'Filed. This folder is done.'),
        unverifiedDetails,
      )
      if (current) { setDoc(current); setDetailFresh(true) }
    } catch (e) {
      setError(e.message || 'Could not file this folder')
      setDetailFresh(false)
    } finally {
      setFiling(false)
      lookingUp.current = false
    }
  }

  async function mark(status) {
    if (!doc || loading || filing || fileBusy || !detailFresh || user.role !== 'staff') return
    const reviewed = { ...doc }
    setError('')
    setOk('')
    setLoading(true)
    setPending(status)
    lookingUp.current = true
    try {
      const body = {
        document_id: reviewed.id,
        office_id: user.office_id,
        status,
        scan_started_at: scanStartedAt,
        expected_movement_id: reviewed.last_movement_id ?? 0,
      }
      if (qrPayload) body.qr_payload = qrPayload
      if (status === 'OUT') {
        Object.assign(body, movementDestination({ destinationOfficeId: destId, isReturn, returnReason }))
      }
      const label = status === 'IN' ? 'Received (IN)' : isReturn ? 'Returned for correction' : 'Sent (OUT)'
      const current = await saveCustodyAndRefresh(
        () => status === 'IN'
          ? recordConfirmedReceipt(reviewed, requestReceipt, smartflow.recordMovement, body)
          : smartflow.recordMovement(body),
        () => smartflow.documentShow(reviewed.id),
        result => confirmedSave(result.message || `${label} · ${reviewed.id}`),
        unverifiedDetails,
      )
      if (current) {
        setDoc(current)
        setDetailFresh(true)
        setScanStartedAt(new Date().toISOString())
        setDestId(status === 'OUT' ? '' : preferredForwardDestination(current, offices))
        setIsReturn(false)
        setReturnReason('')
      }
    } catch (e) {
      setError(e.message || 'Could not record scan')
      setDetailFresh(false)
    } finally {
      setLoading(false)
      setPending('')
      lookingUp.current = false
    }
  }

  const actions = doc
    ? clerkScanActions({
        lastStatus: doc.current_status,
        lastOfficeId: doc.current_office_id,
        myOfficeId: user.office_id,
        currentOfficeName: doc.current_office_name,
        destinationOfficeId: doc.destination_office_id,
        destinationOfficeName: doc.destination_office_name,
        role: user.role,
      })
    : null
  const custody = doc ? custodySummary(doc, actions) : null

  const busy = loading || fileBusy || filing
  const trailComplete = doc?.trail_complete === true
  const canReturn = doc?.can_return_to_accounting === true
  const routeFinished = trailComplete && !canReturn
  const maySend = Boolean(actions?.canOut) && !routeFinished
  return (
    <div className={`sf-life scan-page${doc ? ' scan-page--resolved' : ''}`}>
      {receiptDialog}
      {filingDialog}
      <Overview
        title="Scan"
      />
      {camNote ? <p className="hint" role="status">{camNote}</p> : null}
      <div className={`scan-layout${doc ? ' scan-layout--resolved' : ' scan-layout--solo'}`}>
        <section className="form-card sf-life__panel scan-lookup" aria-label="Find a folder">
          <h3 className="section-title">{doc ? 'Find another folder' : 'Find a folder'}</h3>
          {!doc && error ? <div className="error" role="alert">{error}</div> : null}
          <form className="scan-id-form" onSubmit={(e) => { e.preventDefault(); lookup(raw) }}>
            <div className="field">
              <div className="field-label-row">
                <label htmlFor="scan-tracking-id">Tracking ID or QR text</label>
                <button type="button" className="btn-ghost" disabled={busy} onClick={pasteLookup}>Paste</button>
              </div>
              <input id="scan-tracking-id" value={raw} disabled={busy} onChange={(e) => setRaw(e.target.value)} placeholder="DOC-2026-000001 or SF1.…" />
            </div>
            <button className="btn" type="submit" disabled={busy || !raw.trim()}>{loading ? 'Looking up…' : 'Look up folder'}</button>
          </form>
          <QuickOpen docs={recent} disabled={busy} onOpen={(id) => { setRaw(id); lookup(id) }} onClear={() => setRecent(clearRecentDocs(user.id))} />
          <div className="scan-input-divider"><span>Or read a QR label</span></div>
          {camOn ? (
            <div id="sf-reader" className="reader" />
          ) : null}

          <div className="scan-capture-actions">
            <button className="btn-secondary" type="button" aria-pressed={camOn} disabled={busy} onClick={() => setCamOn(on => !on)}><SfIcon name="scan" size={18} />{camOn ? 'Stop camera' : 'Use camera'}</button>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              capture={undefined}
              className="sr-only"
              aria-hidden
              aria-label="QR image file"
              tabIndex={-1}
              onChange={onQrFileChange}
            />
            <button
              className="btn-secondary"
              type="button"
              disabled={busy}
              onClick={() => { stopCameraCapture(); fileInputRef.current?.click() }}
            >
              <SfIcon name="qrHandoffs" size={18} />
              {fileBusy ? 'Reading image…' : 'Upload QR image'}
            </button>
          </div>
          {/* Off-screen host for html5-qrcode file decode (must stay in DOM). */}
          <div id="sf-file-reader" className="sf-file-reader" aria-hidden />

          <p className="muted scan-lookup__hint">Keep the physical folder with you. Looking it up does not record a handoff.</p>
        </section>
        {doc ? (
        <section className="card sf-life__panel scan-result" aria-label="Folder and next action">
          {error ? <div className="error" role="alert">{error}</div> : null}
          {officeError && user.role === 'staff' && !maySend ? <div className="error" role="alert">Receiving offices unavailable. {officeError}<button type="button" className="btn-secondary" disabled={busy} onClick={() => setOfficeRetry(value => value + 1)}>Retry receiving offices</button></div> : null}
          {ok ? <div className={`ok${ok.includes('Marked IN') ? ' ok--in' : ok.includes('Marked OUT') ? ' ok--out' : ''}`} role="status">{ok}</div> : null}
          {!detailFresh ? <ScanCustodyRecovery saved={Boolean(ok)} error={detailError} busy={busy} onRetry={retryFolderDetails} /> : null}
          <div className="scan-result__body">
              <header className="scan-folder-heading">
                <p className="scan-result__type muted">{doc.type}</p>
                <h2 className="scan-result__title">{doc.title}</h2>
                <p className="scan-result__id">{doc.id}</p>
              </header>
              <div className="scan-custody">
                <div><span className="scan-custody__label">{doc.current_status === 'OUT' ? 'Sent from → destination' : 'Current location'}</span><p className="scan-result__route">{custody.route}</p></div>
                <div className="scan-result__status"><span className={`status-pill status-pill--${custody.tone}`}>{custody.label}</span></div>
              </div>
              {doc.due_at_display && doc.due_at_display !== '—' ? <p className={`scan-deadline${doc.is_overdue ? ' is-overdue' : ''}`}>Deadline · {doc.due_at_display}{doc.is_overdue ? ' · Overdue' : ''}</p> : doc.is_overdue ? <p className="error">Overdue</p> : null}
              {['incomplete', 'discrepancy'].includes(doc.contents_status || doc.folder_inventory?.status) ? <p className="document-content-warning">{(doc.contents_status || doc.folder_inventory?.status) === 'incomplete' ? 'Folder contents incomplete.' : 'Folder contents discrepancy recorded.'} Review the counts and notes below.</p> : null}
              {routeFinished ? <div className="ok ok--in">{doc.filed_at || doc.filed_by?.filed_at ? 'Filed. The route is finished.' : 'Route complete.'}</div> : null}
              {doc.pilot_end_note && !routeFinished && user.role === 'staff' ? (
                <div className={trailComplete ? 'ok ok--in' : 'hint'}>{doc.pilot_end_note}</div>
              ) : null}
              {/* A filed folder will not be sent again, so "they must mark OUT" would contradict the finished route. */}
              {actions?.blockReason && !routeFinished ? <div className={user.role === 'staff' ? 'error' : 'hint'}>{actions.blockReason}</div> : null}
              {actions?.canIn || maySend ? <div className="scan-next-heading"><h3 className="section-title">Next physical action</h3><p className="muted">{actions?.canIn ? 'Confirm the folder and count what actually arrived before recording receipt.' : doc.can_file ? 'Choose where this folder goes next, or file it when its work is complete.' : 'Choose the receiving office before handing over this folder.'}</p></div> : null}
              {actions?.canIn ? <div className="document-action"><button className="btn" type="button" disabled={busy || !detailFresh} onClick={() => mark('IN')}>{pending === 'IN' ? 'Receiving…' : 'Receive (IN)'}</button></div> : null}
              {maySend ? <FolderHandoff document={doc} offices={offices} user={user} destination={destId} isReturn={isReturn} returnReason={returnReason} disabled={busy || !detailFresh} pending={filing ? 'file' : pending}
                officeError={officeError} onRetryOffices={() => setOfficeRetry(value => value + 1)}
                onDestination={setDestId} onMode={value => { setIsReturn(value); setReturnReason(''); setDestId(value ? '' : preferredForwardDestination(doc, offices)) }}
                onReason={setReturnReason} onSend={() => mark('OUT')} onFile={fileFolder} /> : null}
              <DestinationCorrection document={doc} disabled={busy || !detailFresh} onChanged={async result => { confirmedSave(result.message || 'Destination correction recorded.'); await retryFolderDetails() }} />
              <details className="document-secondary scan-folder-details" open={['incomplete', 'discrepancy'].includes(doc.contents_status || doc.folder_inventory?.status)}>
                <summary>Folder details and contents</summary>
                <dl className="document-meta"><div><dt>Reference</dt><dd>{doc.reference_no || '—'}</dd></div><div><dt>Origin office</dt><dd>{doc.origin_office_name}</dd></div></dl>
                <FolderContentsSummary document={doc} />
              </details>
              <Link className="btn-ghost" to={`/documents?id=${encodeURIComponent(doc.id)}`}>Open the full record</Link>
            </div>
        </section>
        ) : null}
      </div>
    </div>
  )
}

export function ScanCustodyRecovery({ saved, error, busy, onRetry }) {
  return <div className="hint" role="status">
    <p>{saved ? 'The action was saved. Current folder details have not been verified; the displayed custody may be out of date.' : 'Current custody is unverified. Check the latest folder details before another physical action.'}</p>
    {error ? <p>{error}</p> : null}
    <p>Receive, Send, File and destination correction stay disabled until the current details load.</p>
    <button type="button" className="btn-secondary" disabled={busy} onClick={onRetry}>{busy ? 'Checking folder details…' : 'Retry folder details'}</button>
  </div>
}
