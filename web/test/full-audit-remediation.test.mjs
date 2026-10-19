import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'
import { transformWithOxc } from 'vite'
import { reportPeriodBounds } from '../src/tracking.js'
import { beginScopedRead, failScopedRead, scopedReadView } from '../src/scoped-read.js'

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
    reportPeriodBounds, beginScopedRead, failScopedRead, scopedReadView,
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

test('staff initial failure is unavailable, and Retry restores verified empty data', async t => {
  let calls = 0
  const retry = deferred()
  const view = await page('StaffHomePage', { user: staff, smartflow: { dashboardStats: () => ++calls === 1 ? Promise.reject(new Error('offline')) : retry.promise } })
  t.after(() => view.dispose())
  view.render(); await view.effects()
  let tree = view.render()
  assert.match(text(tree), /Dashboard unavailable.*Desk unavailable.*Incoming unavailable/)
  assert.doesNotMatch(text(tree), /Your desk is clear|No folders on the way/)
  assert.equal(walk(tree, node => node.type === 'HomeMetrics'), null)
  button(tree, 'Retry').props.onClick()
  view.render(); await view.effects(); tree = view.render()
  assert.equal(button(tree, 'Retrying…').props.disabled, true)
  assert.match(text(tree), /Dashboard unavailable/)
  retry.resolve(emptyDesk); await view.effects(); tree = view.render()
  assert.match(text(tree), /Your desk is clear.*No folders on the way/)
  assert.doesNotMatch(text(tree), /Dashboard unavailable|out of date/)
  assert.equal(walk(tree, node => node.type === 'HomeMetrics').props.items[0].value, 0)
})

test('staff failed refresh retains counts with stale labeling through Retry, without an all-clear', async t => {
  let calls = 0
  const retry = deferred()
  const view = await page('StaffHomePage', { user: staff, smartflow: { dashboardStats: () => ++calls === 1 ? Promise.resolve(emptyDesk) : calls === 2 ? Promise.reject(new Error('offline')) : retry.promise } })
  t.after(() => view.dispose())
  view.render(); await view.effects()
  view.context.revision++
  view.render(); await view.effects()
  let tree = view.render()
  assert.match(text(tree), /Refresh failed.*previously loaded data.*out of date/)
  assert.match(text(tree), /Previously loaded desk is empty.*Previously loaded incoming list is empty/)
  assert.doesNotMatch(text(tree), /Your desk is clear|No folders on the way/)
  assert.equal(walk(tree, node => node.type === 'HomeMetrics').props.items[2].value, 0)
  button(tree, 'Retry').props.onClick()
  view.render(); await view.effects(); tree = view.render()
  assert.match(text(tree), /Refresh failed.*out of date/)
  assert.equal(button(tree, 'Retrying…').props.disabled, true)
  retry.resolve({ ...emptyDesk, stats: { in_flow: 2, out_flow: 1, active_tags: 0 } })
  await view.effects(); tree = view.render()
  assert.doesNotMatch(text(tree), /Refresh failed|out of date|Previously loaded/)
  assert.equal(walk(tree, node => node.type === 'HomeMetrics').props.items[0].value, 2)
})

test('System initial failure reports unavailable and has no healthy pill or counts', async t => {
  let calls = 0
  const view = await page('AdminSystemPage', { user: { ...staff, role: 'admin' }, smartflow: { systemStatus: async () => { if (++calls === 1) throw new Error('offline'); return health } } })
  t.after(() => view.dispose())
  view.render(); await view.effects()
  let tree = view.render()
  assert.match(text(tree), /System status unavailable.*API and database health could not be checked/)
  assert.equal(walk(tree, node => node.type === 'StatusPill'), null)
  assert.doesNotMatch(text(tree), /Active users|Scans today|Updated/)
  await button(tree, 'Refresh status').props.onClick(); tree = view.render()
  assert.equal(walk(tree, node => node.type === 'StatusPill').props.tone, 'ok')
  assert.match(text(tree), /online/)
  assert.doesNotMatch(text(tree), /unavailable|unverified/)
})

test('System retained health stays unverified after failure and while retrying, until a successful read', async t => {
  let calls = 0
  const retry = deferred()
  const view = await page('AdminSystemPage', { user: { ...staff, role: 'admin' }, smartflow: { systemStatus: () => ++calls === 1 ? Promise.resolve(health) : calls === 2 ? Promise.reject(new Error('offline')) : retry.promise } })
  t.after(() => view.dispose())
  view.render(); await view.effects()
  await button(view.render(), 'Refresh status').props.onClick()
  let tree = view.render()
  assert.match(text(tree), /Status refresh failed.*last successful check.*unverified.*Last successful check/)
  assert.doesNotMatch(text(tree), /Updated/)
  let pill = walk(tree, node => node.type === 'StatusPill')
  assert.equal(pill.props.tone, 'warn'); assert.equal(text(pill).trim(), 'Unverified')
  const pending = button(tree, 'Refresh status').props.onClick()
  tree = view.render()
  assert.match(text(tree), /Status refresh failed.*unverified/)
  assert.equal(button(tree, 'Refreshing…').props.disabled, true)
  assert.equal(walk(tree, node => node.type === 'StatusPill').props.tone, 'warn')
  retry.resolve(health); await pending; tree = view.render()
  assert.match(text(tree), /Updated/)
  assert.equal(walk(tree, node => node.type === 'StatusPill').props.tone, 'ok')
  assert.doesNotMatch(text(tree), /refresh failed|unverified|Unverified/)
})

test('Scan keeps a saved destination correction visible after a failed read; Retry only reads and refreshes reviewed guards', async t => {
  let reads = 0, writes = 0
  const doc = { id: 'DOC-2026-000001', title: 'Synthetic transfer', type: 'Others: Transfer', current_status: 'OUT', current_office_id: 3, current_office_name: 'Accounting Office', destination_office_id: 2, destination_office_name: 'Budget Office', can_correct_destination: true, last_movement_id: 41, last_destination_correction_id: 0 }
  const current = { ...doc, destination_office_id: 4, destination_office_name: 'Treasury Office', last_destination_correction_id: 7 }
  const view = await page('ScanPage', { user: staff, smartflow: {
    offices: async () => ({ offices: [] }),
    documentShow: async id => { assert.equal(id, doc.id); reads++; if (reads === 2) throw new Error('Details service unavailable'); return { document: reads === 1 ? doc : current } },
    recordMovement: () => { writes++; assert.fail('follow-up must not write') },
  } }, `id=${doc.id}`)
  t.after(() => view.dispose())
  view.render(); await view.effects()
  const correction = walk(view.render(), node => node.type === 'DestinationCorrection')
  const message = 'Recorded destination corrected to Treasury. No receipt or new handoff was recorded.'
  await correction.props.onChanged({ success: true, message, correction_id: 7 })
  let tree = view.render()
  assert.ok(text(tree).includes(message))
  assert.equal(walk(tree, node => node.type === 'DestinationCorrection').props.disabled, true)
  const recovery = walk(tree, node => node.type?.name === 'ScanCustodyRecovery')
  assert.equal(recovery.props.saved, true)
  assert.match(text(recovery.type(recovery.props)), /The action was saved.*Details service unavailable.*Retry folder details/)
  assert.equal(reads, 2); assert.equal(writes, 0)
  await button(recovery.type(recovery.props), 'Retry folder details').props.onClick()
  tree = view.render()
  assert.ok(text(tree).includes(message))
  assert.equal(walk(tree, node => node.type?.name === 'ScanCustodyRecovery'), null)
  const refreshed = walk(tree, node => node.type === 'DestinationCorrection')
  assert.equal(refreshed.props.disabled, false)
  assert.equal(refreshed.props.document.last_movement_id, 41)
  assert.equal(refreshed.props.document.last_destination_correction_id, 7)
  assert.equal(refreshed.props.document.destination_office_id, 4)
  assert.equal(reads, 3); assert.equal(writes, 0)
})

async function cameraPage(t, smartflow) {
  const view = await page('ScanPage', { user: staff, smartflow })
  t.after(() => view.dispose())
  const callbacks = []
  let stopped = 0
  view.context.window.matchMedia = () => ({ matches: false })
  view.context.document = { getElementById: () => ({ innerHTML: '' }) }
  view.context.Html5Qrcode = class {
    isScanning = true
    async start(_camera, _options, callback) { callbacks.push(callback) }
    async stop() { this.isScanning = false; stopped++ }
    clear() {}
  }
  let now = 5000
  view.context.Date = class extends Date { static now() { now += 2000; return now } }
  view.render(); await view.effects()
  return { view, callbacks, stopped: () => stopped }
}

test('camera consumes one label; late decodes preserve the actual open correction draft and saved read-retry outcome', async t => {
  const doc = { id: 'DOC-2026-000001', title: 'Synthetic transfer', type: 'Others: Transfer', current_status: 'OUT', current_office_id: 3, current_office_name: 'Accounting Office', destination_office_id: 2, destination_office_name: 'Budget Office', can_correct_destination: true, last_movement_id: 41, last_destination_correction_id: 0 }
  let reads = 0, writes = 0
  const auth = { user: staff, api: () => { writes++; assert.fail('camera lookup must not write') }, smartflow: {
    offices: async () => ({ offices: [{ id: 4, name: 'Treasury Office' }] }),
    documentShow: async () => { reads++; if (reads === 2) throw new Error('Details unavailable'); return { document: doc } },
  } }
  const { view, callbacks, stopped } = await cameraPage(t, auth.smartflow)
  callbacks[0](doc.id); await view.effects()
  let tree = view.render()
  const correction = walk(tree, node => node.type === 'DestinationCorrection')
  assert.ok(correction)
  assert.equal(reads, 1)
  await view.effects()

  // Exercise the real correction component's controlled draft and confirmation.
  const form = await page('DestinationCorrection', auth, '', 'components')
  t.after(() => form.dispose())
  button(form.render(correction.props), 'Correct recorded destination').props.onClick()
  form.render(correction.props); await form.effects()
  let draft = form.render(correction.props)
  walk(draft, node => node.type === 'select').props.onChange({ target: { value: '4' } })
  walk(draft, node => node.type === 'textarea').props.onChange({ target: { value: 'Synthetic destination correction reason' } })
  walk(draft, node => node.type === 'input' && node.props.type === 'checkbox').props.onChange({ target: { checked: true } })

  callbacks[0](doc.id)
  callbacks[0]('DOC-2026-000002')
  tree = view.render()
  const retained = walk(tree, node => node.type === 'DestinationCorrection')
  assert.ok(retained, 'late decoder callbacks must not unmount the correction component')
  assert.ok(button(tree, 'Use camera'))
  assert.equal(stopped(), 1)
  assert.equal(retained.props.document, doc)
  draft = form.render(retained.props)
  assert.equal(walk(draft, node => node.type === 'Modal').props.open, true)
  assert.equal(walk(draft, node => node.type === 'select').props.value, '4')
  assert.equal(walk(draft, node => node.type === 'textarea').props.value, 'Synthetic destination correction reason')
  assert.equal(walk(draft, node => node.type === 'input' && node.props.type === 'checkbox').props.checked, true)
  assert.equal(button(draft, 'Confirm correction').props.disabled, false)
  assert.equal(reads, 1); assert.equal(writes, 0)

  const savedRead = retained.props.onChanged({ success: true, message: 'Synthetic correction saved' })
  callbacks[0](doc.id)
  assert.equal(walk(view.render(), node => node.type === 'DestinationCorrection').props.disabled, true)
  await savedRead
  callbacks[0](doc.id)
  tree = view.render()
  const recovery = walk(tree, node => node.type?.name === 'ScanCustodyRecovery')
  assert.equal(recovery.props.saved, true)
  assert.match(text(tree), /Synthetic correction saved/)
  assert.equal(walk(tree, node => node.type === 'DestinationCorrection').props.disabled, true)
  assert.equal(reads, 2); assert.equal(writes, 0)
  await button(recovery.type(recovery.props), 'Retry folder details').props.onClick()
  assert.equal(reads, 3); assert.equal(writes, 0)
})

test('explicit camera restart can select another folder; previous camera callbacks stay inert during the new read', async t => {
  let reads = 0
  const next = deferred()
  const first = { id: 'DOC-2026-000001', title: 'First synthetic folder' }
  const second = { id: 'DOC-2026-000002', title: 'Second synthetic folder' }
  const { view, callbacks } = await cameraPage(t, {
    offices: async () => ({ offices: [] }),
    documentShow: id => { reads++; return id === first.id ? Promise.resolve({ document: first }) : next.promise },
  })
  callbacks[0](first.id); await view.effects()
  view.render(); await view.effects()
  button(view.render(), 'Use camera').props.onClick()
  view.render(); await view.effects()
  assert.equal(callbacks.length, 2)
  callbacks[1](second.id)
  callbacks[0](first.id)
  callbacks[1](second.id)
  assert.equal(reads, 2)
  next.resolve({ document: second }); await view.effects()
  assert.match(text(view.render()), /Second synthetic folder/)
  assert.doesNotMatch(text(view.render()), /First synthetic folder/)
})

test('invalid camera lookup stops its session and permits explicit restart without automatic retries', async t => {
  let reads = 0
  const { view, callbacks } = await cameraPage(t, {
    offices: async () => ({ offices: [] }),
    documentShow: async id => { reads++; return { document: { id, title: 'Recovered synthetic folder' } } },
  })
  callbacks[0]('unrelated QR text'); await view.effects()
  let tree = view.render(); await view.effects()
  assert.match(text(tree), /Invalid tracking ID/)
  assert.equal(reads, 0)
  button(tree, 'Use camera').props.onClick()
  view.render(); await view.effects()
  callbacks[1]('DOC-2026-000001'); await view.effects()
  tree = view.render()
  assert.match(text(tree), /Recovered synthetic folder/)
  assert.doesNotMatch(text(tree), /Invalid tracking ID/)
  assert.equal(reads, 1)
})

test('failed camera folder read permits explicit camera retry without silently repeating it', async t => {
  let reads = 0
  const { view, callbacks } = await cameraPage(t, {
    offices: async () => ({ offices: [] }),
    documentShow: async id => { if (++reads === 1) throw new Error('Synthetic offline read'); return { document: { id, title: 'Retried synthetic folder' } } },
  })
  callbacks[0]('DOC-2026-000001'); await view.effects()
  let tree = view.render(); await view.effects()
  assert.match(text(tree), /Lookup failed/)
  callbacks[0]('DOC-2026-000001')
  assert.equal(reads, 1)
  button(tree, 'Use camera').props.onClick()
  view.render(); await view.effects()
  callbacks[1]('DOC-2026-000001'); await view.effects()
  tree = view.render()
  assert.match(text(tree), /Retried synthetic folder/)
  assert.equal(reads, 2)
})

test('Head Analytics initializes and queries the local calendar month across Manila month and year boundaries', async t => {
  for (const [instant, expected] of [
    ['2026-10-31T15:59:59Z', '2026-10'],
    ['2026-10-31T16:00:00Z', '2026-11'],
    ['2026-10-31T23:59:59Z', '2026-11'],
    ['2026-11-01T00:00:00Z', '2026-11'],
    ['2026-12-31T16:00:00Z', '2027-01'],
  ]) {
    const queries = []
    const view = await page('HeadAnalyticsPage', { user: { ...staff, role: 'head' }, smartflow: {
      headAnalytics: async (office, month) => { queries.push([office, month]); return { month, stats: {} } },
    } })
    t.after(() => view.dispose())
    const LocalDate = class extends Date {
      constructor(...args) { super(...(args.length ? args : [instant])) }
      getFullYear() { return new Date(this.getTime() + 8 * 3600000).getUTCFullYear() }
      getMonth() { return new Date(this.getTime() + 8 * 3600000).getUTCMonth() }
    }
    view.context.Date = LocalDate
    view.context.reportPeriodBounds = () => reportPeriodBounds(new LocalDate())
    const tree = view.render(); await view.effects()
    assert.equal(tree.props.month, expected, instant)
    assert.deepEqual(queries.map(row => [...row]), [[staff.office_id, expected]])
  }
})
