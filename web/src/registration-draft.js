import { useEffect, useRef, useState } from 'react'

// A half-filled registration form survives a reload, as it does on the phone. Same stored fields, no physical confirmation.

const KEY_PREFIX = 'sf_registration_draft_v1_'
const MAX_ATTACHMENTS = 20
const SAVE_DELAY_MS = 500

export const DRAFT_RESTORED = 'Draft restored. Recheck the actual contents and physical confirmation.'
export const DRAFT_RESTORE_FAILED = 'Draft could not be restored. Registration is still available.'
export const DRAFT_SAVED = 'Draft saved on this browser.'
export const DRAFT_UNAVAILABLE = 'Draft saving unavailable. Keep this form open.'

export function registrationDraftKey(user, requestId = '') {
  return `${KEY_PREFIX}${user?.id}_${user?.office_id}${requestId ? `_request_${requestId}` : ''}`
}

function inventoryDirty(inventory) {
  const items = inventory?.items || []
  return items.length > 1 || String(items[0]?.pages ?? '') !== '' || Boolean(inventory?.count_confirmed)
}

/** True once anything differs from a blank form for this office. */
export function draftIsDirty(values, firstType = '') {
  return Boolean(
    String(values.title ?? '').trim()
    || String(values.otherName ?? '').trim()
    || String(values.comment ?? '').trim()
    || String(values.reference ?? '').trim()
    || String(values.payee ?? '').trim()
    || String(values.fundSource ?? '').trim()
    || values.dueDate
    || values.receivedFrom
    || (values.type && values.type !== firstType)
    || inventoryDirty(values.inventory),
  )
}

/** The stored text for a form, or null when the form is blank (nothing worth keeping). */
export function serializeDraft(values, firstType = '') {
  if (!draftIsDirty(values, firstType)) return null
  return JSON.stringify({
    title: values.title,
    other: values.otherName,
    comment: values.comment,
    reference: values.reference,
    payee: values.payee,
    fund: values.fundSource,
    type: values.type,
    due: values.dueDate || null,
    sender: values.receivedFrom || null,
    inventory: { items: (values.inventory?.items || []).map(item => ({ name: item.name, pages: item.pages, required: item.required })) },
  })
}

function readItems(inventory) {
  if (!inventory || !Array.isArray(inventory.items)) throw new Error('Draft contents are malformed.')
  const rows = inventory.items.slice(0, MAX_ATTACHMENTS + 1).map(item => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) throw new Error('Draft contents are malformed.')
    return { name: String(item.name ?? ''), pages: String(item.pages ?? ''), required: item.required === true }
  })
  if (rows.length === 0) return null
  rows[0] = { name: 'Main document', pages: rows[0].pages, required: true }
  return rows
}

/** Read stored text back into form values. Throws when it is not a draft; never restores the count confirmation. */
export function parseDraft(raw, { types = [] } = {}) {
  const value = JSON.parse(raw)
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Draft is malformed.')
  const text = key => (value[key] == null ? '' : String(value[key]))
  const items = value.inventory == null ? null : readItems(value.inventory)
  const due = /^\d{4}-\d{2}-\d{2}/.exec(text('due'))
  return {
    title: text('title'),
    otherName: text('other'),
    comment: text('comment'),
    reference: text('reference'),
    payee: text('payee'),
    fundSource: text('fund'),
    receivedFrom: text('sender'),
    dueDate: due ? due[0] : '',
    type: types.includes(value.type) ? value.type : null,
    inventory: items ? { count_confirmed: false, items } : null,
  }
}

/** The form with a stored draft laid over it. A type this office cannot register is ignored. */
export function applyDraft(values, draft) {
  const { type, inventory, ...fields } = draft
  return { ...values, ...fields, type: type ?? values.type, inventory: inventory ?? values.inventory }
}

function storage() {
  try { return window.localStorage } catch { return null }
}

function persist(key, payload) {
  const store = storage()
  if (!store) return false
  try {
    if (payload == null) store.removeItem(key)
    else store.setItem(key, payload)
    return true
  } catch { return false }
}

/**
 * Keeps the registration form in this browser while it is being filled.
 * `apply` receives the whole form with the draft laid over it; the page sets its own fields from it.
 */
export function useRegistrationDraft({ storageKey, enabled, overwrite, values, firstType, types, apply, created }) {
  const [state, setState] = useState({ key: '', note: '', alert: false })
  const saved = useRef(null)
  const latest = useRef({})
  const ready = enabled && state.key === storageKey
  const payload = serializeDraft(values, firstType)

  useEffect(() => {
    latest.current = { key: storageKey, payload, ready, created, values, firstType, types, apply, overwrite }
  })

  useEffect(() => {
    if (!enabled || state.key === storageKey) return
    const { values: current, firstType: first, types: allowed, apply: set, overwrite: force } = latest.current
    let next = { key: storageKey, note: '', alert: false }
    try {
      const raw = storage()?.getItem(storageKey)
      if (raw && (force || !draftIsDirty(current, first))) {
        const merged = applyDraft(current, parseDraft(raw, { types: allowed }))
        set(merged)
        saved.current = serializeDraft(merged, first)
        next = { key: storageKey, note: DRAFT_RESTORED, alert: true }
      }
    } catch {
      next = { key: storageKey, note: DRAFT_RESTORE_FAILED, alert: true }
    }
    // oxlint-disable-next-line react/set-state-in-effect -- Restoring a stored draft is the one-time sync of this form with browser storage.
    setState(next)
  }, [enabled, storageKey, state.key])

  useEffect(() => {
    if (!ready || created || payload === saved.current) return undefined
    const timer = setTimeout(() => {
      const ok = persist(storageKey, payload)
      if (ok) saved.current = payload
      setState(previous => (previous.key === storageKey ? { ...previous, note: !ok ? DRAFT_UNAVAILABLE : payload == null ? '' : DRAFT_SAVED, alert: !ok } : previous))
    }, SAVE_DELAY_MS)
    return () => clearTimeout(timer)
  }, [ready, created, payload, storageKey])

  // A registered folder no longer needs its draft.
  useEffect(() => {
    if (!created) return
    persist(storageKey, null)
    saved.current = null
  }, [created, storageKey])

  // Leaving the page flushes what the short delay has not written yet.
  useEffect(() => {
    const flush = () => {
      const { key, payload: pending, ready: isReady, created: done } = latest.current
      if (!isReady || done || pending === saved.current) return
      if (persist(key, pending)) saved.current = pending
    }
    const onVisibility = () => { if (document.visibilityState === 'hidden') flush() }
    window.addEventListener('pagehide', flush)
    document.addEventListener('visibilitychange', onVisibility)
    return () => {
      window.removeEventListener('pagehide', flush)
      document.removeEventListener('visibilitychange', onVisibility)
      flush()
    }
  }, [])

  return { note: ready ? state.note : '', alert: state.alert }
}
