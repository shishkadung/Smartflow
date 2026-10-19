import { useEffect, useId, useState } from 'react'

import { useAuth } from '../auth.jsx'
import { submitCreation } from '../creation-recovery.js'
import CreationRecovery from './CreationRecovery.jsx'
import { Modal } from './ui.jsx'

export default function DestinationCorrection({ document: doc, disabled = false, onChanged }) {
  const { user, api, smartflow } = useAuth()
  const id = useId()
  const [open, setOpen] = useState(false)
  const [snapshot, setSnapshot] = useState(null)
  const [offices, setOffices] = useState([])
  const [destination, setDestination] = useState('')
  const [reason, setReason] = useState('')
  const [confirmed, setConfirmed] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [retry, setRetry] = useState(0)
  useEffect(() => {
    if (!open) return
    let cancelled = false
    smartflow.offices().then(data => {
      if (!cancelled) { setOffices(data.offices || []); setError(''); setLoading(false) }
    }).catch(error => { if (!cancelled) { setError(error.message); setLoading(false) } })
    return () => { cancelled = true }
  }, [open, retry, smartflow])
  if (user.role !== 'staff') return null
  const eligible = doc.can_correct_destination === true
  const reviewed = snapshot || doc
  const unchanged = reviewed.last_movement_id === doc.last_movement_id && reviewed.destination_office_id === doc.destination_office_id && (reviewed.last_destination_correction_id || 0) === (doc.last_destination_correction_id || 0)
  const choices = offices.filter(office => Number(office.id) !== Number(user.office_id) && Number(office.id) !== Number(doc.destination_office_id))
  async function done(result) {
    setOpen(false)
    await onChanged(result)
    window.dispatchEvent(new Event('sf-refresh-requested'))
  }
  async function submit() {
    if (busy || disabled || !eligible || !unchanged || !destination || reason.trim().length < 5 || !confirmed) return
    setBusy(true); setError('')
    try {
      await done(await submitCreation('correction', {
        document_id: reviewed.id,
        expected_movement_id: reviewed.last_movement_id,
        expected_destination_office_id: reviewed.destination_office_id,
        expected_correction_id: reviewed.last_destination_correction_id || 0,
        destination_office_id: Number(destination), reason: reason.trim(), correction_confirmed: true,
      }, api))
    } catch (error) { setError(error.message) }
    finally { setBusy(false) }
  }
  return <>
    <CreationRecovery kind="correction" onRecovered={done} />
    {eligible ? <button type="button" className="btn-secondary" disabled={disabled || busy} onClick={() => {
      setSnapshot({...doc}); setDestination(''); setReason(''); setConfirmed(false); setError(''); setLoading(true); setOpen(true)
    }}>Correct recorded destination</button> : null}
    <Modal open={open} title="Correct recorded destination" onClose={() => { if (!busy) setOpen(false) }} footer={<>
      <button type="button" className="btn-secondary" disabled={busy} onClick={() => setOpen(false)}>Cancel</button>
      <button type="button" className="btn" disabled={busy || disabled || loading || !eligible || !unchanged || !destination || reason.trim().length < 5 || !confirmed} onClick={submit}>{busy ? 'Recording correction…' : 'Confirm correction'}</button>
    </>}>
      <p>Correct the destination of this unreceived OUT. The original entry and correction reason remain in its history. This records no receipt or additional handoff.</p>
      <p><strong>{reviewed.id}</strong> · Recorded destination: {reviewed.destination_office_name}</p>
      {!unchanged || !eligible ? <p className="error" role="alert">This folder changed. Close this form and review its current destination before correcting it.</p> : null}
      {error ? <div className="error" role="alert">{error} {!offices.length ? <button type="button" className="btn-ghost" onClick={() => { setLoading(true); setRetry(value => value + 1) }}>Retry offices</button> : null}</div> : null}
      <div className="field"><label htmlFor={`${id}-office`}>Correct destination</label><select id={`${id}-office`} value={destination} disabled={busy || loading} onChange={event => { setDestination(event.target.value); setConfirmed(false) }}><option value="">Choose an office</option>{choices.map(office => <option key={office.id} value={office.id}>{office.name}</option>)}</select></div>
      <div className="field"><label htmlFor={`${id}-reason`}>Reason for correction</label><textarea id={`${id}-reason`} rows={3} minLength={5} maxLength={1000} value={reason} disabled={busy} onChange={event => setReason(event.target.value)} /></div>
      <label className="document-confirm"><input type="checkbox" checked={confirmed} disabled={busy} onChange={event => setConfirmed(event.target.checked)} /> I verified the actual destination and this folder has not been received in SmartFlow.</label>
    </Modal>
  </>
}
