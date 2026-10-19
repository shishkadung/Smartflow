import { Segmented } from './ui.jsx'
import { handoffDestinations } from '../custody-actions.js'

// Scan and Documents expose the same next-handoff controls; custody gates stay with each screen.
export default function FolderHandoff({ document: doc, offices, user, destination, isReturn, returnReason, disabled, pending,
  officeError, onRetryOffices, onDestination, onMode, onReason, onSend, onFile }) {
  const destinations = handoffDestinations(doc, offices, user, isReturn)
  const hasPrevious = (doc.visited_office_codes || []).some(code => String(code).toUpperCase() !== String(user.office_code || '').toUpperCase())
  const sendName = destinations.find(office => String(office.id) === String(destination))?.name || ''
  const canSend = !officeError && destinations.some(office => String(office.id) === String(destination)) && (!isReturn || returnReason.trim().length >= 5)
  return <fieldset disabled={disabled} className="document-action" aria-label="Folder handoff" style={{ border: 0, padding: 0, minWidth: 0 }}>
    {doc.can_file ? <button className="btn" type="button" onClick={onFile}>{pending === 'file' ? 'Filing…' : 'File this folder'}</button> : null}
    {officeError ? <div className="error" role="alert">Receiving offices unavailable. {officeError}<button type="button" className="btn-secondary" onClick={onRetryOffices}>Retry receiving offices</button></div> : null}
    {!doc.can_return_to_accounting && hasPrevious ? <Segmented value={isReturn ? 'return' : 'forward'} onChange={value => { if (!disabled) onMode(value === 'return') }} options={[{ value: 'forward', label: 'Forward (OUT)' }, { value: 'return', label: 'Return for correction' }]} /> : null}
    <label className="field">{isReturn || doc.can_return_to_accounting ? 'Return to' : 'Send to'}<select value={destination} onChange={event => onDestination(event.target.value)}><option value="">Choose an office</option>{destinations.map(office => <option key={office.id} value={office.id}>{office.name}</option>)}</select></label>
    {isReturn ? <label className="field">Reason for return (required)<textarea value={returnReason} onChange={event => onReason(event.target.value)} minLength={5} maxLength={200} rows={3} placeholder="Describe what needs correction." /></label> : null}
    <p className="muted">{doc.can_file ? 'Send it only if another office still needs the folder.' : 'Hand over the actual folder. It appears in that office\'s Incoming tray.'}</p>
    <button className={doc.can_file ? 'btn-secondary' : 'btn'} type="button" disabled={!canSend} onClick={onSend}>{pending === 'OUT' ? 'Sending…' : doc.can_return_to_accounting ? 'Return to Accounting' : !canSend && !destination ? 'Choose an office' : `${isReturn ? 'Return' : 'Send'} to ${sendName || 'office'}`}</button>
  </fieldset>
}
