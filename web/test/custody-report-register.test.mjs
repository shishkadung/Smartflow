import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer, transformWithOxc } from 'vite'
import { formatWhen, reportPeriodBounds } from '../src/tracking.js'
import { reportPeriodQuery, reportViewFromSearch, reportViewParams, custodyReportReturnPath } from '../src/report-navigation.js'

// Run real effects with deferred synthetic reads, never the operational API.
async function component(file, smartflow, initialView, apiText = async () => '', user = { id: 1, role: 'admin', office_id: 4, office_code: 'ACC' }) {
  const source = await readFile(new URL(`../src/${file}`, import.meta.url), 'utf8')
  const slots = [], pending = []
  let cursor = 0, query = initialView, changes = []
  const same = (a, b) => a && b && a.length === b.length && a.every((value, index) => Object.is(value, b[index]))
  const useState = initial => {
    const index = cursor++
    if (!(index in slots)) {
      slots[index] = { value: typeof initial === 'function' ? initial() : initial }
      slots[index].set = value => { slots[index].value = typeof value === 'function' ? value(slots[index].value) : value }
    }
    return [slots[index].value, slots[index].set]
  }
  const memo = (create, deps) => {
    const index = cursor++
    if (!slots[index] || !same(slots[index].deps, deps)) slots[index] = { deps, value: create() }
    return slots[index].value
  }
  const context = {
    Date, Number, String, Boolean, Object, Math, JSON, URLSearchParams, URL, Blob, setTimeout,
    h: (type, props, ...children) => ({ type, props: { ...props, children } }), Fragment: 'Fragment',
    useState, useMemo: memo, useCallback: (fn, deps) => memo(() => fn, deps),
    useRef: initial => memo(() => ({ current: initial }), []),
    useEffect: (effect, deps) => {
      const index = cursor++
      if (!slots[index] || !same(slots[index].deps, deps)) {
        slots[index]?.cleanup?.()
        slots[index] = { deps }
        pending.push(() => { slots[index].cleanup = effect() })
      }
    },
    useAuth: () => ({ user, smartflow, apiText }),
    useSearchParams: () => [reportViewParams(query), params => { query = reportViewFromSearch(params) }],
    ApiError: Error, reportPeriodBounds, formatWhen, reportPeriodQuery, reportViewFromSearch, reportViewParams,
    statTone: () => 'stat', window: { open() { return null } }, document: { getElementById() { return null } },
  }
  for (const match of source.matchAll(/^import \{([^}]+)\} from /gm)) for (const name of match[1].split(',').map(value => value.trim())) if (!(name in context)) context[name] = name
  for (const match of source.matchAll(/^import (\w+) from /gm)) if (!(match[1] in context)) context[match[1]] = match[1]
  const name = /export default function (\w+)/.exec(source)[1]
  const local = source.replace(/^import .*\r?\n/gm, '').replace(/export default function /, 'function ').replace(/export function /g, 'function ')
  const result = await transformWithOxc(`${local}\nglobalThis.Page=${name}`, file, { jsx: { runtime: 'classic', pragma: 'h', pragmaFrag: 'Fragment' } })
  vm.createContext(context)
  vm.runInContext(result.code, context)
  return {
    render(props = {}) { cursor = 0; return context.Page({ view: query, onChange: value => { changes.push(value); query = { ...query, ...value } }, ...props }) },
    async effects() { while (pending.length) pending.shift()(); for (let i = 0; i < 15; i++) await Promise.resolve() },
    change(value) { query = { ...query, ...value } },
    get changes() { return changes },
    get query() { return query },
    dispose() { slots.forEach(slot => slot?.cleanup?.()) },
  }
}
function walk(node, predicate) {
  if (!node || typeof node !== 'object') return null
  if (predicate(node)) return node
  for (const child of [node.props?.children, node.props?.action, node.props?.actions].flat(Infinity)) { const found = walk(child, predicate); if (found) return found }
  return null
}
function text(node) {
  if (node == null || typeof node === 'boolean') return ''
  if (typeof node !== 'object') return String(node)
  if (Array.isArray(node)) return node.map(text).join(' ')
  return [node.props?.children, node.props?.action, node.props?.actions].map(text).join(' ')
}
const button = (node, label) => walk(node, item => item.type === 'button' && text(item).trim() === label)
const named = name => node => (typeof node.type === 'function' ? node.type.name : node.type) === name
const defer = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no }); return { promise, resolve, reject } }
const base = reportViewFromSearch('month=2026-10')
const response = (rows = [], total = rows.length, page = 1) => ({ documents: rows, total, page, page_size: 25, total_pages: Math.max(1, Math.ceil(total / 25)), as_of: '2026-10-23 12:00:00', timezone: 'Asia/Manila' })

test('report navigation preserves committed filters and excludes hidden outstanding classification and external return paths', () => {
  const view = reportViewFromSearch('period=quarter&quarter=2026-Q3&scope=activity&classification=delayed&office_id=4&q=Signed+schedule&page=3')
  assert.deepEqual(reportPeriodQuery(view), { period: 'quarter', year: '2026', quarter: '3' })
  assert.deepEqual(reportViewFromSearch(reportViewParams(view)), view)
  const returnTo = custodyReportReturnPath(`/admin/reports?${reportViewParams(view)}&unexpected=ignored`)
  assert.match(returnTo, /classification=delayed/)
  assert.doesNotMatch(returnTo, /unexpected/)
  assert.equal(reportViewFromSearch('scope=outstanding&classification=delayed').classification, 'all')
  for (const path of ['https://external.invalid/admin/reports', '//external.invalid/admin/reports', '/admin/reports/../../users', '/documents', '/admin/reports\\evil']) assert.equal(custodyReportReturnPath(path), null)
})

test('register pins the summary cutoff and ignores a late response for an abandoned search', async t => {
  const old = defer(), calls = []
  const instance = await component('components/ReportRegister.jsx', { reportsRegister: query => { calls.push(query); return calls.length === 1 ? old.promise : Promise.resolve(response([{ document_id: 'NEW' }])) } }, base)
  t.after(() => instance.dispose())
  instance.render({ asOf: '2026-10-23 12:00:00' }); await instance.effects()
  instance.change({ q: 'new', page: 1 })
  instance.render({ asOf: '2026-10-23 12:00:00' }); await instance.effects()
  let tree = instance.render({ asOf: '2026-10-23 12:00:00' })
  assert.equal(walk(tree, named('ReportRegisterRows')).props.rows[0].document_id, 'NEW')
  old.resolve(response([{ document_id: 'OLD' }]))
  await instance.effects(); tree = instance.render({ asOf: '2026-10-23 12:00:00' })
  assert.equal(walk(tree, named('ReportRegisterRows')).props.rows[0].document_id, 'NEW')
  assert.equal(calls[0].as_of, '2026-10-23 12:00:00')
  assert.equal(calls[1].q, 'new')
  instance.render({ asOf: '2026-10-23 12:00:00', movementWatermark: 44, correctionWatermark: 0 }); await instance.effects()
  assert.equal(calls[2].movement_watermark, 44)
  assert.equal(calls[2].correction_watermark, 0)
})

test('changed-query failures never reuse old records; same-query stale empty reads cannot claim an all-clear', async t => {
  let calls = 0
  const instance = await component('components/ReportRegister.jsx', { reportsRegister: () => ++calls === 1 ? Promise.resolve(response()) : Promise.reject(new Error('offline')) }, base)
  t.after(() => instance.dispose())
  instance.render(); await instance.effects()
  assert.match(text(instance.render()), /No recorded folder activity/)
  instance.render({ revision: 1 }); await instance.effects()
  let tree = instance.render({ revision: 1 })
  assert.match(text(tree), /Previously loaded register may be stale/)
  assert.match(text(tree), /Current folder status could not be verified/)
  assert.doesNotMatch(text(tree), /No recorded folder activity|No outstanding transfers/)
  instance.change({ scope: 'outstanding' })
  instance.render({ revision: 1 }); await instance.effects(); tree = instance.render({ revision: 1 })
  assert.match(text(tree), /Folder register unavailable/)
  assert.doesNotMatch(text(tree), /No outstanding transfers|Page 1/)
  assert.equal(walk(tree, node => node.type === 'ReportRegisterRows'), null)
})

test('server pages remain server queries and an unavailable page offers recovery without claiming zero matches', async t => {
  const calls = []
  const instance = await component('components/ReportRegister.jsx', { reportsRegister: async query => { calls.push(query); return response([], 30, query.page) } }, { ...base, page: 3, office_id: '4', q: 'schedules' })
  t.after(() => instance.dispose())
  instance.render(); await instance.effects()
  const tree = instance.render()
  assert.match(text(tree), /This page is no longer available/)
  assert.doesNotMatch(text(tree), /No folders match/)
  button(tree, 'Go to first page').props.onClick()
  instance.render(); await instance.effects()
  assert.equal(calls[1].page, 1)
  assert.equal(calls[1].office_id, '4')
  assert.equal(calls[1].q, 'schedules')
})

test('export errors preserve the verified report, while summary metrics expose counts and their register classification', async t => {
  const summary = { period: 'month', month: '2026-10', office_id: 4, export_allowed: true, period_start: '2026-10-01 00:00:00', period_end: '2026-10-23 12:00:00', as_of: '2026-10-23 12:00:00', movement_watermark: 44, correction_watermark: 0, totals: { documents_in_period: 4 }, compliance: { on_time: { count: 2, percent: 50 }, unforwarded: { count: 1, percent: 25 }, delayed: { count: 1, percent: 25 } }, office_totals: [{ office_id: 4, docs_processed: 4 }] }
  let exportQuery
  const instance = await component('pages/AdminReportsPage.jsx', { reportsSummary: async () => summary, auditExceptions: async () => ({ exceptions: [] }) }, base, async (_endpoint, query) => { exportQuery = query; throw new Error('download failed') })
  t.after(() => instance.dispose())
  instance.render(); await instance.effects()
  let tree = instance.render()
  const selected = walk(tree, node => node.type === 'button' && text(node).includes('Late receipt'))
  assert.match(text(selected), /1.*25%/)
  await button(tree, 'Download CSV').props.onClick()
  tree = instance.render()
  assert.match(text(tree), /Export could not be prepared.*download failed/)
  assert.doesNotMatch(text(tree), /Custody report unavailable/)
  assert.equal(walk(tree, named('ReportOfficeTotals')).props.data.totals.documents_in_period, 4)
  assert.equal(exportQuery.as_of, summary.as_of)
  assert.equal(exportQuery.movement_watermark, 44)
  assert.equal(exportQuery.correction_watermark, 0)
  selected.props.onClick()
  assert.equal(instance.query.classification, 'delayed')
  assert.equal(instance.query.scope, 'activity')
  assert.equal(instance.query.section, 'register', 'a summary tile opens the register part')
})

const pageSummary = { period: 'month', month: '2026-10', office_id: 4, export_allowed: true, period_start: '2026-10-01 00:00:00', period_end: '2026-10-23 12:00:00', as_of: '2026-10-23 12:00:00', movement_watermark: 44, correction_watermark: 0, totals: { documents_in_period: 4 }, compliance: { on_time: { count: 2, percent: 50 }, unforwarded: { count: 1, percent: 25 }, delayed: { count: 1, percent: 25 } }, office_totals: [{ office_id: 4, docs_processed: 4 }] }
const exceptionRows = [{ document_id: 'DOC-2026-000001', exception_type: 'unforwarded' }, { document_id: 'DOC-2026-000002', exception_type: 'skipped_office' }]
function parts(tree) {
  const found = []
  const visit = node => {
    if (!node || typeof node !== 'object') return
    if (node.props?.role === 'tabpanel') found.push(node)
    for (const child of [node.props?.children].flat(Infinity)) visit(child)
  }
  visit(tree)
  return found
}
const shown = tree => parts(tree).filter(node => !node.props.hidden).map(node => node.props['aria-label'])
const partTabs = tree => walk(tree, node => node.type === 'Segmented' && node.props.options?.some(option => option.value === 'register'))

test('Custody reports shows one part at a time, keeps the others loaded and counts the exceptions on their tab', async t => {
  const instance = await component('pages/AdminReportsPage.jsx', { reportsSummary: async () => pageSummary, auditExceptions: async () => ({ exceptions: exceptionRows }) }, base)
  t.after(() => instance.dispose())
  instance.render(); await instance.effects(); await instance.effects()
  let tree = instance.render()
  assert.deepEqual(Array.from(partTabs(tree).props.options, option => [option.value, option.label, option.badge ?? null]),
    [['overview', 'Overview', null], ['departments', 'Departments', null], ['register', 'Register', null], ['exceptions', 'Exceptions', 2]])
  assert.deepEqual(shown(tree), ['Overview'], 'the page opens on the overview')
  assert.deepEqual(parts(tree).map(node => node.props['aria-label']), ['Overview', 'Departments', 'Register', 'Exceptions'], 'hidden parts stay mounted')
  assert.ok(walk(parts(tree)[0], named('ReportFlowMetrics')) && walk(parts(tree)[0], named('ReportOfficeTotals')), 'overview holds the completion figures and the office totals')
  assert.ok(walk(parts(tree)[1], named('DepartmentPerformance')))
  assert.ok(walk(parts(tree)[2], named('ReportRegister')))
  assert.ok(walk(parts(tree)[3], named('ExceptionCard')))
  instance.change({ page: 3, office_id: '4', q: 'schedules' })
  partTabs(instance.render()).props.onChange('register')
  assert.equal(instance.query.section, 'register')
  assert.equal(instance.query.page, 3, 'changing the part keeps the register page')
  assert.equal(instance.query.q, 'schedules')
  assert.equal(instance.query.office_id, '4')
  assert.deepEqual(shown(instance.render()), ['Register'])
  instance.change({ section: 'departments' })
  assert.deepEqual(shown(instance.render()), ['Departments'])
  instance.change({ section: 'exceptions' })
  assert.deepEqual(shown(instance.render()), ['Exceptions'])
})

test('without Accounting authority there is no exceptions part, and a stale link to it falls back to the overview', async t => {
  const instance = await component('pages/AdminReportsPage.jsx', { reportsSummary: async () => pageSummary }, { ...base, section: 'exceptions' }, async () => '', { id: 2, role: 'admin', office_id: 3, office_code: 'BUD' })
  t.after(() => instance.dispose())
  instance.render(); await instance.effects(); await instance.effects()
  const tree = instance.render()
  assert.deepEqual(Array.from(partTabs(tree).props.options, option => option.value), ['overview', 'departments', 'register'])
  assert.deepEqual(parts(tree).map(node => node.props['aria-label']), ['Overview', 'Departments', 'Register'])
  assert.deepEqual(shown(tree), ['Overview'])
})

test('the report part is part of the address only when it is not the overview', () => {
  assert.equal(reportViewFromSearch('month=2026-10').section, 'overview')
  assert.equal(reportViewFromSearch('section=register').section, 'register')
  assert.equal(reportViewFromSearch('section=departments').section, 'departments')
  assert.equal(reportViewFromSearch('section=bogus').section, 'overview')
  assert.doesNotMatch(String(reportViewParams(base)), /section/)
  assert.match(String(reportViewParams({ ...base, section: 'departments' })), /section=departments/)
  assert.match(custodyReportReturnPath('/admin/reports?month=2026-10&section=register&page=2'), /section=register/)
  assert.doesNotMatch(custodyReportReturnPath('/admin/reports?month=2026-10&section=overview'), /section/)
  const view = reportViewFromSearch('period=quarter&quarter=2026-Q3&section=exceptions')
  assert.deepEqual(reportViewFromSearch(reportViewParams(view)), view)
})

test('the register lists 10 folders a page and a folder opened from it returns to the register, not the overview', async t => {
  const calls = []
  const instance = await component('components/ReportRegister.jsx', { reportsRegister: async query => { calls.push(query); return response([{ document_id: 'DOC-2026-000001', title: 'Signed schedules' }], 23, 2) } }, { ...base, page: 2, section: 'overview' })
  t.after(() => instance.dispose())
  instance.render(); await instance.effects()
  const tree = instance.render()
  assert.equal(calls[0].page_size, 10)
  assert.equal(calls[0].page, 2)
  const returnTo = walk(tree, named('ReportRegisterRows')).props.returnTo
  assert.match(returnTo, /section=register/)
  assert.match(returnTo, /page=2/)
})

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { ReportRegisterRows } = await server.ssrLoadModule('/src/components/ReportRegister.jsx')
test('register exposes named as-of custody evidence and exact tracking/history links without custody writes', () => {
  const row = { document_id: 'DOC-2026-000001', title: 'Signed schedules', type: 'Others: Supporting papers', classification: 'unforwarded', current_status: 'OUT', current_office_name: 'Budget Office', destination_office_name: 'Accounting Office', last_scanned_at: '2026-10-02 09:00:00', recorded_by: 'Sending clerk', last_sent_at: '2026-10-02 09:00:00', sent_by: 'Sending clerk', last_received_at: '2026-10-01 08:00:00', received_by: 'Receiving clerk', receipt_wait_hours: 120, movement_count: 2, carried_forward: true }
  const returnTo = `/admin/reports?${reportViewParams(base)}`
  const html = renderToStaticMarkup(React.createElement(MemoryRouter, null, React.createElement(ReportRegisterRows, { rows: [row], returnTo })))
  for (const value of ['Signed schedules', 'Receipt not recorded', 'Budget Office', 'Accounting Office', 'Sending clerk', 'Receiving clerk', 'Sent before this period', '120 calendar hours', 'Last received:', 'Last sent:']) assert.ok(html.includes(value), value)
  assert.match(html, /aria-label="Track folder DOC-2026-000001"/)
  assert.match(html, /href="\/documents\?id=DOC-2026-000001&amp;report_return=/)
  assert.match(html, /href="\/history\?id=DOC-2026-000001&amp;report_return=/)
  assert.doesNotMatch(html, /<button|Record IN|Record OUT/)
})
