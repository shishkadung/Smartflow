import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'
import { transformWithOxc } from 'vite'
import { reportPeriodBounds } from '../src/tracking.js'
import { reportPeriodQuery, reportViewFromSearch, reportViewParams } from '../src/report-navigation.js'
import { beginScopedRead, failScopedRead, scopedReadView } from '../src/scoped-read.js'
import { custodyReportReturnPath } from '../src/report-navigation.js'
import { documentQueue } from '../src/document-queue.js'
import { documentRequestCategoriesForOffice, statusLabel } from '../src/tracking.js'
import { requestReturnPath, requestViewFromSearch, requestViewParams } from '../src/request-navigation.js'
import { requestReturnPath as validRequestPath } from '../src/custody-actions.js'

// Run actual page effects and callbacks with synthetic reads, without HTTP or
// storage. Shared components stay as element markers; page state is unchanged.
async function page(name, auth, query = '', folder = 'pages') {
  const source = await readFile(new URL(`../src/${folder}/${name}.jsx`, import.meta.url), 'utf8')
  const slots = [], pending = []
  let cursor = 0
  const sameDeps = (a, b) => a && b && a.length === b.length && a.every((value, i) => Object.is(value, b[i]))
  const useState = initial => {
    const at = cursor++
    if (!(at in slots)) slots[at] = typeof initial === 'function' ? initial() : initial
    return [slots[at], value => { slots[at] = typeof value === 'function' ? value(slots[at]) : value }]
  }
  const memoSlot = (create, deps) => {
    const at = cursor++
    if (!slots[at] || !sameDeps(slots[at].deps, deps)) slots[at] = { deps, value: create() }
    return slots[at].value
  }
  const useEffect = (effect, deps) => {
    const at = cursor++
    if (!slots[at] || !sameDeps(slots[at].deps, deps)) {
      slots[at]?.cleanup?.()
      slots[at] = { deps }
      pending.push(() => { slots[at].cleanup = effect() })
    }
  }
  const context = {
    Date, Number, String, Boolean, Object, Math, URLSearchParams,
    ApiError: class ApiError extends Error {},
    h: (type, props, ...children) => ({ type, props: { ...props, children } }), Fragment: 'Fragment',
    useState, useEffect, useMemo: memoSlot, useCallback: (fn, deps) => memoSlot(() => fn, deps),
    useRef: initial => memoSlot(() => ({ current: initial }), []),
    useId: () => memoSlot(() => 'synthetic-field', []),
    useAuth: () => auth, revision: 0, useLiveRefresh: () => context.revision,
    useNavigate: () => () => {}, useSearchParams: () => [new URLSearchParams(query), () => {}],
    window: { matchMedia: () => ({ matches: true }), setTimeout, clearTimeout },
    useFolderReceipt: () => ({ requestReceipt: async () => null, receiptDialog: null }),
    useFolderFiling: () => ({ requestFiling: async () => false, filingDialog: null }),
    parseTrackingId: value => /^DOC-\d{4}-\d{6}$/.test(value) ? value : null,
    isSignedQrPayload: () => false, preferredForwardDestination: doc => String(doc.suggested_forward?.office_id || ''),
    clerkScanActions: () => ({ canIn: false, canOut: false }), statTone: () => '',
    reportPeriodBounds, reportPeriodQuery, reportViewFromSearch, reportViewParams, beginScopedRead, failScopedRead, scopedReadView,
  }
  for (const line of source.matchAll(/^import \{([^}]+)\} from /gm)) {
    for (const entry of line[1].split(',').map(value => value.trim())) if (!(entry in context)) context[entry] = entry
  }
  for (const line of source.matchAll(/^import (\w+) from /gm)) if (!(line[1] in context)) context[line[1]] = line[1]
  const local = source.replace(/^import .*\r?\n/gm, '').replace(/export default function /, 'function ').replace(/export function /g, 'function ')
  const transformed = await transformWithOxc(`${local}\nglobalThis.Page=${name}`, `${name}.jsx`, { jsx: { runtime: 'classic', pragma: 'h', pragmaFrag: 'Fragment' } })
  vm.createContext(context)
  vm.runInContext(transformed.code, context)
  return {
    context,
    render(props) { cursor = 0; return context.Page(props) },
    async effects() { while (pending.length) pending.shift()(); for (let i = 0; i < 12; i++) await Promise.resolve() },
    dispose() { for (const slot of slots) slot?.cleanup?.() },
  }
}
function walk(node, predicate) {
  if (!node || typeof node !== 'object') return null
  if (predicate(node)) return node
  for (const child of [node.props?.children, node.props?.actions, node.props?.footer].flat(Infinity)) {
    const found = walk(child, predicate)
    if (found) return found
  }
  return null
}
function text(node) {
  if (node == null || typeof node === 'boolean') return ''
  if (typeof node !== 'object') return String(node)
  if (Array.isArray(node)) return node.map(text).join(' ')
  return [node.props?.children, node.props?.actions, node.props?.footer].map(text).join(' ')
}
const button = (tree, label) => walk(tree, node => node.type === 'button' && text(node).trim() === label)
const staff = { id: 5, office_id: 3, office_code: 'ACC', role: 'staff' }
const emptyDesk = { stats: { in_flow: 0, out_flow: 0, active_tags: 0 }, active_documents: [], in_transit: [] }
const health = { status: { api: 'Online', documents: 0 }, users: { active: 1 }, operations: { movements_today: 0 } }
function deferred() { let resolve; const promise = new Promise(done => { resolve = done }); return { promise, resolve } }

test('non-Accounting QR administrators read scans/activity without requesting restricted exceptions', async t => {
  for (const officeCode of ['BUD', 'ENG', 'TRE']) {
    const view = await page('AdminQrMonitorPage', { user: { ...staff, role: 'admin', office_code: officeCode }, smartflow: {
      auditScans: async () => ({ events: [{ document_id: 'DOC-2026-000007', outcome: 'success' }] }),
      auditActivity: async () => ({ events: [{ id: 2, action: 'threshold.update' }] }),
      auditExceptions: async () => assert.fail('the client must not request Accounting-only records'),
    } })
    t.after(() => view.dispose())
    view.render(); await view.effects()
    const result = view.render()
    assert.equal(result.props.canReadExceptions, false)
    assert.equal(result.props.error, '')
    assert.equal(result.props.data.rows.length, 1)
    assert.equal(result.props.data.activity.length, 1)
    const content = result.type(result.props)
    assert.match(text(content), /available to Accounting administrators/)
    assert.equal(button(content, 'Download scan CSV').props.disabled, false)
    assert.doesNotMatch(text(content), /QR monitor unavailable|No custody exceptions found/)
    const table = walk(content, node => node.type === 'DocTable')
    const link = table.props.columns.find(column => column.key === 'document_id').render(result.props.data.rows[0])
    assert.equal(link.type, 'Link')
    assert.equal(link.props.to, '/history?id=DOC-2026-000007')
    assert.equal(link.props['aria-label'], 'View history of DOC-2026-000007')
  }
})

test('Accounting exception failure leaves scan records/export usable and retries without a false all-clear', async t => {
  let exceptionReads = 0
  const view = await page('AdminQrMonitorPage', { user: { ...staff, role: 'admin' }, smartflow: {
    auditScans: async () => ({ events: [{ document_id: 'DOC-2026-000007' }] }),
    auditActivity: async () => ({ events: [] }),
    auditExceptions: async hours => { assert.equal(hours, 24); if (++exceptionReads === 1) throw new Error('Exception read unavailable'); return { exceptions: [] } },
  } })
  t.after(() => view.dispose())
  view.render(); await view.effects()
  let result = view.render(), content = result.type(result.props)
  assert.equal(result.props.error, '')
  assert.equal(result.props.data.rows.length, 1)
  assert.match(text(content), /Custody exceptions unavailable/)
  assert.doesNotMatch(text(content), /No custody exceptions found/)
  assert.equal(button(content, 'Download scan CSV').props.disabled, false)
  button(content, 'Retry exceptions').props.onClick()
  view.render(); await view.effects(); result = view.render(); content = result.type(result.props)
  assert.equal(exceptionReads, 2)
  assert.match(text(content), /No custody exceptions found/)
  assert.match(text(content), /Missing receipt records after 24 hours/)
  assert.doesNotMatch(text(content), /Custody exceptions unavailable|No exceptions in the last 48h/)
})

const approved = { id: 7, request_code: 'REQ-2026-0007', status: 'approved', document_category: 'budget', revision: 'a'.repeat(64), handler_office: { office_id: 3, office_code: 'ACC' }, requester: { user_id: 8 } }
async function picker(t, smartflow, req = approved) {
  const view = await page('RequestsPage', { user: staff, smartflow })
  t.after(() => view.dispose())
  view.context.Page = view.context.FolderSelector
  let value = ''
  const props = { req, user: staff, get value() { return value }, onChange(next) { value = next }, disabled: false }
  view.render(props); await view.effects()
  return { view, props, value: () => value }
}
function fillLookup(view, props, id) {
  walk(view.render(props), node => node.type === 'input').props.onChange({ target: { value: id } })
  return button(view.render(props), 'Find folder').props.onClick()
}

test('exact lookup selects a category-matching historical folder even after late tray suggestions finish', async t => {
  const suggestions = deferred()
  const calls = []
  const folder = { id: 'DOC-2026-000007', title: 'Previously handled budget', type: 'Approved Budget', current_office_id: 4 }
  const { view, props, value } = await picker(t, {
    officeDocuments: () => suggestions.promise,
    documentShow: async id => { calls.push(id); return { document: folder } },
    recordMovement: () => assert.fail('lookup cannot record custody'),
    documentRequestUpdate: () => assert.fail('finding a folder cannot link it'),
  })
  await fillLookup(view, props, ' doc-2026-000007 ')
  assert.deepEqual(calls, [folder.id])
  assert.equal(value(), folder.id)
  suggestions.resolve({ documents: [] }); await view.effects()
  const select = walk(view.render(props), node => node.type === 'select')
  assert.equal(select.props.value, folder.id)
  assert.equal(select.props.disabled, false)
  assert.match(text(select), /Previously handled budget/)
  assert.match(text(view.render(props)), /handling office registered or handled/)
})

test('exact folder lookup keeps category checks, invalid-ID validation and 403 without a fallback', async t => {
  const calls = []
  let response = { document: { id: 'DOC-2026-000007', type: 'Disbursement Voucher' } }
  const { view, props, value } = await picker(t, {
    officeDocuments: async (...args) => { calls.push(['tray', ...args]); return { documents: [] } },
    documentShow: async id => { calls.push(['show', id]); if (response instanceof Error) throw response; return response },
  })
  await fillLookup(view, props, 'not-a-tracking-id')
  assert.equal(calls.filter(call => call[0] === 'show').length, 0)
  assert.match(text(view.render(props)), /complete tracking ID/)
  await fillLookup(view, props, 'DOC-2026-000007')
  assert.equal(value(), '')
  assert.match(text(view.render(props)), /does not match the request category/)
  response = new view.context.ApiError('Folder access denied')
  response.status = 403
  await fillLookup(view, props, 'DOC-2026-000007')
  assert.equal(value(), '')
  assert.match(text(view.render(props)), /Folder access denied/)
  assert.equal(calls.filter(call => call[0] === 'tray').length, 1, 'a direct lookup denial must not retry via another scope')
  props.disabled = true
  await button(view.render(props), 'Find folder').props.onClick()
  assert.equal(calls.filter(call => call[0] === 'show').length, 2)
})

test('closing an exact folder lookup discards its late response and selection', async t => {
  const pending = deferred()
  const { view, props, value } = await picker(t, { officeDocuments: async () => ({ documents: [] }), documentShow: () => pending.promise })
  const lookup = fillLookup(view, props, 'DOC-2026-000007')
  view.dispose()
  pending.resolve({ document: { id: 'DOC-2026-000007', type: 'Approved Budget' } })
  await lookup
  assert.equal(value(), '')
})

test('confirming a found request folder preserves the reviewed status/revision and sends no custody action', async t => {
  let current = approved
  const writes = []
  const view = await page('RequestsPage', { user: staff, smartflow: {
    documentRequestsList: async () => ({ requests: [current] }),
    documentRequestUpdate: async body => { writes.push(body); current = { ...current, related_document_id: body.related_document_id, revision: 'b'.repeat(64) }; return { request: current } },
    recordMovement: () => assert.fail('linking cannot record custody'),
  } }, 'id=7')
  t.after(() => view.dispose())
  Object.assign(view.context, { useLocation: () => ({ state: null }), requestViewFromSearch, requestViewParams, requestReturnPath, validRequestPath, documentRequestCategoriesForOffice, statusLabel, Event: class Event {} })
  view.context.window.matchMedia = () => ({ matches: true, addEventListener() {}, removeEventListener() {} })
  view.context.window.dispatchEvent = () => {}
  view.render(); await view.effects()
  const details = walk(view.render(), node => node.type?.name === 'RequestDetailPanel')
  assert.equal(details.props.fresh, true)
  details.props.onAction(approved, 'link')
  let tree = view.render()
  const selector = walk(tree, node => node.type?.name === 'FolderSelector')
  assert.equal(selector.props.disabled, false)
  selector.props.onChange('DOC-2026-000007')
  tree = view.render()
  await button(tree, 'Link folder').props.onClick()
  assert.equal(writes.length, 1)
  assert.equal(writes[0].request_id, approved.id)
  assert.equal(writes[0].action, 'link')
  assert.equal(writes[0].expected_status, approved.status)
  assert.equal(writes[0].expected_revision, approved.revision)
  assert.equal(writes[0].related_document_id, 'DOC-2026-000007')
})

test('Documents retained empty refresh failure is qualified until a verified retry', async t => {
  let reads = 0
  const view = await page('DocumentsPage', { user: staff, smartflow: {
    officeDocuments: async () => { if (++reads === 2) throw new Error('Synthetic read unavailable'); return { documents: [] } },
    offices: async () => ({ offices: [] }),
  } }, 'overdue=1')
  t.after(() => view.dispose())
  Object.assign(view.context, { useLocation: () => ({ state: null }), custodyReportReturnPath, documentQueue, preferredForwardDestination: () => '' })
  view.render(); await view.effects()
  assert.match(text(view.render()), /No overdue folders in this view/)
  view.context.revision++; view.render(); await view.effects()
  let tree = view.render()
  assert.match(text(tree), /Current folder status could not be verified/)
  assert.doesNotMatch(text(tree), /No overdue folders in this view/)
  walk(tree, node => node.props?.['aria-label'] === 'Refresh documents').props.onClick()
  view.render(); await view.effects(); tree = view.render()
  assert.match(text(tree), /No overdue folders in this view/)
  assert.doesNotMatch(text(tree), /Current folder status could not be verified/)
})

test('System accurately names role totals and recorded movements', async t => {
  const view = await page('AdminSystemPage', { smartflow: { systemStatus: async () => ({ ...health, role_counts: { staff: 18, head: 1, admin: 1 }, users: { active: 2, inactive: 18 }, operations: { movements_today: 7 } }) } })
  t.after(() => view.dispose())
  view.render(); await view.effects()
  const output = text(view.render()).replace(/\s+/g, ' ')
  assert.match(output, /Accounts by role 18 clerks/)
  assert.match(output, /7 Movements today/)
  assert.doesNotMatch(output, /Accounts on duty|Scans today/)
})

test('Profile initial failure offers Retry and retains an explicitly stale overview on later failure', async t => {
  let reads = 0
  const view = await page('ProfilePage', { user: staff, smartflow: { dashboardStats: async () => { if (++reads === 1 || reads === 3) throw new Error('Synthetic failure'); return emptyDesk } } })
  t.after(() => view.dispose())
  view.context.roleLabel = role => role
  view.render(); await view.effects()
  let tree = view.render()
  assert.match(text(tree), /Overview unavailable/)
  button(tree, 'Retry overview').props.onClick()
  view.render(); await view.effects(); tree = view.render()
  assert.doesNotMatch(text(tree), /Overview unavailable/)
  assert.match(text(tree), /Today's desk.*Received.*Sent.*On desk/)
  button(tree, 'Refresh overview').props.onClick()
  view.render(); await view.effects(); tree = view.render()
  assert.match(text(tree), /Overview refresh failed.*counts may be out of date/)
  assert.match(text(tree), /Last successful update.*Received/)
})

test('Profile system-status failure cannot turn an available administrator overview into API offline', async t => {
  const view = await page('ProfilePage', { user: { ...staff, role: 'admin' }, smartflow: { accountantDashboard: async () => ({ stats: { active_documents: 7 } }), systemStatus: async () => { throw new Error('Status read unavailable') } } })
  t.after(() => view.dispose())
  view.context.roleLabel = role => role
  view.render(); await view.effects()
  const output = text(view.render())
  assert.match(output, /System status unverified/)
  assert.match(output, /Municipal overview.*7/)
  assert.doesNotMatch(output, /API offline|API online/)
})

test('Offices retry distinguishes unavailable, verified empty and a retained stale empty read', async t => {
  let reads = 0
  const view = await page('AdminOfficesPage', { smartflow: { adminOffices: async () => { if (++reads === 1 || reads === 3) throw new Error('Synthetic failure'); return { offices: [] } } } })
  t.after(() => view.dispose())
  view.render(); await view.effects()
  let tree = view.render()
  assert.match(text(tree), /Offices unavailable/)
  assert.doesNotMatch(text(tree), /No offices configured/)
  button(tree, 'Retry offices').props.onClick()
  view.render(); await view.effects(); tree = view.render()
  assert.match(text(tree), /No offices configured/)
  button(tree, 'Refresh offices').props.onClick()
  view.render(); await view.effects(); tree = view.render()
  assert.match(text(tree), /Office refresh failed.*Previously loaded office rules may be out of date/)
  assert.doesNotMatch(text(tree), /No offices configured/)
})

test('New request controls have associated visible labels in both request kinds', async t => {
  const view = await page('RequestsPage', { user: staff, smartflow: { offices: async () => ({ offices: [{ id: 4, name: 'Treasury' }] }) } })
  t.after(() => view.dispose())
  view.context.Page = view.context.CreateRequestForm
  const props = { categories: [{ value: 'budget', label: 'Budget' }], onDone() {}, onError() {} }
  view.render(props); await view.effects()
  const check = tree => {
    for (const label of ['request-kind', 'request-purpose', 'request-required-by']) {
      assert.ok(walk(tree, node => node.type === 'label' && node.props.htmlFor === label))
      assert.ok(walk(tree, node => node.props?.id === label && ['input', 'textarea', 'select'].includes(node.type)))
    }
  }
  let tree = view.render(props)
  check(tree)
  assert.ok(walk(tree, node => node.type === 'label' && node.props.htmlFor === 'request-category'))
  walk(tree, node => node.props?.id === 'request-kind').props.onChange({ target: { value: 'pull' } })
  tree = view.render(props); check(tree)
  assert.ok(walk(tree, node => node.type === 'label' && node.props.htmlFor === 'request-target-office'))
})


