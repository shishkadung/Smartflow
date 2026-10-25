import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'
import { barFraction, barValueLabel, formatHours, monthLabel, sortPerformanceOffices, trendLabel } from '../src/report-metrics.js'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { DepartmentPerformanceContent } = await server.ssrLoadModule('/src/components/DepartmentPerformance.jsx')
const render = (props) => renderToStaticMarkup(React.createElement(DepartmentPerformanceContent, { months: 6, onMonths() {}, onRetry() {}, loading: false, error: '', ...props }))
function findElement(node, predicate) {
  if (!React.isValidElement(node)) return undefined
  if (predicate(node)) return node
  return React.Children.toArray(node.props.children).map(child => findElement(child, predicate)).find(Boolean)
}

const months = ['2026-05', '2026-06', '2026-07']
const cell = (month, visits, forwarded, avg, late, slow = false) => ({ month, visits, forwarded, open: visits - forwarded, completed: 0, avg_hours: avg, late, late_percent: visits ? Math.round(late * 1000 / visits) / 10 : null, slow })
const totals = (visits, avg, late) => ({ visits, forwarded: visits, open: 0, completed: 0, avg_hours: avg, late, late_percent: visits ? Math.round(late * 1000 / visits) / 10 : null })
const office = (id, code, name, avg, trend, bottleneck, cells) => ({ office_id: id, office_code: code, office_name: name, months: cells, totals: totals(cells.reduce((n, c) => n + c.visits, 0), avg, cells.reduce((n, c) => n + c.late, 0)), trend, bottleneck, types: [{ type: 'Disbursement Voucher', visits: 9, forwarded: 9, open: 0, completed: 0, avg_hours: avg, late: 5, late_percent: 55.6 }] })
const data = {
  success: true,
  window: { months: 6, start_month: '2026-05', end_month: '2026-10', list: months, cutoff: '2026-10-26 10:00:00' },
  rules: { min_visits_per_month: 3, slow_month_late_percent: 25, recurring_slow_months: 3 },
  basis: 'A visit is one IN at an office. A month is slow when it has at least 3 visits and at least 25% of them were late.',
  municipal: { months: [], totals: totals(27, 15.3, 8), trend: { direction: 'steady', earlier_avg_hours: 15, later_avg_hours: 15.6, change_hours: 0.6 } },
  bottlenecks: [{ office_id: 5, office_code: 'TRE', office_name: 'Treasury Office', slow_months: 4, active_months: 6, late_percent: 42.3 }],
  offices: [
    office(1, 'ENG', 'Engineering Office', 12.5, { direction: 'steady', earlier_avg_hours: 12, later_avg_hours: 12.9, change_hours: 0.9 }, { recurring: false, slow_months: 0, active_months: 3, slow_month_list: [] }, [cell('2026-05', 3, 3, 12, 0), cell('2026-06', 3, 3, 13, 0), cell('2026-07', 3, 3, 12.5, 0)]),
    office(5, 'TRE', 'Treasury Office', 61.4, { direction: 'slower', earlier_avg_hours: 40, later_avg_hours: 72.5, change_hours: 32.5 }, { recurring: true, slow_months: 4, active_months: 6, slow_month_list: ['2026-05', '2026-06', '2026-07'] }, [cell('2026-05', 4, 4, 55, 3, true), cell('2026-06', 5, 5, 62, 3, true), cell('2026-07', 4, 4, 70, 2, true)]),
    office(2, 'HR', 'Human Resources', null, { direction: 'insufficient', earlier_avg_hours: null, later_avg_hours: null, change_hours: null }, { recurring: false, slow_months: 0, active_months: 0, slow_month_list: [] }, [cell('2026-05', 0, 0, null, 0), cell('2026-06', 0, 0, null, 0), cell('2026-07', 0, 0, null, 0)]),
  ],
}

test('helpers word the trend, month and hours honestly', () => {
  assert.equal(trendLabel({ direction: 'slower', earlier_avg_hours: 10, later_avg_hours: 30, change_hours: 20 }), 'Slower by 20 h (10 h → 30 h)')
  assert.equal(trendLabel({ direction: 'faster', earlier_avg_hours: 40, later_avg_hours: 12.8, change_hours: -27.2 }), 'Faster by 27.2 h (40 h → 12.8 h)')
  assert.equal(trendLabel({ direction: 'steady', earlier_avg_hours: 100, later_avg_hours: 105, change_hours: 5 }), 'Steady (100 h → 105 h)')
  assert.equal(trendLabel({ direction: 'insufficient', change_hours: null }), 'Not enough forwarded folders to show a trend')
  assert.equal(trendLabel(null), 'Not enough forwarded folders to show a trend')
  assert.equal(monthLabel('2026-05'), 'May 2026')
  assert.equal(monthLabel('2026-05', 'short'), 'May')
  assert.equal(formatHours(60), '60 h (2.5 days)')
})

test('offices are listed slowest first and offices without a forwarded folder last', () => {
  const sorted = sortPerformanceOffices([{ office_code: 'HR', totals: { avg_hours: null } }, { office_code: 'ENG', totals: { avg_hours: 12.5 } }, { office_code: 'TRE', totals: { avg_hours: 61.4 } }, { office_code: 'ACC', totals: { avg_hours: 12.5 } }])
  assert.deepEqual(sorted.map(item => item.office_code), ['TRE', 'ACC', 'ENG', 'HR'])
  assert.deepEqual(sortPerformanceOffices(null), [])
})

test('an office with a recurring bottleneck is listed first, then slowest first', () => {
  const sorted = sortPerformanceOffices([
    { office_code: 'BUD', totals: { avg_hours: 28.7 }, bottleneck: { recurring: false } },
    { office_code: 'ACC', totals: { avg_hours: 21.1 }, bottleneck: { recurring: true } },
    { office_code: 'TRE', totals: { avg_hours: 39.1 }, bottleneck: { recurring: true } },
    { office_code: 'HR', totals: { avg_hours: null }, bottleneck: { recurring: false } },
    { office_code: 'MAY', totals: { avg_hours: null } },
  ])
  assert.deepEqual(sorted.map(item => item.office_code), ['TRE', 'ACC', 'BUD', 'HR', 'MAY'])
})

test('bar numbers and heights are honest about small, empty and very tall months', () => {
  assert.equal(barValueLabel(5.94), '5.9')
  assert.equal(barValueLabel(6), '6')
  assert.equal(barValueLabel(0), '0')
  assert.equal(barValueLabel(22.4), '22')
  assert.equal(barValueLabel(62.5), '63')
  assert.equal(barValueLabel(null), '')
  assert.equal(barValueLabel(undefined), '')
  assert.equal(barFraction(null, 48), 0)
  assert.equal(barFraction(24, 48), 0.5)
  assert.equal(barFraction(0.5, 48), 0.06)
  assert.equal(barFraction(96, 48), 1)
  assert.equal(barFraction(10, 0), 0)
})

test('every bar carries its number, and months without a forwarded folder stay empty', () => {
  const html = render({ data })
  const heroes = html.match(/<b class="is-slow" style="--v:[^"]+">(\d+)<\/b>/g) || []
  assert.deepEqual(heroes.map(item => item.replace(/<[^>]+>/g, '')), ['55', '62', '70'], 'slow months of the bottleneck show their hours')
  assert.match(html, /<b style="--v:[0-9.]+">12<\/b>/, 'a normal month shows its hours without the slow colour')
  assert.match(html, /<b style="--v:[0-9.]+">13<\/b>/)
  assert.equal((html.match(/<b[ >]/g) || []).length, 6, 'the office without forwarded folders prints no numbers')
  assert.match(html, /<small>May<\/small>/)
})

test('the bars describe themselves for assistive technology', () => {
  const html = render({ data })
  assert.match(html, /role="img" aria-label="Average hours per month\. May 2026: 55 h \(2\.3 days\), slow; June 2026: 62 h \(2\.6 days\), slow; July 2026: 70 h \(2\.9 days\), slow\."/)
  assert.match(html, /aria-label="Average hours per month\. May 2026: no forwarded folders; June 2026: no forwarded folders/)
})

test('the default desk limit is a dashed line, scales the bars with it and is explained once', () => {
  const html = render({ data: { ...data, rules: { ...data.rules, default_desk_limit_hours: 48 } } })
  assert.equal((html.match(/department-performance__limit/g) || []).length, 3, 'one line for each of the three offices')
  assert.match(html, /<span class="department-performance__limit"><em>48 h<\/em><\/span>/)
  assert.match(html, /class="department-performance__bars has-limit"[^>]*--limit:0\.685714/, 'the line sits at 48 of the 70 h scale')
  assert.match(html, /The dashed line is the 48 h default desk limit; some folder types have their own limit/)
  assert.match(html, /The dashed line is the 48 h default desk limit\./, 'the bars also say so for screen readers')
  assert.match(html, /<i class="is-slow" style="--v:1"><\/i>/, 'the tallest month fills the plot')
  assert.match(html, /<i style="--v:0\.1714/, '12 h of a 70 h scale')
  assert.doesNotMatch(html, /NaN|undefined|null/)
})

test('a response without the desk limit draws no line and no limit wording', () => {
  const html = render({ data })
  assert.doesNotMatch(html, /department-performance__limit|has-limit|dashed line|default desk limit/)
  assert.match(html, /at least 25% of its visits ran past their limit/)
})

test('each office keeps its figures and its bars as separate parts so the desktop can place them side by side', () => {
  const html = render({ data })
  const first = html.slice(html.indexOf('<li class="department-performance__row">'))
  const summary = first.indexOf('department-performance__summary')
  const bars = first.indexOf('department-performance__bars')
  const details = first.indexOf('<details>')
  assert.ok(summary > -1 && summary < bars && bars < details, 'figures, then bars, then the month table')
  assert.match(first, /<div class="department-performance__summary"><div class="department-performance__title"><strong>Treasury Office<\/strong>/)
})

test('the view shows the window, the recurring bottleneck, each office and a month by month table', () => {
  const html = render({ data })
  assert.match(html, /Department performance/)
  assert.match(html, /May 2026 to October 2026 · each month is measured at its own end · 27 office visits in total/)
  assert.match(html, /Recurring bottleneck<\/strong><ul><li><strong>Treasury Office \(TRE\)<\/strong>: slow in 4 of 6 months · 42\.3% of visits late/)
  assert.match(html, /Treasury Office<\/strong><span class="department-performance__code">TRE<\/span><span class="status-pill status-pill--warn">Recurring bottleneck/)
  assert.match(html, /61\.4 h \(2\.6 days\) on average before forwarding · 13 visits · 8 late \(61\.5%\)/)
  assert.match(html, /Slower by 32\.5 h \(40 h → 72\.5 h\)/)
  assert.match(html, /All offices/)
  assert.match(html, /Month by month/)
  assert.match(html, /<th scope="row">May 2026 · slow<\/th><td>4<\/td><td>4<\/td><td>55<\/td><td>3<\/td><td>75%<\/td>/)
  assert.match(html, /Folder types with the most late visits: Disbursement Voucher \(5 late of 9\)/)
  assert.match(html, /How these are counted/)
  assert.ok(html.indexOf('Treasury Office</strong>') < html.indexOf('Engineering Office</strong>') && html.indexOf('Engineering Office</strong>') < html.indexOf('Human Resources</strong>'), 'slowest office first')
  assert.match(html, /aria-selected="true" class="is-active">6 months/)
  assert.match(html, /No folder forwarded yet · 0 visits|No office visits in this window/)
  assert.doesNotMatch(html, /NaN|undefined|null/)
})

test('without a recurring bottleneck the view says so instead of an empty flag', () => {
  const html = render({ data: { ...data, bottlenecks: [] } })
  assert.match(html, /No office was slow in 3 or more months in this window/)
  assert.doesNotMatch(html, /department-performance__flag/)
})

test('a window without any visits is an empty state, not a healthy all-clear', () => {
  const idle = { ...data, municipal: { ...data.municipal, totals: totals(0, null, 0) }, bottlenecks: [], offices: [] }
  const html = render({ data: idle })
  assert.match(html, /No office visits were recorded in this window/)
  assert.doesNotMatch(html, /No office was slow|Recurring bottleneck|NaN/)
})

test('a failed first read is unavailable with a working retry and no invented figures', () => {
  let retries = 0
  const props = { data: null, error: 'Connection interrupted', onRetry() { retries++ } }
  const html = render(props)
  assert.match(html, /Department performance unavailable/)
  assert.match(html, /Connection interrupted/)
  assert.match(html, /could not be verified/)
  assert.doesNotMatch(html, /No office visits|No office was slow|0 office visits/)
  const retry = findElement(DepartmentPerformanceContent({ months: 6, onMonths() {}, loading: false, ...props }), node => node.type === 'button' && node.props.children === 'Retry department performance')
  assert.ok(retry, 'retry button is rendered')
  retry.props.onClick()
  assert.equal(retries, 1)
})

test('a failed refresh keeps the earlier view and labels it as possibly out of date', () => {
  const html = render({ data, error: 'Connection interrupted' })
  assert.match(html, /Department performance refresh failed/)
  assert.match(html, /Showing the previously loaded 6 month view; it may be out of date/)
  assert.match(html, /Treasury Office/)
})

test('while the first read is loading no figures or empty message are shown', () => {
  const html = render({ data: null, loading: true })
  assert.match(html, /Loading department performance/)
  assert.doesNotMatch(html, /No office visits|No office was slow|Recurring bottleneck/)
})

test('the window control offers 3, 6 and 12 months and reports the choice', () => {
  const picked = []
  const html = render({ data, months: 12, onMonths: value => picked.push(value) })
  for (const label of ['3 months', '6 months', '12 months']) assert.match(html, new RegExp(label))
  assert.match(html, /aria-selected="true" class="is-active">12 months/)
  const element = findElement(DepartmentPerformanceContent({ data, months: 6, onMonths: value => picked.push(value), onRetry() {}, loading: false, error: '' }), node => node.props?.options && node.props.onChange)
  element.props.onChange(3)
  assert.deepEqual(picked, [3])
})
