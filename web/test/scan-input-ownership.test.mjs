import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'
import { transformWithOxc } from 'vite'
import { ApiError } from '../src/api.js'
import { isSignedQrPayload, parseTrackingId } from '../src/tracking.js'

// Exercise the actual page callbacks with a controlled decoder and synthetic
// reads. Camera hardware and image decoding remain separate browser acceptance.
async function scanPage(t, smartflow, decode) {
  const source = await readFile(new URL('../src/pages/ScanPage.jsx', import.meta.url), 'utf8')
  const slots = [], pending = [], cameraCallbacks = [], scanners = []
  let cursor = 0, clock = 5000
  const sameDeps = (a, b) => a && b && a.length === b.length && a.every((value, i) => Object.is(value, b[i]))
  const useState = initial => {
    const at = cursor++
    if (!(at in slots)) slots[at] = typeof initial === 'function' ? initial() : initial
    return [slots[at], value => { slots[at] = typeof value === 'function' ? value(slots[at]) : value }]
  }
  const useRef = initial => {
    const at = cursor++
    if (!(at in slots)) slots[at] = { current: initial }
    return slots[at]
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
    Date: class extends Date { static now() { clock += 2000; return clock } },
    Number, String, Boolean, Object, Math, URLSearchParams, ApiError,
    h: (type, props, ...children) => ({ type, props: { ...props, children } }), Fragment: 'Fragment',
    useState, useRef, useEffect,
    useAuth: () => ({ user: { id: 5, role: 'staff', office_id: 3 }, smartflow }),
    useSearchParams: () => [new URLSearchParams()],
    window: { matchMedia: () => ({ matches: false }), setTimeout: () => 0, clearTimeout() {} },
    document: { getElementById: () => ({ innerHTML: '' }) },
    useFolderReceipt: () => ({ requestReceipt: async () => null, receiptDialog: null }),
    useFolderFiling: () => ({ requestFiling: async () => false, filingDialog: null }),
    isSignedQrPayload, parseTrackingId,
    preferredForwardDestination: () => '',
    clerkScanActions: () => ({ canIn: false, canOut: false }),
    Html5Qrcode: class {
      constructor(host) { this.host = host; this.isScanning = host === 'sf-reader'; this.stops = 0; this.clears = 0; scanners.push(this) }
      async start(_camera, _options, callback) { cameraCallbacks.push(callback) }
      async stop() { this.isScanning = false; this.stops++ }
      clear() { this.clears++ }
      scanFile(file, showImage) { assert.equal(showImage, false); return decode(file) }
    },
  }
  for (const line of source.matchAll(/^import \{([^}]+)\} from /gm)) {
    for (const entry of line[1].split(',').map(value => value.trim())) if (!(entry in context)) context[entry] = entry
  }
  for (const line of source.matchAll(/^import (\w+) from /gm)) if (!(line[1] in context)) context[line[1]] = line[1]
  const local = source.replace(/^import .*\r?\n/gm, '').replace(/export default function /, 'function ').replace(/export function /g, 'function ')
  const transformed = await transformWithOxc(`${local}\nglobalThis.Page=ScanPage`, 'ScanPage.jsx', { jsx: { runtime: 'classic', pragma: 'h', pragmaFrag: 'Fragment' } })
  vm.createContext(context)
  vm.runInContext(transformed.code, context)
  const view = {
    render() { cursor = 0; return context.Page() },
    async effects() { while (pending.length) pending.shift()(); for (let i = 0; i < 12; i++) await Promise.resolve() },
    cameraCallbacks, scanners,
  }
  t.after(() => { for (const slot of slots) slot?.cleanup?.() })
  view.render(); await view.effects()
  return view
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
const fileInput = tree => walk(tree, node => node.type === 'input' && node.props.type === 'file')
const fileEvent = () => ({ target: { files: [{ name: 'synthetic-folder.png' }], value: 'synthetic-folder.png' } })
function deferred() { let resolve, reject; const promise = new Promise((done, fail) => { resolve = done; reject = fail }); return { promise, resolve, reject } }

test('upload chooser retires the camera before opening; cancelled chooser records no lookup', async t => {
  let chooserOpened = 0, reads = 0, decodes = 0
  const view = await scanPage(t, { offices: async () => ({ offices: [] }), documentShow: async id => { reads++; return { document: { id } } } }, async () => { decodes++; return 'DOC-2026-000001' })
  const tree = view.render()
  fileInput(tree).props.ref.current = { click() { chooserOpened++; view.cameraCallbacks[0]('DOC-2026-000001') } }
  button(tree, 'Upload QR image').props.onClick()
  assert.equal(chooserOpened, 1)
  await fileInput(tree).props.onChange({ target: { files: [], value: '' } })
  view.render(); await view.effects()
  assert.ok(button(view.render(), 'Use camera'))
  assert.equal(view.scanners[0].stops, 1)
  assert.equal(reads, 0)
  assert.equal(decodes, 0)
})

test('uploaded image owns lookup through decoding and reading, ignoring late camera and competing inputs', async t => {
  const decoded = deferred(), detail = deferred(), reads = []
  let decodes = 0, writes = 0
  const view = await scanPage(t, {
    offices: async () => ({ offices: [] }),
    documentShow: id => { reads.push(id); return detail.promise },
    recordMovement: () => { writes++; assert.fail('QR lookup must not record a handoff') },
  }, () => { decodes++; return decoded.promise })
  const initial = view.render(), input = fileInput(initial), event = fileEvent()
  const upload = input.props.onChange(event)
  assert.equal(event.target.value, '')
  view.cameraCallbacks[0]('DOC-2026-000001')
  const competingUpload = input.props.onChange(fileEvent())
  const manual = walk(initial, node => node.type === 'input' && node.props.id === 'scan-tracking-id')
  manual.props.onChange({ target: { value: 'DOC-2026-000003' } })
  const duringDecode = view.render()
  await walk(duringDecode, node => node.type === 'form').props.onSubmit({ preventDefault() {} })
  assert.equal(button(duringDecode, 'Reading image…').props.disabled, true)
  assert.equal(decodes, 1)
  assert.deepEqual(reads, [])
  decoded.resolve('DOC-2026-000002'); await view.effects()
  view.cameraCallbacks[0]('DOC-2026-000001')
  assert.deepEqual(reads, ['DOC-2026-000002'])
  detail.resolve({ document: { id: 'DOC-2026-000002', title: 'Uploaded folder' } })
  await upload
  await competingUpload
  view.cameraCallbacks[0]('DOC-2026-000001')
  const result = view.render()
  assert.match(text(result), /Uploaded folder/)
  assert.match(text(result), /QR read from uploaded image/)
  assert.doesNotMatch(text(result), /DOC-2026-000001/)
  assert.equal(view.scanners.find(scanner => scanner.host === 'sf-file-reader').clears, 1)
  assert.equal(writes, 0)
})

test('signed QR upload verifies before showing its folder and records no movement', async t => {
  const calls = [], payload = 'SF1.synthetic.signature'
  const view = await scanPage(t, {
    offices: async () => ({ offices: [] }),
    verifyQr: async value => { calls.push(['verify', value]); return { document_id: 'DOC-2026-000042' } },
    documentShow: async id => { calls.push(['show', id]); return { document: { id, title: 'Verified image folder' } } },
    recordMovement: () => assert.fail('verification must not record a movement'),
  }, async () => ` ${payload} `)
  await fileInput(view.render()).props.onChange(fileEvent())
  assert.deepEqual(calls, [['verify', payload], ['show', 'DOC-2026-000042']])
  assert.match(text(view.render()), /Verified image folder/)
})

test('failed image decoder releases resources and allows explicit same-file retry', async t => {
  let decodes = 0, reads = 0
  const view = await scanPage(t, {
    offices: async () => ({ offices: [] }),
    documentShow: async id => { reads++; return { document: { id, title: 'Retried image folder' } } },
  }, async () => { if (++decodes === 1) throw new Error('No QR'); return 'DOC-2026-000009' })
  await fileInput(view.render()).props.onChange(fileEvent())
  assert.match(text(view.render()), /Could not read a QR from that image/)
  assert.equal(reads, 0)
  assert.equal(view.scanners.find(scanner => scanner.host === 'sf-file-reader').clears, 1)
  await fileInput(view.render()).props.onChange(fileEvent())
  assert.equal(reads, 1)
  assert.match(text(view.render()), /Retried image folder/)
  assert.doesNotMatch(text(view.render()), /Could not read a QR/)
})

test('image selection during an existing lookup cannot replace the pending reviewed folder', async t => {
  const detail = deferred(), reads = []
  let decodes = 0
  const view = await scanPage(t, {
    offices: async () => ({ offices: [] }),
    documentShow: id => { reads.push(id); return detail.promise },
  }, async () => { decodes++; return 'DOC-2026-000012' })
  view.cameraCallbacks[0]('DOC-2026-000011')
  await fileInput(view.render()).props.onChange(fileEvent())
  detail.resolve({ document: { id: 'DOC-2026-000011', title: 'Pending camera folder' } })
  await view.effects()
  assert.equal(decodes, 0)
  assert.deepEqual(reads, ['DOC-2026-000011'])
  assert.match(text(view.render()), /Pending camera folder/)
})
