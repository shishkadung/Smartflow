import { reportPeriodBounds } from './tracking.js'

const classifications = ['all', 'on_time', 'unforwarded', 'delayed']
const positive = (value, fallback = 1) => /^\d+$/.test(String(value || '')) && Number.isSafeInteger(Number(value)) && Number(value) > 0 ? Number(value) : fallback

export function reportViewFromSearch(value, now = new Date()) {
  const params = value instanceof URLSearchParams ? value : new URLSearchParams(value)
  const bounds = reportPeriodBounds(now)
  return {
    period: ['month', 'quarter', 'year'].includes(params.get('period')) ? params.get('period') : 'month',
    month: params.get('month') || bounds.maxMonth,
    year: params.get('year') || String(now.getFullYear()),
    quarter: params.get('quarter') || `${now.getFullYear()}-Q${Math.ceil((now.getMonth() + 1) / 3)}`,
    scope: params.get('scope') === 'outstanding' ? 'outstanding' : 'activity',
    classification: params.get('scope') !== 'outstanding' && classifications.includes(params.get('classification')) ? params.get('classification') : 'all',
    office_id: params.has('office_id') ? String(positive(params.get('office_id'), '')) : '',
    q: (params.get('q') || '').trim().slice(0, 200),
    page: positive(params.get('page')),
  }
}

export function reportViewParams(view) {
  const params = new URLSearchParams()
  for (const key of ['period', 'month', 'year', 'quarter', 'scope', 'classification', 'office_id', 'q', 'page']) {
    if (view[key] !== '' && view[key] != null) params.set(key, String(view[key]))
  }
  return params
}

export function reportPeriodQuery(view) {
  if (view.period === 'year') return { period: 'year', year: view.year }
  if (view.period === 'quarter') {
    const [year, quarter] = view.quarter.split('-Q')
    return { period: 'quarter', year, quarter }
  }
  return { period: 'month', month: view.month }
}

// Only this fixed local report destination is allowed as a tracking return link.
export function custodyReportReturnPath(value) {
  if (typeof value !== 'string' || value.length > 3000 || /[\\\r\n]/.test(value)) return null
  const path = value.split('?')[0]
  if (path !== '/admin/reports' && path !== '/reports') return null
  return `/admin/reports?${reportViewParams(reportViewFromSearch(value.split('?')[1] || ''))}`
}
