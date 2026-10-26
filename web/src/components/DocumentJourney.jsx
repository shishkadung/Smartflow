import { formatWhen } from '../tracking.js'
import { elapsedLabel } from '../document-queue.js'

export function FolderReceiptEvidence({ receipt }) {
  if (!receipt) return <p className="muted">Contents not recorded for this receipt.</p>
  const status = receipt.status
  const totals = [
    typeof receipt.registered_total_pages === 'number' ? `${receipt.registered_total_pages} registered pages` : '',
    typeof receipt.total_pages === 'number' ? `${receipt.total_pages} received pages` : '',
  ].filter(Boolean)
  return <div className="folder-contents-summary">
    <strong>{status === 'complete' ? 'Receipt contents checked complete' : status === 'incomplete' ? 'Receipt contents incomplete' : status === 'discrepancy' ? 'Receipt contents discrepancy recorded' : 'Recorded receipt contents'}</strong>
    <p>{totals.length ? totals.join(' · ') : 'Page totals not recorded for this receipt.'}</p>
    {Array.isArray(receipt.items) && receipt.items.length ? <ul>{receipt.items.map((item, index) => {
      const registered = typeof item.registered_pages === 'number'
      const received = typeof item.pages === 'number'
      const different = registered && received && item.pages !== item.registered_pages
      const difference = different ? Math.abs(item.pages - item.registered_pages) : 0
      return <li key={item.id || index}>{item.name || 'Recorded item'}: {registered ? `${item.registered_pages} registered → ` : ''}{received ? `${item.pages} received` : 'received count not recorded'}{different ? ` · ${difference} ${item.pages < item.registered_pages ? `${difference === 1 ? 'page' : 'pages'} missing` : `extra ${difference === 1 ? 'page' : 'pages'}`}` : ''}{item.required && item.pages === 0 ? ' · required item missing' : ''}</li>
    })}</ul> : null}
    {receipt.reason ? <p className="timeline__note">{receipt.reason}</p> : null}
  </div>
}

export default function DocumentJourney({ document: doc }) {
  const steps = doc.journey || []
  const filed = Boolean(doc.filed_at || doc.filed_by?.filed_at)
  return <section className="document-journey" aria-label="Document journey">
    <h3 className="section-title">Document journey</h3>
    <p className="muted">{doc.tray === 'completed' ? `Completed at ${doc.current_office_name}.` : doc.current_status === 'OUT' ? `Awaiting receipt at ${doc.destination_office_name || 'the receiving office'}. Last sent by ${doc.current_office_name}.` : `Currently held by ${doc.current_office_name}.`}</p>
    {steps.length ? <ol className="journey-steps">{steps.map((step, index) => <li key={step.id} className={step.is_current ? 'is-current' : ''} style={{ '--i': Math.min(index, 8) }}>
      <div className="journey-steps__head"><strong>{step.status === 'IN' ? `Received at ${step.office_name}` : `Sent from ${step.office_name}`}</strong>{step.is_current ? <span className="status-pill">Latest</span> : null}</div>
      {step.status === 'OUT' ? <p>To {step.destination_office_name || 'Unspecified office'}</p> : null}
      <p className="muted">{formatWhen(step.scanned_at)} · {step.user_name}</p>
      <p className="journey-duration">{step.is_current && doc.tray === 'completed' ? `${filed ? 'Filed · ' : ''}Journey complete` : <>{step.duration_kind === 'at_office' ? 'Time at office' : 'Time in transit'}: {elapsedLabel(step.elapsed_hours)}{step.is_current ? ' · ongoing' : ''}</>}</p>
      {step.remarks ? <p className="muted">{step.remarks}</p> : null}
      {step.status === 'IN' ? <FolderReceiptEvidence receipt={step.contents_receipt} /> : null}
      {(step.destination_corrections || []).map(correction => <div key={correction.id} className="hint">
        <strong>Destination corrected: {correction.previous_destination_office_name} → {correction.destination_office_name}</strong>
        <p>{correction.reason}</p>
        <p className="muted">{formatWhen(correction.corrected_at)} · {correction.corrected_by_name}</p>
      </div>)}
    </li>)}</ol> : <p className="muted">No custody events recorded.</p>}
  </section>
}
