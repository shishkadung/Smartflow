import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { default: DocumentList } = await server.ssrLoadModule('/src/components/DocumentList.jsx')
const documents = [
  { id: 'DOC-2026-000001', title: 'Signed municipal road rehabilitation schedules — END OF FULL TITLE', reference_no: 'ENG-2026-001', tray: 'incoming', current_status: 'OUT', current_office_name: 'Engineering Office', hours_waiting: 25, is_overdue: true, due_at_display: 'Oct 12, 2026 · 5:00 PM' },
  { id: 'DOC-2026-000002', title: 'Approved Budget', tray: 'forwarded', current_status: 'OUT', current_office_name: 'Accounting Office', destination_office_name: 'Treasury Office', hours_waiting: 0.5 },
  { id: 'DOC-2026-000003', title: 'Completed inspection report', tray: 'completed', current_status: 'IN', current_office_name: 'Treasury Office', hours_waiting: 96 },
]

function findElements(node, predicate) {
  const found = []
  function visit(element) {
    if (!React.isValidElement(element)) return
    if (predicate(element)) found.push(element)
    React.Children.forEach(element.props.children, visit)
  }
  visit(node)
  return found
}

test('document table retains custody, deadline, waiting and completed states alongside phone cards', () => {
  const html = renderToStaticMarkup(React.createElement(DocumentList, { documents, selected: documents[0].id, onSelect() {} }))
  assert.equal((html.match(/scope="col"/g) || []).length, 6)
  for (const text of ['Tracking ID', 'Deadline', 'END OF FULL TITLE', 'From Engineering Office', 'To Treasury Office', 'Awaiting receipt', '1d 1h', '30 min', 'Oct 12, 2026', 'Completed']) assert.ok(html.includes(text), text)
  assert.match(html, /<tr[^>]+aria-selected="true"/)
  assert.match(html, /mobile-document-list/)
})

test('native row button activates the correct folder for keyboard clicks without bubbling twice', () => {
  const selected = []
  const tree = DocumentList({ documents, selected: documents[0].id, onSelect: id => selected.push(id) })
  const button = findElements(tree, element => element.type === 'button' && element.props.className === 'document-table__select')[1]
  assert.equal(button.props.type, 'button')
  assert.equal(button.props['aria-controls'], 'document-details')
  assert.equal(button.props['aria-pressed'], false)
  let propagationStopped = false
  // Enter and Space activate a native button through click, with no pointer detail.
  button.props.onClick({ detail: 0, stopPropagation() { propagationStopped = true } })
  assert.equal(propagationStopped, true)
  assert.deepEqual(selected, [documents[1].id])
  const row = findElements(tree, element => element.type === 'tr' && element.props.onClick)[2]
  row.props.onClick()
  assert.deepEqual(selected, [documents[1].id, documents[2].id])
})

test('busy custody writes prevent selection through table rows, native buttons and phone cards', () => {
  const selected = []
  const tree = DocumentList({ documents, selected: documents[0].id, busy: true, onSelect: id => selected.push(id) })
  const buttons = findElements(tree, element => element.type === 'button')
  assert.equal(buttons.length, documents.length * 2)
  for (const button of buttons) {
    assert.equal(button.props.disabled, true)
    button.props.onClick({ stopPropagation() {} })
  }
  for (const row of findElements(tree, element => element.type === 'tr' && element.props.onClick)) row.props.onClick()
  assert.deepEqual(selected, [])
})
