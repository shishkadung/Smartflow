import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'
import { transformWithOxc } from 'vite'
import { documentTypesForOffice, OTHER_DOCUMENT_TYPE } from '../src/tracking.js'

// Exercise the actual recovery-to-success branch without HTTP or a registration write.
async function registration() {
  const source = await readFile(new URL('../src/pages/RegisterPage.jsx', import.meta.url), 'utf8')
  const slots = []
  let cursor = 0
  const context = {
    Date, Object, Number, String, Boolean,
    h: (type, props, ...children) => ({ type, props: { ...props, children } }),
    Fragment: 'Fragment',
    useState: initial => {
      const index = cursor++
      if (!(index in slots)) slots[index] = typeof initial === 'function' ? initial() : initial
      return [slots[index], value => { slots[index] = typeof value === 'function' ? value(slots[index]) : value }]
    },
    useMemo: create => create(), useEffect() {},
    useSearchParams: () => [new URLSearchParams(), () => {}],
    useAuth: () => ({ user: { id: 1, role: 'staff', office_id: 1, office_code: 'ENG', office_name: 'Engineering Office' }, smartflow: new Proxy({}, { get() { assert.fail('Reviewing registration guidance must not call the API') } }) }),
    documentTypesForOffice, OTHER_DOCUMENT_TYPE,
    emptyInventory: () => ({ count_confirmed: false, items: [{ name: 'Main document', pages: '', required: true }] }),
  }
  for (const match of source.matchAll(/^import \{([^}]+)\} from /gm)) for (const name of match[1].split(',').map(value => value.trim())) if (!(name in context)) context[name] = name
  for (const match of source.matchAll(/^import (\w+) from /gm)) if (!(match[1] in context)) context[match[1]] = match[1]
  const local = source.replace(/^import .*\r?\n/gm, '').replace('export default function ', 'function ')
  const result = await transformWithOxc(`${local}\nglobalThis.Page=RegisterPage`, 'RegisterPage.jsx', { jsx: { runtime: 'classic', pragma: 'h', pragmaFrag: 'Fragment' } })
  vm.createContext(context)
  vm.runInContext(result.code, context)
  return () => { cursor = 0; return context.Page() }
}

function walk(node, predicate) {
  if (!node || typeof node !== 'object') return null
  if (predicate(node)) return node
  for (const child of [node.props?.children].flat(Infinity)) { const found = walk(child, predicate); if (found) return found }
  return null
}
function text(node) {
  if (node == null || typeof node === 'boolean') return ''
  if (typeof node !== 'object') return String(node)
  if (Array.isArray(node)) return node.map(text).join(' ')
  return [node.props?.children, node.props?.body].map(text).join(' ')
}

test('registration explains initial custody before submission and keeps the QR secondary to opening the folder', async () => {
  const render = await registration()
  const form = render()
  assert.match(text(form), /Register to record IN at your office and create its tracking ID and QR label/)
  assert.match(text(walk(form, node => node.type === 'button' && node.props.type === 'submit')), /Register folder/)
  assert.doesNotMatch(text(form), /Register folder & get QR/)
  const recovery = walk(form, node => node.type === 'CreationRecovery')
  recovery.props.onRecovered({ document: { id: 'DOC-2026-000001', title: 'Recovered folder', initial_in_recorded: true, qr_payload: 'synthetic-label', current_status: 'OUT', current_office_name: 'Another office', tray: 'forwarded' } })
  const success = render()
  assert.match(text(success), /Initial IN recorded at Engineering Office during registration\. No extra scan is needed for registration\./)
  const summary = walk(success, node => node.type === 'DocumentSummary').props.document
  assert.equal(summary.current_status, undefined, 'creation evidence must not become a claim about current custody')
  assert.equal(summary.current_office_name, undefined)
  assert.equal(summary.tray, undefined)
  const open = walk(success, node => node.type === 'Link' && node.props.to === '/documents?id=DOC-2026-000001')
  assert.equal(open.props.className, 'btn as-link')
  assert.match(text(open), /Open folder/)
  assert.match(text(success), /Print \/ Save QR label/)
  assert.match(text(success), /Forward \(OUT\) and choose the receiving office/)
  assert.match(text(success), /Receiving office opens Incoming and confirms receipt \(IN\)/)
  assert.equal(walk(success, node => node.type === 'Link' && node.props.to === '/scan'), null)
})

test('a saved response without explicit initial-IN evidence asks for custody verification without claiming an IN', async () => {
  for (const value of [false, undefined, 'true']) {
    const render = await registration()
    walk(render(), node => node.type === 'CreationRecovery').props.onRecovered({ document: { id: 'DOC-2026-000002', title: 'Legacy recovered folder', ...(value !== undefined ? { initial_in_recorded: value } : {}) } })
    const success = render()
    assert.match(text(success), /Folder saved\. Open the folder to verify its current custody before the next handoff\./)
    assert.doesNotMatch(text(success), /Initial IN recorded|No extra scan is needed/)
    assert.equal(walk(success, node => node.type === 'DocumentSummary').props.document.current_status, undefined)
    assert.ok(walk(success, node => node.type === 'Link' && node.props.to === '/documents?id=DOC-2026-000002'))
  }
})
