// Head dashboard queue: folders that need attention come first; finished folders stay reachable but out of the way.
export const QUEUE_PAGE_SIZE = 20

export const queueFilters = ['active', 'overdue', 'in_office', 'awaiting', 'completed', 'all']
export const queueSorts = ['attention', 'hoursDesc', 'hoursAsc', 'id']

const statusOf = (item) => String(item?.status_label || '').trim().toLowerCase()

export function awaitingReceive(item) {
  return item?.last_status === 'OUT' && String(item?.meta || '').toLowerCase().includes('awaiting receive')
}

/** The one state shown on a card: the server's overdue or completed label wins over the physical position. */
export function queueState(item) {
  const status = statusOf(item)
  if (status === 'overdue') return 'overdue'
  if (awaitingReceive(item)) return 'awaiting'
  if (status === 'completed') return 'completed'
  if (status === 'in_office') return 'in_office'
  return 'other'
}

export function matchesFilter(item, filter) {
  if (filter === 'all') return true
  if (filter === 'active') return statusOf(item) !== 'completed'
  if (filter === 'overdue') return statusOf(item) === 'overdue'
  if (filter === 'in_office') return statusOf(item) === 'in_office'
  if (filter === 'awaiting') return awaitingReceive(item)
  if (filter === 'completed') return statusOf(item) === 'completed'
  return true
}

export function queueCounts(queue) {
  const counts = {}
  for (const filter of queueFilters) counts[filter] = (queue || []).filter((item) => matchesFilter(item, filter)).length
  return counts
}

const rank = { overdue: 0, in_office: 1, awaiting: 2, other: 3, completed: 4 }
const hoursOf = (item) => Number(item?.hours_pending) || 0

/** Sorted copy. "attention" puts overdue first, then the longest waits; completed folders go last, newest first. */
export function sortQueue(list, sort) {
  return [...list].sort((a, b) => {
    if (sort === 'id') return String(a.document_id || '').localeCompare(String(b.document_id || ''))
    if (sort === 'hoursAsc') return hoursOf(a) - hoursOf(b)
    if (sort === 'hoursDesc') return hoursOf(b) - hoursOf(a)
    const byState = rank[queueState(a)] - rank[queueState(b)]
    if (byState) return byState
    return queueState(a) === 'completed' ? hoursOf(a) - hoursOf(b) : hoursOf(b) - hoursOf(a)
  })
}

export function filterQueue(queue, { filter = 'active', query = '', sort = 'attention' } = {}) {
  const q = String(query || '').trim().toUpperCase()
  const list = (queue || []).filter((item) => {
    if (!matchesFilter(item, filter)) return false
    if (!q) return true
    return String(item.document_id || item.id || '').toUpperCase().includes(q) || String(item.title || '').toUpperCase().includes(q)
  })
  return sortQueue(list, sort)
}

/** Whole hours below two days, days and leftover hours from then on, so "96h" reads as "4d". */
export function spanLabel(hours) {
  const value = Math.floor(Number(hours))
  if (!Number.isFinite(value) || value < 1) return ''
  if (value < 48) return `${value}h`
  const days = Math.floor(value / 24)
  const rest = value % 24
  return rest ? `${days}d ${rest}h` : `${days}d`
}

/** Completed folders say when they finished; the others say how long they have been waiting. */
export function waitLabel(item) {
  const span = spanLabel(item?.hours_pending)
  if (queueState(item) === 'completed') return span ? `Completed ${span} ago` : 'Completed just now'
  return span ? `${span} waiting` : 'Just recorded'
}
