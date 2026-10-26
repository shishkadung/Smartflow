import { useEffect, useState } from 'react'
import { useAuth } from '../auth.jsx'
import { SfIcon } from '../icons.jsx'
import { CHECKLIST_NAME_MAX, checklistsForType, inventoryDirty, inventoryFromChecklist, readChecklistAttachments } from '../folder-checklists.js'
import { Modal } from './ui.jsx'

const errorText = (error, fallback) => (error && error.message) || fallback

/**
 * An office's published attachment checklists for one document type, as on the phone: staff apply one to fill in
 * attachment names (page counts stay blank); heads and administrators also publish and archive them when `management` is set.
 */
export default function FolderChecklists({ type, inventory, onApply, disabled = false, management = false }) {
  const { user, smartflow } = useAuth()
  const manager = user?.role === 'head' || user?.role === 'admin'
  const [rows, setRows] = useState([])
  const [loaded, setLoaded] = useState(false)
  const [loadError, setLoadError] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [reload, setReload] = useState(0)
  const [dialog, setDialog] = useState(null)
  const [publishName, setPublishName] = useState('')

  useEffect(() => {
    let cancelled = false
    // oxlint-disable-next-line react/set-state-in-effect -- A refresh keeps the last loaded checklists while it checks them again.
    setBusy(true)
    smartflow.folderChecklists()
      .then((data) => {
        if (cancelled) return
        setRows(Array.isArray(data.checklists) ? data.checklists : [])
        setLoaded(true)
        setLoadError('')
      })
      .catch((e) => { if (!cancelled) setLoadError(errorText(e, 'Could not load checklists.')) })
      .finally(() => { if (!cancelled) setBusy(false) })
    return () => { cancelled = true }
  }, [smartflow, reload])

  const shown = checklistsForType(rows, type)
  const refreshEnabled = !disabled && !busy
  const enabled = refreshEnabled && !loadError

  function use(row) {
    if (!enabled) return
    setError('')
    if (inventoryDirty(inventory)) setDialog({ kind: 'replace', row })
    else onApply(inventoryFromChecklist(row))
  }

  function replace() {
    const row = dialog?.row
    setDialog(null)
    if (row && enabled) onApply(inventoryFromChecklist(row))
  }

  function askPublish() {
    if (!enabled) return
    const result = readChecklistAttachments(inventory)
    if (result.error) { setError(result.error); return }
    setError('')
    setPublishName('')
    setDialog({ kind: 'publish', items: result.items })
  }

  async function write(body, failure) {
    setDialog(null)
    setBusy(true)
    setError('')
    try {
      await smartflow.saveFolderChecklist(body)
      setReload((value) => value + 1)
    } catch (e) {
      setError(errorText(e, failure))
      setBusy(false)
    }
  }

  const name = publishName.trim()
  return (
    <div className="folder-checklists">
      <div className="folder-checklists__head">
        <h4>{management ? 'Office attachment checklists' : 'Office checklist'}</h4>
        {management ? null : (
          <button type="button" className="btn-ghost folder-checklists__refresh" aria-label="Refresh checklists" title="Refresh checklists" disabled={!refreshEnabled} onClick={() => setReload((value) => value + 1)}>
            <SfIcon name="refresh" size={18} />
          </button>
        )}
      </div>
      {loadError ? (
        <div className="error" role="alert">
          {loaded ? `Refresh failed. Showing the last loaded checklists, which may be out of date. ${loadError}` : `Checklists unavailable. ${loadError}`}
          <button type="button" className="btn-secondary" disabled={!refreshEnabled} onClick={() => setReload((value) => value + 1)}>Retry</button>
        </div>
      ) : null}
      {error ? <div className="error" role="alert">{error}</div> : null}
      {busy ? <p className="muted" role="status">Loading checklists…</p> : null}
      {!busy && loaded && !loadError && shown.length === 0 ? (
        <p className="muted">
          {management
            ? 'No published checklist for this document type. Define approved attachment requirements below.'
            : 'No published checklist. Enter your office’s approved requirements below.'}
        </p>
      ) : null}
      <ul className="folder-checklists__list">
        {shown.map((row) => (
          <li key={row.id}>
            <button type="button" className="btn-secondary" disabled={!enabled} onClick={() => use(row)}>Use {row.name}</button>
            {manager ? (
              <button type="button" className="btn-ghost" aria-label={`Archive ${row.name}`} title="Archive checklist" disabled={!enabled} onClick={() => setDialog({ kind: 'archive', row })}>
                <SfIcon name="archive" size={18} />
              </button>
            ) : null}
          </li>
        ))}
      </ul>
      {manager || management ? (
        <div className="folder-checklists__actions">
          {manager ? <button type="button" className="btn-ghost" disabled={!enabled} onClick={askPublish}>Publish attachments as checklist</button> : null}
          {management ? <button type="button" className="btn-ghost" disabled={!refreshEnabled} onClick={() => setReload((value) => value + 1)}>Refresh checklists</button> : null}
        </div>
      ) : null}

      <Modal
        open={dialog?.kind === 'replace'}
        title="Replace the contents checklist?"
        onClose={() => setDialog(null)}
        footer={<div className="row-btns"><button type="button" className="btn-secondary" onClick={() => setDialog(null)}>Cancel</button><button type="button" className="btn" onClick={replace}>Replace</button></div>}
      >
        <p>{management ? 'This replaces the attachment names and required flags in this draft.' : 'This replaces the attachment names and clears all page counts and physical confirmation.'}</p>
      </Modal>

      <Modal
        open={dialog?.kind === 'publish'}
        title="Publish office checklist"
        onClose={() => setDialog(null)}
        footer={<div className="row-btns"><button type="button" className="btn-secondary" onClick={() => setDialog(null)}>Cancel</button><button type="submit" form="publish-checklist-form" className="btn" disabled={!name}>Publish</button></div>}
      >
        <form id="publish-checklist-form" onSubmit={(e) => { e.preventDefault(); if (name && dialog?.items) write({ name, document_type: type, items: dialog.items }, 'Could not publish the checklist.') }}>
          <p className="muted">Publish only requirements approved by your office. Page counts will stay blank when staff apply this checklist.</p>
          <div className="field">
            <label htmlFor="checklist-name">Checklist name</label>
            <input id="checklist-name" value={publishName} maxLength={CHECKLIST_NAME_MAX} onChange={(e) => setPublishName(e.target.value)} autoComplete="off" />
          </div>
        </form>
      </Modal>

      <Modal
        open={dialog?.kind === 'archive'}
        title={`Archive ${dialog?.row?.name ?? 'checklist'}?`}
        onClose={() => setDialog(null)}
        footer={<div className="row-btns"><button type="button" className="btn-secondary" onClick={() => setDialog(null)}>Cancel</button><button type="button" className="btn" onClick={() => write({ action: 'archive', id: dialog.row.id }, 'Could not archive the checklist.')}>Archive</button></div>}
      >
        <p>Existing registered inventories stay unchanged.</p>
      </Modal>
    </div>
  )
}
