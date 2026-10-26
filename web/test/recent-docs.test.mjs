import { after, beforeEach, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'
import { clearRecentDocs, loadRecentDocs, readClipboardText, recentChipLabel, recentDocsKey, rememberRecentDoc } from '../src/recent-docs.js'

// Scan and History on the web keep the same five recent folders and a Paste button, like the phone.

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { default: QuickOpen } = await server.ssrLoadModule('/src/components/QuickOpen.jsx')

function fakeStorage() {
  const data = new Map()
  return { data, getItem: key => (data.has(key) ? data.get(key) : null), setItem: (key, value) => { data.set(key, String(value)) }, removeItem: key => { data.delete(key) } }
}
let store
beforeEach(() => {
  store = fakeStorage()
  globalThis.window = { localStorage: store }
})

test('a chip reads 000003 · name, or the whole ID when the name is not known', () => {
  assert.equal(recentChipLabel({ id: 'DOC-2026-000003', title: 'DV – Road Repair' }), '000003 · DV – Road Repair')
  assert.equal(recentChipLabel({ id: 'DOC-2026-000003', title: '   ' }), 'DOC-2026-000003')
  assert.equal(recentChipLabel({ id: 'DOC-2026-000003' }), 'DOC-2026-000003')
})

test('the newest folder comes first, a repeat moves up without a copy, and only five are kept', () => {
  for (let i = 1; i <= 6; i++) rememberRecentDoc(1, `DOC-2026-00000${i}`, `Folder ${i}`)
  assert.deepEqual(loadRecentDocs(1).map(entry => entry.id), ['DOC-2026-000006', 'DOC-2026-000005', 'DOC-2026-000004', 'DOC-2026-000003', 'DOC-2026-000002'])
  const list = rememberRecentDoc(1, 'DOC-2026-000003', 'Folder 3')
  assert.deepEqual(list.map(entry => entry.id), ['DOC-2026-000003', 'DOC-2026-000006', 'DOC-2026-000005', 'DOC-2026-000004', 'DOC-2026-000002'])
})

test('a lookup that has no name keeps the name already known', () => {
  rememberRecentDoc(1, 'DOC-2026-000001', 'Road Repair')
  assert.equal(rememberRecentDoc(1, 'DOC-2026-000001', '')[0].title, 'Road Repair')
  assert.equal(rememberRecentDoc(1, 'DOC-2026-000001', 'Road Repair Phase 2')[0].title, 'Road Repair Phase 2')
})

test('each account has its own list, and clearing one does not touch another', () => {
  rememberRecentDoc(1, 'DOC-2026-000001', 'Mine')
  rememberRecentDoc(2, 'DOC-2026-000002', 'Theirs')
  assert.notEqual(recentDocsKey(1), recentDocsKey(2))
  assert.deepEqual(loadRecentDocs(1).map(entry => entry.id), ['DOC-2026-000001'])
  assert.deepEqual(clearRecentDocs(1), [])
  assert.deepEqual(loadRecentDocs(1), [])
  assert.deepEqual(loadRecentDocs(2).map(entry => entry.id), ['DOC-2026-000002'])
})

test('damaged or missing storage reads as no recent folders, and never throws', () => {
  store.data.set(recentDocsKey(1), 'not json')
  assert.deepEqual(loadRecentDocs(1), [])
  store.data.set(recentDocsKey(1), JSON.stringify({ id: 'x' }))
  assert.deepEqual(loadRecentDocs(1), [])
  store.data.set(recentDocsKey(1), JSON.stringify([null, 3, { id: '' }, { id: 'DOC-2026-000009', title: 7 }]))
  assert.deepEqual(loadRecentDocs(1), [{ id: 'DOC-2026-000009', title: '' }])
  globalThis.window = { get localStorage() { throw new Error('blocked') } }
  assert.deepEqual(loadRecentDocs(1), [])
  assert.deepEqual(rememberRecentDoc(1, 'DOC-2026-000001', 'x').map(entry => entry.id), ['DOC-2026-000001'], 'the list still shows for this visit')
  assert.deepEqual(clearRecentDocs(1), [])
})

test('the clipboard gives text, says when it is empty, and says when it cannot be read', async () => {
  const set = value => Object.defineProperty(globalThis, 'navigator', { value, configurable: true })
  set({ clipboard: { readText: async () => '  DOC-2026-000001 \n' } })
  assert.deepEqual(await readClipboardText(), { text: 'DOC-2026-000001' })
  set({ clipboard: { readText: async () => '   ' } })
  assert.deepEqual(await readClipboardText(), { error: 'Clipboard is empty.' })
  set({ clipboard: { readText: async () => { throw new Error('denied') } } })
  assert.match((await readClipboardText()).error, /Could not read the clipboard/)
  set({})
  assert.match((await readClipboardText()).error, /Could not read the clipboard/)
})

test('Quick open lists the chips with Clear, and shows nothing when there is nothing to open', () => {
  const html = renderToStaticMarkup(React.createElement(QuickOpen, { docs: [{ id: 'DOC-2026-000003', title: 'DV – Road Repair' }, { id: 'DOC-2026-000004', title: '' }], onOpen() {}, onClear() {} }))
  assert.match(html, /Quick open/)
  assert.match(html, />Clear</)
  assert.match(html, />000003 · DV – Road Repair</)
  assert.match(html, />DOC-2026-000004</)
  assert.equal(renderToStaticMarkup(React.createElement(QuickOpen, { docs: [], onOpen() {}, onClear() {} })), '')
  assert.match(renderToStaticMarkup(React.createElement(QuickOpen, { docs: [{ id: 'DOC-2026-000003' }], disabled: true, onOpen() {}, onClear() {} })), /disabled=""/)
})

test('choosing a chip opens that folder', () => {
  let opened = ''
  const tree = QuickOpen({ docs: [{ id: 'DOC-2026-000003', title: 'x' }], onOpen: id => { opened = id }, onClear() {} })
  const find = node => {
    if (!React.isValidElement(node)) return null
    if (node.type === 'button' && node.props.className === 'quick-open__chip') return node
    return React.Children.toArray(node.props.children).map(find).find(Boolean) || null
  }
  find(tree).props.onClick()
  assert.equal(opened, 'DOC-2026-000003')
})
