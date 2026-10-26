// Office attachment checklists: heads publish attachment names; actual page counts are always entered separately.

export const MAX_ATTACHMENTS = 20
export const CHECKLIST_NAME_MAX = 100

const MAIN = 'Main document'

/** True once the contents form holds anything a replacement would lose. */
export function inventoryDirty(inventory) {
  const items = inventory?.items || []
  return items.length > 1 || String(items[0]?.pages ?? '') !== '' || Boolean(inventory?.count_confirmed)
}

/** Published checklists for one document type, in the order the server returned them. */
export function checklistsForType(rows, type) {
  return (rows || []).filter(row => row?.document_type === type)
}

/** The contents form a checklist fills in: its attachment names and required flags, with every page count blank and nothing confirmed. */
export function inventoryFromChecklist(row) {
  const attachments = Array.isArray(row?.items) ? row.items.slice(0, MAX_ATTACHMENTS) : []
  return {
    count_confirmed: false,
    items: [
      { name: MAIN, pages: '', required: true },
      ...attachments.map(item => ({ name: String(item?.name ?? ''), pages: '', required: item?.required === true })),
    ],
  }
}

/** The attachments of a contents form ready to publish, or the reason they are not. */
export function readChecklistAttachments(inventory) {
  const attachments = (inventory?.items || []).slice(1)
  if (attachments.length === 0) return { error: 'Add at least one attachment before publishing.' }
  const names = new Set([MAIN.toLowerCase()])
  const items = []
  for (const attachment of attachments) {
    const name = String(attachment.name ?? '').trim()
    if (!name || name.length > CHECKLIST_NAME_MAX || names.has(name.toLowerCase())) {
      return { error: 'Give each attachment a distinct name (up to 100 characters).' }
    }
    names.add(name.toLowerCase())
    items.push({ name, required: attachment.required === true })
  }
  return { items }
}
