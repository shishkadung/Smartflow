import { StatusPill } from './ui.jsx'
import { formatWhen } from '../tracking.js'
import { FolderContentsSummary } from './FolderContents.jsx'

export function DocumentStatus({ document: doc }) {
  const completed = doc.tray === 'completed'
  const label = completed ? 'Completed' : doc.tray === 'incoming' ? 'Awaiting receipt' : doc.current_status === 'OUT' ? 'Forwarded' : doc.current_status === 'IN' ? 'In office' : 'Registered'
  return <StatusPill tone={completed || doc.current_status === 'IN' ? 'ok' : doc.current_status === 'OUT' ? 'warn' : 'neutral'}>{label}</StatusPill>
}

export default function DocumentSummary({ document: doc }) {
  return (
    <div className="document-summary">
      <h3 className="document-title">{doc.title}</h3>
      <div className="document-summary__identity"><span className="document-id">{doc.id}</span><span className="document-summary__status"><DocumentStatus document={doc} />{doc.is_overdue && doc.tray !== 'completed' ? <StatusPill tone="bad">Overdue</StatusPill> : null}</span></div>
      <dl className="document-meta document-meta--primary">
        {doc.current_office_name ? <div><dt>{doc.current_status === 'OUT' ? 'Sent from' : 'Current office'}</dt><dd>{doc.current_office_name}</dd></div> : null}
        {doc.current_status === 'OUT' ? <div><dt>Destination</dt><dd>{doc.destination_office_name || 'Unspecified office'}</dd></div> : null}
        {doc.current_status === 'OUT' ? <div><dt>Receipt</dt><dd>Not recorded by the receiving office yet</dd></div> : null}
        {doc.tray !== 'completed' && doc.due_at_display && doc.due_at_display !== '—' ? <div className={doc.is_overdue ? 'document-summary__deadline is-overdue' : 'document-summary__deadline'}><dt>Deadline</dt><dd>{doc.due_at_display}{doc.is_overdue ? <span>Past deadline</span> : null}</dd></div> : null}
      </dl>
      {['incomplete', 'discrepancy'].includes(doc.contents_status || doc.folder_inventory?.status) ? <p className="document-content-warning">{(doc.contents_status || doc.folder_inventory?.status) === 'incomplete' ? 'Folder contents incomplete.' : 'Folder contents discrepancy recorded.'} Review the counts and notes below.</p> : null}
      <details className="document-secondary">
        <summary>Folder details and contents</summary>
        <dl className="document-meta">
        {doc.last_scanned_at ? <div><dt>Last movement</dt><dd>{formatWhen(doc.last_scanned_at)}</dd></div> : null}
        <div><dt>Reference</dt><dd>{doc.reference_no || '—'}</dd></div>
        <div><dt>Type</dt><dd>{doc.type}</dd></div>
        <div><dt>Origin</dt><dd>{doc.origin_office_name}</dd></div>
        </dl>
        <FolderContentsSummary document={doc} />
      </details>
    </div>
  )
}
