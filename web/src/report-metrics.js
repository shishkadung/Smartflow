// Wording helpers for the report figures that measure time at an office.

export function formatHours(hours) {
  const value = Number(hours)
  return value >= 48 ? `${value} h (${(value / 24).toFixed(1)} days)` : `${value} h`
}

export function monthLabel(month, style = 'long') {
  const [year, number] = String(month || '').split('-').map(Number)
  if (!year || !number) return String(month || '')
  return new Date(year, number - 1, 1).toLocaleString('en-US', style === 'short' ? { month: 'short' } : { month: 'long', year: 'numeric' })
}

/** One sentence for the earlier-versus-later comparison, or an honest note when there is too little to compare. */
export function trendLabel(trend) {
  if (!trend || trend.direction === 'insufficient') return 'Not enough forwarded folders to show a trend'
  const change = Math.abs(Number(trend.change_hours))
  const span = `${trend.earlier_avg_hours} h → ${trend.later_avg_hours} h`
  if (trend.direction === 'slower') return `Slower by ${change} h (${span})`
  if (trend.direction === 'faster') return `Faster by ${change} h (${span})`
  return `Steady (${span})`
}

/** Slowest office first; offices without a forwarded folder go last. */
export function sortPerformanceOffices(offices) {
  return [...(offices || [])].sort((a, b) => {
    const left = a.totals?.avg_hours
    const right = b.totals?.avg_hours
    if (left == null && right != null) return 1
    if (left != null && right == null) return -1
    if (left !== right) return Number(right) - Number(left)
    return String(a.office_code).localeCompare(String(b.office_code))
  })
}
