import { useEffect, useRef, useState } from 'react'
import { Modal } from './ui.jsx'

export function FolderFilingConfirmation({ document: doc, onCancel, onConfirm }) {
  return <Modal open={Boolean(doc)} title="File this folder?" onClose={onCancel} footer={<>
    <button type="button" className="btn-secondary" onClick={onCancel}>Cancel</button>
    <button type="button" className="btn" onClick={onConfirm}>Confirm filing</button>
  </>}>
    <p><strong>{doc?.title}</strong><br />{doc?.id}</p>
    <p>File this folder only when the work is complete and it will remain at your office. It leaves the active trays and can no longer be sent to another office.</p>
    <p className="muted">The folder and its full custody history remain available under Completed.</p>
  </Modal>
}

// oxlint-disable-next-line react/only-export-components -- The paired confirmation hook owns this dialog's promise lifecycle.
export function useFolderFiling() {
  const [doc, setDoc] = useState(null)
  const pending = useRef(null)
  useEffect(() => () => { pending.current?.(false) }, [])
  function close(confirmed = false) { pending.current?.(confirmed); pending.current = null; setDoc(null) }
  function requestFiling(document) {
    setDoc(document)
    return new Promise(resolve => { pending.current = resolve })
  }
  return { requestFiling, filingDialog: <FolderFilingConfirmation document={doc} onCancel={() => close()} onConfirm={() => close(true)} /> }
}
