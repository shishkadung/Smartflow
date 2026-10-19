// Committed request views live in the URL so linked-folder visits can return to them.
export function requestViewFromSearch(value) {
  const params = value instanceof URLSearchParams ? value : new URLSearchParams(value)
  const positiveInteger = (raw, fallback) => /^\d+$/.test(raw || '') && Number.isSafeInteger(Number(raw)) && Number(raw) > 0 ? Number(raw) : fallback
  return {
    tab: params.get('tab') === 'outbox' ? 'outbox' : 'inbox',
    filter: ['active', 'past', 'all', 'pending', 'overdue'].includes(params.get('filter')) ? params.get('filter') : 'active',
    q: (params.get('q') || '').trim().slice(0, 200),
    page: positiveInteger(params.get('page'), 1),
    id: String(positiveInteger(params.get('id'), '') || ''),
  }
}

export function requestViewParams(view) {
  const normalized = requestViewFromSearch(new URLSearchParams(view))
  const params = new URLSearchParams()
  if (normalized.tab !== 'inbox') params.set('tab', normalized.tab)
  if (normalized.filter !== 'active') params.set('filter', normalized.filter)
  if (normalized.q) params.set('q', normalized.q)
  if (normalized.page !== 1) params.set('page', normalized.page)
  if (normalized.id) params.set('id', normalized.id)
  return params
}

export function requestReturnPath(view, id = view.id) {
  const query = requestViewParams({ ...view, id }).toString()
  return `/requests${query ? `?${query}` : ''}`
}

// A confirmed creation opens its exact ticket, independently of the old list filters.
export function createdRequestNavigation(result, view) {
  const id = result?.request?.id
  const selected = requestViewFromSearch(new URLSearchParams({ id: String(id ?? '') })).id
  if (!selected) throw new Error('Request saved, but its ID was not returned. Open My requests and refresh before creating another ticket.')
  return {
    params: requestViewParams({ tab: 'outbox', filter: 'active', page: 1, q: '', id: selected }),
    state: { requestCreationReturnTo: requestReturnPath(view) },
  }
}
