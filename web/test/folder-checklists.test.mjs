import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'
import { transformWithOxc } from 'vite'
import { checklistsForType, inventoryDirty, inventoryFromChecklist, readChecklistAttachments } from '../src/folder-checklists.js'

// Office checklists on the web behave as on the phone: staff apply one (page counts stay blank, nothing confirmed),
// heads and administrators publish and archive, and a failed read is never shown as "no checklists".

const blank = () => ({ count_confirmed: false, items: [{ name: 'Main document', pages: '', required: true }] })
const rows = [
  { id: 1, name: 'Standard DV', document_type: 'Disbursement Voucher', items: [{ name: 'Obligation request', required: true }, { name: 'Receipts', required: false }] },
  { id: 2, name: 'Budget packet', document_type: 'Approved Budget', items: [{ name: 'Annual plan', required: true }] },
  { id: 3, name: 'Rush DV', document_type: 'Disbursement Voucher', items: [{ name: 'Memo', required: true }] },
]

test('only the checklists of the chosen document type are offered, in the server order', () => {
  assert.deepEqual(checklistsForType(rows, 'Disbursement Voucher').map(row => row.name), ['Standard DV', 'Rush DV'])
  assert.deepEqual(checklistsForType(rows, 'Others'), [])
  assert.deepEqual(checklistsForType(undefined, 'Others'), [])
})

test('applying a checklist keeps names and required flags, blanks every page count and confirms nothing', () => {
  assert.deepEqual(inventoryFromChecklist(rows[0]), {
    count_confirmed: false,
    items: [
      { name: 'Main document', pages: '', required: true },
      { name: 'Obligation request', pages: '', required: true },
      { name: 'Receipts', pages: '', required: false },
    ],
  })
  assert.equal(inventoryFromChecklist({ items: Array.from({ length: 30 }, (_, i) => ({ name: `A${i}`, required: true })) }).items.length, 21)
  assert.deepEqual(inventoryFromChecklist({}).items, [{ name: 'Main document', pages: '', required: true }])
  assert.equal(inventoryFromChecklist({ items: [{ name: 'X', required: 'yes' }] }).items[1].required, false, 'only true means required')
})

test('the contents form is dirty once it has an attachment, a page count or the confirmation', () => {
  assert.equal(inventoryDirty(blank()), false)
  assert.equal(inventoryDirty({ ...blank(), count_confirmed: true }), true)
  assert.equal(inventoryDirty({ count_confirmed: false, items: [{ name: 'Main document', pages: '3', required: true }] }), true)
  assert.equal(inventoryDirty({ count_confirmed: false, items: [{ name: 'Main document', pages: '', required: true }, { name: '', pages: '', required: true }] }), true)
  assert.equal(inventoryDirty(undefined), false)
})

test('publishing needs at least one attachment, each with its own name', () => {
  assert.deepEqual(readChecklistAttachments(blank()), { error: 'Add at least one attachment before publishing.' })
  const form = items => ({ count_confirmed: false, items: [{ name: 'Main document', pages: '', required: true }, ...items] })
  const distinct = 'Give each attachment a distinct name (up to 100 characters).'
  assert.deepEqual(readChecklistAttachments(form([{ name: '  ', pages: '', required: true }])), { error: distinct })
  assert.deepEqual(readChecklistAttachments(form([{ name: 'Receipts', pages: '', required: true }, { name: ' receipts ', pages: '', required: false }])), { error: distinct })
  assert.deepEqual(readChecklistAttachments(form([{ name: 'main DOCUMENT', pages: '', required: true }])), { error: distinct })
  assert.deepEqual(readChecklistAttachments(form([{ name: 'x'.repeat(101), pages: '', required: true }])), { error: distinct })
  assert.deepEqual(readChecklistAttachments(form([{ name: ' Receipts ', pages: '9', required: true }, { name: 'Memo', pages: '', required: false }])), {
    items: [{ name: 'Receipts', required: true }, { name: 'Memo', required: false }],
  }, 'names are trimmed and no page count is published')
})

// ---- the component, run with synthetic reads and writes (no HTTP) ----
async function checklistPanel(auth) {
  const source = await readFile(new URL('../src/components/FolderChecklists.jsx', import.meta.url), 'utf8')
  const slots = [], pending = []
  let cursor = 0
  const sameDeps = (a, b) => a && b && a.length === b.length && a.every((value, i) => Object.is(value, b[i]))
  const useState = initial => {
    const at = cursor++
    if (!(at in slots)) slots[at] = typeof initial === 'function' ? initial() : initial
    return [slots[at], value => { slots[at] = typeof value === 'function' ? value(slots[at]) : value }]
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
    Array, String, Boolean, Object, Number,
    h: (type, props, ...children) => ({ type, props: { ...props, children } }), Fragment: 'Fragment',
    useState, useEffect, useAuth: () => auth,
    checklistsForType, inventoryDirty, inventoryFromChecklist, readChecklistAttachments, CHECKLIST_NAME_MAX: 100,
  }
  for (const line of source.matchAll(/^import \{([^}]+)\} from /gm)) for (const entry of line[1].split(',').map(value => value.trim())) if (!(entry in context)) context[entry] = entry
  for (const line of source.matchAll(/^import (\w+) from /gm)) if (!(line[1] in context)) context[line[1]] = line[1]
  const local = source.replace(/^import .*\r?\n/gm, '').replace(/export default function /, 'function ')
  const transformed = await transformWithOxc(`${local}\nglobalThis.Page=FolderChecklists`, 'FolderChecklists.jsx', { jsx: { runtime: 'classic', pragma: 'h', pragmaFrag: 'Fragment' } })
  vm.createContext(context)
  vm.runInContext(transformed.code, context)
  return {
    render(props) { cursor = 0; return context.Page(props) },
    async settle() { while (pending.length) pending.shift()(); for (let i = 0; i < 12; i++) await Promise.resolve() },
  }
}
function walk(node, predicate) {
  if (!node || typeof node !== 'object') return null
  if (predicate(node)) return node
  for (const child of [node.props?.children, node.props?.footer].flat(Infinity)) { const found = walk(child, predicate); if (found) return found }
  return null
}
function text(node) {
  if (node == null || typeof node === 'boolean') return ''
  if (typeof node !== 'object') return String(node)
  if (Array.isArray(node)) return node.map(text).join('')
  return [node.props?.children].map(text).join('')
}
const button = (tree, label) => walk(tree, node => node.type === 'button' && text(node).trim() === label)
const buttonByName = (tree, name) => walk(tree, node => node.type === 'button' && node.props['aria-label'] === name)
const modal = (tree, title) => walk(tree, node => node.type === 'Modal' && node.props.title === title)
const staff = { role: 'staff' }
const head = { role: 'head' }

test('staff see the published checklists of the type, and applying one on a blank form needs no confirmation', async () => {
  let applied = null
  const panel = await checklistPanel({ user: staff, smartflow: { folderChecklists: async () => ({ checklists: rows }) } })
  const props = { type: 'Disbursement Voucher', inventory: blank(), onApply: value => { applied = value } }
  panel.render(props); await panel.settle()
  const tree = panel.render(props)
  assert.match(text(tree), /Office checklist/)
  assert.ok(button(tree, 'Use Standard DV') && button(tree, 'Use Rush DV'))
  assert.equal(button(tree, 'Use Budget packet'), null, 'another document type')
  assert.equal(button(tree, 'Publish attachments as checklist'), null, 'staff do not publish')
  assert.equal(buttonByName(tree, 'Archive Standard DV'), null, 'staff do not archive')
  button(tree, 'Use Standard DV').props.onClick()
  assert.deepEqual(applied, inventoryFromChecklist(rows[0]))
})

test('applying over a filled form asks first, and Cancel leaves the form alone', async () => {
  const applied = []
  const panel = await checklistPanel({ user: staff, smartflow: { folderChecklists: async () => ({ checklists: rows }) } })
  const props = { type: 'Disbursement Voucher', inventory: { count_confirmed: true, items: [{ name: 'Main document', pages: '12', required: true }] }, onApply: value => applied.push(value) }
  panel.render(props); await panel.settle()
  button(panel.render(props), 'Use Standard DV').props.onClick()
  let tree = panel.render(props)
  const dialog = modal(tree, 'Replace the contents checklist?')
  assert.equal(dialog.props.open, true)
  assert.match(text(dialog), /clears all page counts and physical confirmation/)
  assert.deepEqual(applied, [])
  button(dialog.props.footer, 'Cancel').props.onClick()
  tree = panel.render(props)
  assert.equal(modal(tree, 'Replace the contents checklist?').props.open, false)
  assert.deepEqual(applied, [])
  button(tree, 'Use Standard DV').props.onClick()
  button(modal(panel.render(props), 'Replace the contents checklist?').props.footer, 'Replace').props.onClick()
  assert.deepEqual(applied, [inventoryFromChecklist(rows[0])])
})

test('a failed first read is unavailable with Retry, never "no checklist", and Retry recovers', async () => {
  let reads = 0
  const panel = await checklistPanel({ user: staff, smartflow: { folderChecklists: async () => { if (++reads === 1) throw new Error('Offline'); return { checklists: rows } } } })
  const props = { type: 'Disbursement Voucher', inventory: blank(), onApply() {} }
  panel.render(props); await panel.settle()
  let tree = panel.render(props)
  assert.match(text(tree), /Checklists unavailable\. Offline/)
  assert.doesNotMatch(text(tree), /No published checklist/)
  assert.equal(button(tree, 'Use Standard DV'), null)
  button(tree, 'Retry').props.onClick()
  tree = panel.render(props); await panel.settle()
  tree = panel.render(props)
  assert.doesNotMatch(text(tree), /unavailable/)
  assert.ok(button(tree, 'Use Standard DV'))
})

test('a failed refresh keeps the last checklists marked out of date and blocks using them', async () => {
  let reads = 0
  const panel = await checklistPanel({ user: staff, smartflow: { folderChecklists: async () => { if (++reads === 2) throw new Error('Timed out'); return { checklists: rows } } } })
  const props = { type: 'Disbursement Voucher', inventory: blank(), onApply() { assert.fail('stale checklists must not be applied') } }
  panel.render(props); await panel.settle()
  button(panel.render(props), 'Use Standard DV')
  buttonByName(panel.render(props), 'Refresh checklists').props.onClick()
  panel.render(props); await panel.settle()
  const tree = panel.render(props)
  assert.match(text(tree), /Refresh failed\. Showing the last loaded checklists, which may be out of date\. Timed out/)
  assert.equal(button(tree, 'Use Standard DV').props.disabled, true)
})

test('a read that succeeded with none for the type says so', async () => {
  const panel = await checklistPanel({ user: staff, smartflow: { folderChecklists: async () => ({ checklists: rows }) } })
  const props = { type: 'Others', inventory: blank(), onApply() {} }
  panel.render(props); await panel.settle()
  assert.match(text(panel.render(props)), /No published checklist\. Enter your office’s approved requirements below\./)
  const manager = await checklistPanel({ user: head, smartflow: { folderChecklists: async () => ({ checklists: rows }) } })
  const managing = { ...props, management: true }
  manager.render(managing); await manager.settle()
  assert.match(text(manager.render(managing)), /No published checklist for this document type\. Define approved attachment requirements below\./)
})

test('a head publishes the attachments as a named checklist, then the list is read again', async () => {
  const saved = []
  let reads = 0
  const panel = await checklistPanel({ user: head, smartflow: { folderChecklists: async () => { reads++; return { checklists: rows } }, saveFolderChecklist: async body => { saved.push(body); return { success: true, id: 9 } } } })
  const draft = { count_confirmed: false, items: [{ name: 'Main document', pages: '', required: true }, { name: ' Memo ', pages: '', required: true }, { name: 'Receipts', pages: '', required: false }] }
  const props = { type: 'Disbursement Voucher', inventory: draft, onApply() {}, management: true }
  panel.render(props); await panel.settle()
  button(panel.render(props), 'Publish attachments as checklist').props.onClick()
  const dialog = modal(panel.render(props), 'Publish office checklist')
  assert.equal(dialog.props.open, true)
  assert.match(text(dialog), /Publish only requirements approved by your office\. Page counts will stay blank when staff apply this checklist\./)
  const form = walk(dialog, node => node.type === 'form')
  const field = walk(form, node => node.type === 'input')
  field.props.onChange({ target: { value: '  Standard DV v2 ' } })
  const submit = modal(panel.render(props), 'Publish office checklist')
  walk(submit, node => node.type === 'form').props.onSubmit({ preventDefault() {} })
  await panel.settle()
  assert.deepEqual(JSON.parse(JSON.stringify(saved)), [{ name: 'Standard DV v2', document_type: 'Disbursement Voucher', items: [{ name: 'Memo', required: true }, { name: 'Receipts', required: false }] }])
  panel.render(props); await panel.settle()
  assert.equal(reads, 2, 'the published list was read again')
})

test('publishing is refused before any request when there is nothing to publish', async () => {
  const panel = await checklistPanel({ user: head, smartflow: { folderChecklists: async () => ({ checklists: [] }), saveFolderChecklist: async () => assert.fail('nothing should be sent') } })
  const props = { type: 'Disbursement Voucher', inventory: blank(), onApply() {}, management: true }
  panel.render(props); await panel.settle()
  button(panel.render(props), 'Publish attachments as checklist').props.onClick()
  const tree = panel.render(props)
  assert.match(text(tree), /Add at least one attachment before publishing\./)
  assert.equal(modal(tree, 'Publish office checklist').props.open, false)
})

test('a failed publish shows its error, is not retried, and leaves the draft', async () => {
  let writes = 0
  const panel = await checklistPanel({ user: head, smartflow: { folderChecklists: async () => ({ checklists: [] }), saveFolderChecklist: async () => { writes++; throw new Error('Only your office head can publish') } } })
  const draft = { count_confirmed: false, items: [{ name: 'Main document', pages: '', required: true }, { name: 'Memo', pages: '', required: true }] }
  const props = { type: 'Disbursement Voucher', inventory: draft, onApply() {}, management: true }
  panel.render(props); await panel.settle()
  button(panel.render(props), 'Publish attachments as checklist').props.onClick()
  walk(modal(panel.render(props), 'Publish office checklist'), node => node.type === 'input').props.onChange({ target: { value: 'Memo list' } })
  walk(modal(panel.render(props), 'Publish office checklist'), node => node.type === 'form').props.onSubmit({ preventDefault() {} })
  await panel.settle()
  const tree = panel.render(props)
  assert.equal(writes, 1)
  assert.match(text(tree), /Only your office head can publish/)
  assert.equal(button(tree, 'Publish attachments as checklist').props.disabled, false)
})

test('archiving asks first, then sends the archive and reads the list again', async () => {
  const sent = []
  let reads = 0
  const panel = await checklistPanel({ user: head, smartflow: { folderChecklists: async () => { reads++; return { checklists: rows } }, saveFolderChecklist: async body => { sent.push(body); return { success: true } } } })
  const props = { type: 'Disbursement Voucher', inventory: blank(), onApply() {}, management: true }
  panel.render(props); await panel.settle()
  buttonByName(panel.render(props), 'Archive Standard DV').props.onClick()
  const dialog = modal(panel.render(props), 'Archive Standard DV?')
  assert.equal(dialog.props.open, true)
  assert.match(text(dialog), /Existing registered inventories stay unchanged\./)
  assert.deepEqual(sent, [])
  button(dialog.props.footer, 'Archive').props.onClick()
  await panel.settle()
  assert.deepEqual(JSON.parse(JSON.stringify(sent)), [{ action: 'archive', id: 1 }])
  panel.render(props); await panel.settle()
  assert.equal(reads, 2)
})
