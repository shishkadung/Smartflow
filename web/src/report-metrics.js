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

/** Short number printed on a bar: one decimal below 10 h, whole hours from 10 h up. */
export function barValueLabel(hours) {
  if (hours == null || Number.isNaN(Number(hours))) return ''
  const value = Number(hours)
  return String(value < 10 ? Math.round(value * 10) / 10 : Math.round(value))
}

/** Share of the plot height a month's average fills; a forwarded month keeps a visible minimum, a month without one is empty. */
export function barFraction(hours, scale) {
  if (hours == null || Number.isNaN(Number(hours)) || !(Number(scale) > 0)) return 0
  return Math.min(1, Math.max(0.06, Number(hours) / Number(scale)))
}

/** Offices with a recurring bottleneck first, then slowest first; offices without a forwarded folder go last. */
export function sortPerformanceOffices(offices) {
  return [...(offices || [])].sort((a, b) => {
    const flagged = Number(Boolean(b.bottleneck?.recurring)) - Number(Boolean(a.bottleneck?.recurring))
    if (flagged) return flagged
    const left = a.totals?.avg_hours
    const right = b.totals?.avg_hours
    if (left == null && right != null) return 1
    if (left != null && right == null) return -1
    if (left !== right) return Number(right) - Number(left)
    return String(a.office_code).localeCompare(String(b.office_code))
  })
}
