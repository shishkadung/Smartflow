export function elapsedLabel(hours) {
  const minutes = Math.max(0, Math.round(Number(hours || 0) * 60))
  if (minutes < 60) return `${minutes} min`
  const days = Math.floor(minutes / 1440)
  const remainder = Math.floor((minutes % 1440) / 60)
  return days ? `${days}d ${remainder}h` : `${Math.floor(minutes / 60)}h ${minutes % 60}m`
}

export function documentQueue(documents, { tray, overdueOnly = false, officeId = '', search = '', sort = 'urgency' }) {
  const query = search.toLowerCase().trim()
  return documents.filter(d => (overdueOnly ? d.is_overdue && d.tray !== 'completed' : d.tray === tray)
    && (!officeId || Number(d.current_office_id) === Number(officeId))
    && `${d.id} ${d.title} ${d.reference_no || ''}`.toLowerCase().includes(query)).sort((a, b) => {
    if (sort === 'recent') return String(b.last_scanned_at).localeCompare(String(a.last_scanned_at)) || a.id.localeCompare(b.id)
    if (sort === 'waiting') return Number(b.hours_waiting || 0) - Number(a.hours_waiting || 0) || a.id.localeCompare(b.id)
    return Number(Boolean(b.is_overdue)) - Number(Boolean(a.is_overdue))
      || String(a.due_at || '9999').localeCompare(String(b.due_at || '9999'))
      || Number(b.hours_waiting || 0) - Number(a.hours_waiting || 0) || a.id.localeCompare(b.id)
  })
}
