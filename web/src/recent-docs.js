// Folders this account opened lately, for one-tap lookup on Scan and History (the phone keeps the same five).

const MAX_RECENT = 5

function storage() {
  try { return window.localStorage } catch { return null }
}

// Kept per account, so a shared browser does not show one person's folders to the next.
export const recentDocsKey = userId => `sf_recent_docs_v1_${userId}`

/** `000003 · DV – Road Repair`, or the full ID when the folder's name is not known. */
export function recentChipLabel({ id, title = '' }) {
  const name = String(title || '').trim()
  if (!name) return id
  return `${String(id).replace(/^DOC-\d{4}-/, '')} · ${name}`
}

function readList(userId) {
  try {
    const parsed = JSON.parse(storage()?.getItem(recentDocsKey(userId)) || '[]')
    if (!Array.isArray(parsed)) return []
    return parsed
      .filter(entry => entry && typeof entry.id === 'string' && entry.id.trim())
      .map(entry => ({ id: entry.id.trim(), title: typeof entry.title === 'string' ? entry.title : '' }))
      .slice(0, MAX_RECENT)
  } catch { return [] }
}

export function loadRecentDocs(userId) {
  return readList(userId)
}

/** Puts `id` first (keeping a known name when this lookup has none) and returns the list now stored. */
export function rememberRecentDoc(userId, id, title = '') {
  const clean = String(id || '').trim()
  if (!clean) return readList(userId)
  const previous = readList(userId)
  const known = previous.find(entry => entry.id === clean)
  const name = String(title || '').trim() || known?.title || ''
  const next = [{ id: clean, title: name }, ...previous.filter(entry => entry.id !== clean)].slice(0, MAX_RECENT)
  try { storage()?.setItem(recentDocsKey(userId), JSON.stringify(next)) } catch { /* the list still shows for this visit */ }
  return next
}

export function clearRecentDocs(userId) {
  try { storage()?.removeItem(recentDocsKey(userId)) } catch { /* nothing stored to clear */ }
  return []
}

/** What the clipboard holds as text, or why it could not be read. */
export async function readClipboardText() {
  try {
    const text = String(await navigator.clipboard.readText() || '').trim()
    return text ? { text } : { error: 'Clipboard is empty.' }
  } catch {
    return { error: 'Could not read the clipboard. Paste into the field with Ctrl+V instead.' }
  }
}
