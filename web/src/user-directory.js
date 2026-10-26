// Account directory filtering for the Users & access page.
export const emptyAccountFilters = { query: '', office: '', role: '', status: '' }

const text = (value) => String(value ?? '').toLowerCase()

/** Every word typed must appear in the name, username, email or office code. */
export function filterAccounts(users, filters = emptyAccountFilters) {
  const words = text(filters.query).split(/\s+/).filter(Boolean)
  return (users || []).filter((row) => {
    if (filters.office && row.office_code !== filters.office) return false
    if (filters.role && row.role !== filters.role) return false
    if (filters.status === 'active' && !row.is_active) return false
    if (filters.status === 'inactive' && row.is_active) return false
    if (!words.length) return true
    const haystack = [row.name, row.username, row.email, row.office_code].map(text).join(' ')
    return words.every((word) => haystack.includes(word))
  })
}

export function officeCodes(users) {
  return [...new Set((users || []).map((row) => row.office_code).filter(Boolean))].sort((a, b) => String(a).localeCompare(String(b)))
}

export function filtersActive(filters) {
  return Boolean(String(filters?.query || '').trim() || filters?.office || filters?.role || filters?.status)
}
