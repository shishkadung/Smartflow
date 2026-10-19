import { formatWhen } from '../tracking.js'
import { elapsedLabel } from '../document-queue.js'

export default function DocumentJourney({ document: doc }) {
  const steps = doc.journey || []
  return <section className="document-journey" aria-label="Document journey">
    <h3 className="section-title">Document journey</h3>
    <p className="muted">{doc.tray === 'completed' ? `Completed at ${doc.current_office_name}.` : doc.current_status === 'OUT' ? `Awaiting receipt at ${doc.destination_office_name || 'the receiving office'}. Last sent by ${doc.current_office_name}.` : `Currently held by ${doc.current_office_name}.`}</p>
    {steps.length ? <ol className="journey-steps">{steps.map(step => <li key={step.id} className={step.is_current ? 'is-current' : ''}>
      <div className="journey-steps__head"><strong>{step.status === 'IN' ? `Received at ${step.office_name}` : `Sent from ${step.office_name}`}</strong>{step.is_current ? <span className="status-pill">Latest</span> : null}</div>
      {step.status === 'OUT' ? <p>To {step.destination_office_name || 'Unspecified office'}</p> : null}
      <p className="muted">{formatWhen(step.scanned_at)} · {step.user_name}</p>
      <p className="journey-duration">{step.is_current && doc.tray === 'completed' ? 'Filed · journey complete' : <>{step.duration_kind === 'at_office' ? 'Time at office' : 'Time in transit'}: {elapsedLabel(step.elapsed_hours)}{step.is_current ? ' · ongoing' : ''}</>}</p>
      {step.remarks ? <p className="muted">{step.remarks}</p> : null}
      {(step.destination_corrections || []).map(correction => <div key={correction.id} className="hint">
        <strong>Destination corrected: {correction.previous_destination_office_name} → {correction.destination_office_name}</strong>
        <p>{correction.reason}</p>
        <p className="muted">{formatWhen(correction.corrected_at)} · {correction.corrected_by_name}</p>
      </div>)}
    </li>)}</ol> : <p className="muted">No custody events recorded.</p>}
  </section>
}
