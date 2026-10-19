import { useEffect, useRef, useState } from 'react'
import { Modal } from './ui.jsx'

export const emptyInventory = () => ({ count_confirmed: false, items: [{ name: 'Main document', pages: '', required: true }] })
const validPages = value => /^\d+$/.test(String(value)) && Number(value) <= 999
export function readInventory(value) {
  const names = new Set()
  const items = value.items.map((item, i) => ({ ...item, name: i === 0 ? 'Main document' : item.name.trim(), pages: Number(item.pages) }))
  items.forEach((item, i) => {
    if (!validPages(value.items[i].pages) || (i === 0 && item.pages < 1)) throw new Error('Enter actual page counts (main document 1–999; attachments 0–999).')
    if (!item.name || item.name.length > 100 || names.has(item.name.toLowerCase())) throw new Error('Give each attachment a distinct name, up to 100 characters.')
    names.add(item.name.toLowerCase())
  })
  if (items.reduce((sum, item) => sum + item.pages, 0) > 9999) throw new Error('The total may not exceed 9999 pages.')
  if (!value.count_confirmed) throw new Error('Confirm you hold this folder and counted its contents.')
  return { count_confirmed: true, items }
}
export function FolderInventoryEditor({ value, onChange, disabled }) {
  function change(index, field, next) { onChange({ ...value, items: value.items.map((item, i) => i === index ? { ...item, [field]: next } : item) }) }
  return <fieldset disabled={disabled} className="folder-contents"><legend>Folder contents</legend>
    <p className="muted">Count physical pages. Include required items even when missing; enter 0. Your office decides which attachments are required.</p>
    {value.items.map((item, i) => <div key={i} className="folder-item">
      {i > 0 ? <label className="field">Attachment name<input maxLength={100} value={item.name} onChange={e => change(i, 'name', e.target.value)} /></label> : null}
      <label className="field">{i === 0 ? 'Main document pages' : 'Attachment pages'}<input type="number" inputMode="numeric" min={i === 0 ? 1 : 0} max={999} step={1} required value={item.pages} onChange={e => change(i, 'pages', e.target.value)} /></label>
      {i > 0 ? <><label className="document-confirm"><input type="checkbox" checked={item.required} onChange={e => change(i, 'required', e.target.checked)} />Required attachment</label><button type="button" className="btn-ghost" onClick={() => onChange({ ...value, items: value.items.filter((_, index) => i !== index) })}>Remove attachment</button></> : null}
    </div>)}
    {value.items.length < 21 ? <button type="button" className="btn-secondary" onClick={() => onChange({ ...value, items: [...value.items, { name: '', pages: '', required: true }] })}>Add attachment</button> : null}
    <label className="document-confirm"><input type="checkbox" checked={value.count_confirmed} onChange={e => onChange({ ...value, count_confirmed: e.target.checked })} />I physically hold this folder and counted its contents.</label>
  </fieldset>
}
export function FolderContentsSummary({ document: doc }) {
  const inventory = doc.folder_inventory
  if (!inventory) return <p className="muted">Contents not recorded for this folder.</p>
  const receipt = doc.current_contents_receipt
  const status = doc.contents_status || inventory.status
  return <div className="folder-contents-summary">
    <strong className={`folder-contents-status${status === 'complete' ? ' is-complete' : ''}`}>{status === 'incomplete' ? 'Incomplete contents' : status === 'discrepancy' ? 'Contents discrepancy recorded' : receipt ? 'Contents checked complete' : 'Contents declared complete'}</strong>
    <p>{inventory.total_pages} registered pages{receipt ? ` · ${receipt.total_pages} last received` : ''}</p>
    <ul>{(receipt || inventory).items.map(item => <li key={item.id}>{item.name}: {receipt ? `${item.registered_pages} registered → ${item.pages} received` : `${item.pages} pages`}{receipt && item.pages !== item.registered_pages ? ` · ${Math.abs(item.pages - item.registered_pages)} ${item.pages < item.registered_pages ? 'pages missing' : 'extra pages'}` : ''}{item.required && item.pages === 0 ? ' · required item missing' : ''}</li>)}</ul>
    {receipt?.reason ? <p>{receipt.reason}</p> : null}
    {receipt?.checked_at ? <p className="muted">Checked by {receipt.checked_by} · {receipt.office_name}<br />{receipt.checked_at}</p> : null}
  </div>
}
// Both custody screens use the same physical check before sending their API call.
export function useFolderReceipt() {
  const [doc, setDoc] = useState(null)
  const [counts, setCounts] = useState([])
  const [reason, setReason] = useState('')
  const [confirmed, setConfirmed] = useState(false)
  const [error, setError] = useState('')
  const pending = useRef(null)
  useEffect(() => () => { pending.current?.(null) }, [])
  function requestReceipt(document) {
    setCounts((document.folder_inventory?.items || []).map(() => ''))
    setReason(''); setConfirmed(false); setError(''); setDoc(document)
    return new Promise(resolve => { pending.current = resolve })
  }
  function close(value = null) { pending.current?.(value); pending.current = null; setDoc(null) }
  const items = doc?.folder_inventory?.items || []
  const different = items.some((item, i) => counts[i] !== '' && Number(counts[i]) !== item.pages)
  const incomplete = items.some((item, i) => item.required && counts[i] !== '' && (Number(counts[i]) === 0 || Number(counts[i]) < item.pages))
  function submit(e) {
    e.preventDefault()
    if (!confirmed) { setError('Confirm physical receipt first.'); return }
    if (counts.some(value => !validPages(value)) || counts.reduce((sum, value) => sum + Number(value), 0) > 9999) { setError('Enter actual whole page counts (0–999; total up to 9999).'); return }
    if (different && reason.trim().length < 5) { setError('Describe the discrepancy in at least 5 characters.'); return }
    close({ confirmed: true, items: items.map((item, i) => ({ id: item.id, pages: Number(counts[i]) })), reason: reason.trim() })
  }
  const receiptDialog = <Modal open={Boolean(doc)} title="Check folder contents" onClose={() => close()}><form onSubmit={submit}>
    <p>{doc?.id}</p><p className="muted">{items.length ? `${doc.folder_inventory.total_pages} registered pages. Count what actually arrived; use 0 for missing items. The QR does not count pages.` : 'No inventory was recorded for this older folder. Check its reference and confirm physical receipt.'}</p>
    {items.map((item, i) => <label className="field folder-item" key={item.id}>{item.name} — received pages ({item.pages} registered{item.required ? ', required' : ''})<input type="number" inputMode="numeric" required min={0} max={999} step={1} value={counts[i]} onChange={e => { setCounts(counts.map((value, index) => i === index ? e.target.value : value)); setError('') }} /></label>)}
    {items.length && counts.every(value => value !== '') ? <p>{counts.reduce((sum, value) => sum + Number(value), 0)} received / {doc.folder_inventory.total_pages} registered pages · {incomplete ? 'Incomplete contents' : different ? 'Discrepancy' : 'Counts match'}</p> : null}
    {different ? <label className="field">Discrepancy / missing item details<textarea maxLength={1000} rows={3} value={reason} onChange={e => { setReason(e.target.value); setError('') }} /></label> : null}
    <label className="document-confirm"><input type="checkbox" checked={confirmed} onChange={e => setConfirmed(e.target.checked)} />I physically received this folder and checked its reference and contents.</label>
    {error ? <p className="error" role="alert">{error}</p> : null}
    <div className="row-btns"><button type="button" className="btn-secondary" onClick={() => close()}>Cancel</button><button type="submit" className="btn" disabled={!confirmed}>{incomplete ? 'Receive incomplete folder' : different ? 'Receive with discrepancy' : 'Confirm receipt'}</button></div>
  </form></Modal>
  return { requestReceipt, receiptDialog }
}
