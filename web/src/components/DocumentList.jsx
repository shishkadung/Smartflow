import { DocumentStatus } from './DocumentSummary.jsx'
import { elapsedLabel } from '../document-queue.js'
import { formatWhen } from '../tracking.js'

function officeLabel(doc) {
  if (doc.tray === 'incoming') return `From ${doc.current_office_name || 'Unspecified office'}`
  if (doc.tray === 'forwarded') return `To ${doc.destination_office_name || 'Unspecified office'}`
  return doc.current_office_name || 'Unspecified office'
}

function waitingLabel(doc) {
  return doc.tray === 'completed' ? 'Filed' : elapsedLabel(doc.hours_waiting)
}

export default function DocumentList({ documents, selected, busy = false, onSelect }) {
  function select(doc) {
    if (!busy) onSelect(doc.id)
  }

  return <>
    <div className="desktop-document-list table-wrap">
      <table className="data-table document-table">
        <caption className="sr-only">Folders in this view. Select a folder to review its details.</caption>
        <colgroup>
          <col className="document-table__tracking-column" /><col className="document-table__title-column" />
          <col className="document-table__office-column" /><col className="document-table__status-column" />
          <col className="document-table__wait-column" /><col className="document-table__deadline-column" />
        </colgroup>
        <thead><tr>{['Tracking ID', 'Title', 'Office', 'Status', 'Wait', 'Deadline'].map(label => <th key={label} scope="col">{label}</th>)}</tr></thead>
        <tbody>{documents.map(doc => <tr key={doc.id} className={`document-table-row${selected === doc.id ? ' is-selected' : ''}`} aria-selected={selected === doc.id} onClick={() => select(doc)}>
          <td><button className="document-table__select" type="button" disabled={busy} aria-pressed={selected === doc.id} aria-label={`Open ${doc.id}: ${doc.title || 'Folder'}`} aria-controls="document-details" onClick={event => { event.stopPropagation(); select(doc) }}>{doc.id}</button></td>
          <td><strong className="document-table__title">{doc.title || 'Folder'}</strong><span className="document-table__reference">{doc.reference_no || '—'}</span></td>
          <td>{officeLabel(doc)}</td>
          <td><DocumentStatus document={doc} /></td>
          <td className={doc.is_overdue ? 'queue-overdue' : undefined}>{doc.is_overdue ? <span className="document-table__overdue">Overdue</span> : null}{waitingLabel(doc)}</td>
          <td>{doc.due_at_display || (doc.due_at ? formatWhen(doc.due_at) : '—')}</td>
        </tr>)}</tbody>
      </table>
    </div>
    <div className="mobile-document-list">{documents.map(doc => <button className={`document-row${selected === doc.id ? ' is-selected' : ''}`} aria-pressed={selected === doc.id} key={doc.id} type="button" disabled={busy} onClick={() => select(doc)}>
      <span className="document-row__identity"><span className="document-id">{doc.id}</span><DocumentStatus document={doc} /></span>
      <strong className="document-row__title">{doc.title}</strong><span className="muted">Reference: {doc.reference_no || '—'}</span>
      <span className={doc.is_overdue ? 'queue-overdue' : 'muted'}>{doc.is_overdue ? 'Overdue · ' : ''}{doc.tray === 'completed' ? 'Filed' : `Waiting ${waitingLabel(doc)}`}</span>
      <span className="muted">{officeLabel(doc)}</span>
    </button>)}</div>
  </>
}
