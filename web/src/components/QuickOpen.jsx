import { recentChipLabel } from '../recent-docs.js'

/** Recently opened tracking IDs. The chips wrap so an ID is never cut. */
export default function QuickOpen({ docs, disabled = false, onOpen, onClear }) {
  if (!docs || docs.length === 0) return null
  return <div className="quick-open" role="group" aria-label="Recently opened folders">
    <div className="quick-open__head">
      <strong>Quick open</strong>
      <button type="button" className="btn-ghost" disabled={disabled} onClick={onClear}>Clear</button>
    </div>
    <div className="quick-open__chips">
      {docs.map(doc => <button key={doc.id} type="button" className="quick-open__chip" title={doc.id} disabled={disabled} onClick={() => onOpen(doc.id)}>{recentChipLabel(doc)}</button>)}
    </div>
  </div>
}
