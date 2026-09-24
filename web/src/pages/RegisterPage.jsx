import { useMemo, useState } from 'react'
import { QRCodeSVG } from 'qrcode.react'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { documentTypesForOffice } from '../tracking.js'
import { LifeEmpty, Overview } from '../components/ui.jsx'

export default function RegisterPage() {
  const { user } = useAuth()
  const types = useMemo(() => documentTypesForOffice(user.office_code), [user.office_code])
  const [title, setTitle] = useState('')
  const [type, setType] = useState(types[0] || '')
  const [reference, setReference] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [created, setCreated] = useState(null)

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      if (!type) throw new ApiError('This office does not register physical QR documents in the pilot (HR uses payslip access).')
      const data = await smartflow.createDocument({
        title: title.trim(),
        type,
        origin_office_id: user.office_id,
        reference_no: reference.trim() || undefined,
      })
      setCreated(data.document)
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not register')
    } finally {
      setLoading(false)
    }
  }

  const preview = created

  return (
    <div className="sf-life">
      <Overview
        title="Register a document folder"
        body="Only when the folder is already in your custody."
      />
      <div className="register-layout">
        <form className="form-card sf-life__panel" onSubmit={onSubmit}>
          <h3 className="section-title">Folder details</h3>
          {error ? <div className="error" role="alert">{error}</div> : null}
          {types.length === 0 ? (
            <div className="error">HR does not register physical QR folders in this pilot.</div>
          ) : (
            <>
              <div className="form-grid">
                <div className="field">
                  <label>Title</label>
                  <input value={title} onChange={(e) => setTitle(e.target.value)} required placeholder="e.g. DV for road repair" />
                </div>
                <div className="field">
                  <label>Type</label>
                  <select value={type} onChange={(e) => setType(e.target.value)}>
                    {types.map((t) => <option key={t} value={t}>{t}</option>)}
                  </select>
                </div>
                <div className="field">
                  <label>Origin office</label>
                  <input value={`${user.office_name} (${user.office_code})`} readOnly />
                </div>
                <div className="field">
                  <label>Reference (optional)</label>
                  <input value={reference} onChange={(e) => setReference(e.target.value)} />
                </div>
              </div>
              <button className="btn" type="submit" disabled={loading}>
                {loading ? 'Registering…' : 'Register & get QR'}
              </button>
            </>
          )}
        </form>
        <div className={`card sf-life__panel${preview ? ' register-qr register-qr--ready' : ' register-qr'}`}>
          <h3 className="section-title">{preview ? 'QR ready' : 'QR preview'}</h3>
          {preview ? (
            <>
              <p className="register-qr__id">{preview.id}</p>
              <div className="qr-box qr-box--ready">
                <QRCodeSVG value={preview.qr_payload || preview.id} size={200} />
              </div>
              {preview.qr_expires_at ? <p className="muted">Expires {preview.qr_expires_at}</p> : null}
              <div className="register-qr__actions">
                <a className="btn as-link" href={smartflow.qrLabelUrl(preview.id)} target="_blank" rel="noreferrer">Open printable label</a>
                <button className="btn-secondary" type="button" onClick={() => { setCreated(null); setTitle(''); setReference('') }}>Register another</button>
              </div>
            </>
          ) : (
            <LifeEmpty icon="register">
              QR appears here after you register.
            </LifeEmpty>
          )}
        </div>
      </div>
    </div>
  )
}
