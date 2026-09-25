import { useEffect, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Html5Qrcode } from 'html5-qrcode'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { clerkScanActions, isSignedQrPayload, parseTrackingId } from '../tracking.js'
import { Overview, LifeEmpty } from '../components/ui.jsx'

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
  const { user } = useAuth()
  const [params] = useSearchParams()
  const [raw, setRaw] = useState(params.get('id') || '')
  const [doc, setDoc] = useState(null)
  const [offices, setOffices] = useState([])
  const [qrPayload, setQrPayload] = useState('')
  const [scanStartedAt, setScanStartedAt] = useState(null)
  const [destId, setDestId] = useState('')
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const [loading, setLoading] = useState(false)
  const [camNote, setCamNote] = useState('')
  const [camOn, setCamOn] = useState(preferCamera)
  const [fileBusy, setFileBusy] = useState(false)
  const scannerRef = useRef(null)
  const fileInputRef = useRef(null)
  const lookingUp = useRef(false)
  const lastScanAt = useRef(0)

  useEffect(() => {
    smartflow.offices().then((d) => setOffices(d.offices || [])).catch(() => {})
  }, [])

  useEffect(() => {
    if (!ok) return undefined
    const t = window.setTimeout(() => setOk(''), 4200)
    return () => window.clearTimeout(t)
  }, [ok])

  useEffect(() => {
    const preset = params.get('id')
    if (preset) lookup(preset)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (!camOn) return undefined

    let cancelled = false
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
            if (lookingUp.current || now - lastScanAt.current < 1600) return
            lastScanAt.current = now
            lookup(text)
          },
        )
        if (cancelled) {
          await stopScanner(scanner)
          return
        }
        setCamNote('Point the camera at the folder label, or upload a QR photo.')
      } catch {
        if (cancelled) return
        setCamNote('Camera needs HTTPS or localhost. Upload a QR photo or paste the text instead.')
        setCamOn(false)
      }
    })()

    return () => {
      cancelled = true
      const s = scannerRef.current
      scannerRef.current = null
      void stopScanner(s)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [camOn])

  async function lookup(value) {
    const trimmed = String(value || '').trim()
    if (!trimmed) return
    lookingUp.current = true
    setLoading(true)
    setError('')
    setOk('')
    setDoc(null)
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
      setRaw(id)
      setQrPayload(payload)
      setScanStartedAt(new Date().toISOString())
      const hint = shown.document?.suggested_forward?.office_id
      if (hint) setDestId(String(hint))
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Lookup failed')
    } finally {
      setLoading(false)
      lookingUp.current = false
    }
  }

  async function onQrFileChange(e) {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return

    setFileBusy(true)
    setError('')
    setOk('')
    try {
      const host = document.getElementById('sf-file-reader')
      if (host) host.innerHTML = ''
      const fileScanner = new Html5Qrcode('sf-file-reader', { verbose: false })
      const text = await fileScanner.scanFile(file, false)
      try {
        fileScanner.clear()
      } catch {
        /* ignore */
      }
      if (!text?.trim()) {
        throw new ApiError('No QR code found in that image.')
      }
      setCamNote('QR read from uploaded image.')
      await lookup(text.trim())
    } catch (err) {
      const msg = err instanceof ApiError
        ? err.message
        : 'Could not read a QR from that image. Use a clear photo of the folder label.'
      setError(msg)
    } finally {
      setFileBusy(false)
    }
  }

  async function mark(status) {
    if (!doc) return
    setError('')
    setOk('')
    setLoading(true)
    try {
      const body = {
        document_id: doc.id,
        office_id: user.office_id,
        status,
        scan_started_at: scanStartedAt,
      }
      if (qrPayload) body.qr_payload = qrPayload
      if (status === 'OUT') {
        const dest = Number(destId)
        if (!dest) throw new ApiError('Choose a destination office for Mark OUT.')
        body.destination_office_id = dest
      }
      const result = await smartflow.recordMovement(body)
      const label = status === 'IN' ? 'Marked IN' : 'Marked OUT'
      const msg = result.message || `${label} · ${doc.id}`
      setOk(msg)
      const shown = await smartflow.documentShow(doc.id)
      setDoc(shown.document)
      setScanStartedAt(new Date().toISOString())
      if (status === 'OUT') setDestId('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not record scan')
    } finally {
      setLoading(false)
    }
  }

  const actions = doc
    ? clerkScanActions({
        lastStatus: doc.current_status,
        lastOfficeId: doc.current_office_id,
        myOfficeId: user.office_id,
        currentOfficeName: doc.current_office_name,
      })
    : null

  const busy = loading || fileBusy

  return (
    <div className="sf-life">
      <Overview
        title="Scan"
        body="Mark IN when a folder arrives · OUT when you send it."
      />
      {camNote ? <p className="hint">{camNote}</p> : null}
      <div className="scan-layout">
        <div className="form-card sf-life__panel">
          <h3 className="section-title">Look up folder</h3>
          {camOn ? (
            <div id="sf-reader" className="reader" />
          ) : (
            <div className="cam-stage">
              <p className="muted cam-stage__hint" style={{ margin: 0 }}>
                Upload a QR photo, paste the tracking ID, or use the camera.
              </p>
              <button className="btn-secondary" type="button" style={{ marginTop: 4, width: 'auto' }} onClick={() => setCamOn(true)}>
                Use camera
              </button>
            </div>
          )}

          <div className="scan-upload-row">
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              capture={undefined}
              className="sr-only"
              aria-hidden
              tabIndex={-1}
              onChange={onQrFileChange}
            />
            <button
              className="btn-secondary"
              type="button"
              disabled={busy}
              onClick={() => fileInputRef.current?.click()}
            >
              {fileBusy ? 'Reading image…' : 'Upload QR image'}
            </button>
          </div>
          {/* Off-screen host for html5-qrcode file decode (must stay in DOM). */}
          <div id="sf-file-reader" className="sf-file-reader" aria-hidden />

          <form
            onSubmit={(e) => {
              e.preventDefault()
              lookup(raw)
            }}
          >
            <div className="field" style={{ marginTop: 12 }}>
              <label>Tracking ID or QR text</label>
              <input value={raw} onChange={(e) => setRaw(e.target.value)} placeholder="SF1.… or DOC-2026-000001" />
            </div>
            <button className="btn" type="submit" disabled={busy}>{loading ? 'Looking up…' : 'Look up'}</button>
          </form>
        </div>

        <div className={`card sf-life__panel${doc ? ' scan-result' : ''}`}>
          {error ? <div className="error">{error}</div> : null}
          {ok ? <div className={`ok${ok.includes('Marked IN') ? ' ok--in' : ok.includes('Marked OUT') ? ' ok--out' : ''}`}>{ok}</div> : null}
          {doc ? (
            <div className="scan-result__body">
              <p className="scan-result__type muted">{doc.type}</p>
              <h2 className="scan-result__id">{doc.id}</h2>
              <p className="muted">{doc.title}</p>
              <p className="muted">{actions?.statusLine}</p>
              {doc.is_overdue ? <p className="error">Overdue</p> : null}
              {doc.pilot_end_note ? <div className="hint">{doc.pilot_end_note}</div> : null}
              {actions?.blockReason ? <div className="error">{actions.blockReason}</div> : null}

              {actions?.canOut ? (
                <div className="field" style={{ marginTop: 14 }}>
                  <label>Forward to</label>
                  <select value={destId} onChange={(e) => setDestId(e.target.value)}>
                    <option value="">Select office</option>
                    {offices
                      .filter((o) => o.id !== user.office_id)
                      .map((o) => (
                        <option key={o.id} value={o.id}>{o.code} — {o.name}</option>
                      ))}
                  </select>
                </div>
              ) : null}

              <div className="row-btns" style={{ marginTop: 8 }}>
                <button className="btn btn--mark-in" type="button" disabled={!actions?.canIn || busy} onClick={() => mark('IN')}>
                  {busy && actions?.canIn ? 'Recording…' : 'Mark IN'}
                </button>
                <button className="btn-secondary btn--mark-out" type="button" disabled={!actions?.canOut || busy} onClick={() => mark('OUT')} style={{ marginTop: 0 }}>
                  {busy && actions?.canOut ? 'Recording…' : 'Mark OUT'}
                </button>
              </div>
            </div>
          ) : (
            <LifeEmpty icon="scan">No folder loaded yet.</LifeEmpty>
          )}
        </div>
      </div>
    </div>
  )
}
