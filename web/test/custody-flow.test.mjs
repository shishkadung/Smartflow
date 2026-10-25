import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'
import { handoffDestinations, preferredForwardDestination, recordConfirmedReceipt, requestReturnPath } from '../src/custody-actions.js'

test('cancelled or unconfirmed physical receipt never records a movement', async () => {
  let writes = 0
  const record = async () => { writes++ }
  for (const receipt of [null, undefined, { confirmed: false }, { confirmed: 'true' }]) {
    assert.equal(await recordConfirmedReceipt({ id: 'DOC-2026-000001' }, async () => receipt, record, { status: 'IN' }), null)
  }
  assert.equal(writes, 0)
})

test('one confirmed check submits actual counts with the captured custody guard', async () => {
  const doc = { id: 'DOC-2026-000001', last_movement_id: 12 }
  const contents = { confirmed: true, items: [{ id: 4, pages: 0 }], reason: 'Missing signed copy' }
  const body = { document_id: doc.id, status: 'IN', expected_movement_id: doc.last_movement_id, movement_source: 'system' }
  const writes = []
  const result = await recordConfirmedReceipt(doc, async shown => { assert.equal(shown, doc); return contents }, async value => { writes.push(value); return { message: 'Received' } }, body)
  assert.deepEqual(result, { message: 'Received' })
  assert.deepEqual(writes, [{ ...body, receipt_confirmed: true, contents_receipt: contents }])
  assert.equal(Object.hasOwn(body, 'receipt_confirmed'), false)
})

test('request return context accepts only the Requests route', () => {
  assert.equal(requestReturnPath('/requests?tab=outbox&filter=overdue&page=2&id=9'), '/requests?tab=outbox&filter=overdue&page=2&id=9')
  assert.equal(requestReturnPath('/requests'), '/requests')
  for (const path of ['https://example.test', '//example.test/requests', '/requests-other', '/documents?id=9', '/requests#other', undefined]) assert.equal(requestReturnPath(path), null)
})

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { default: FolderHandoff } = await server.ssrLoadModule('/src/components/FolderHandoff.jsx')
const offices = [{ id: 1, code: 'ENG', name: 'Engineering Office' }, { id: 2, code: 'BUD', name: 'Budget Office' }, { id: 3, code: 'ACC', name: 'Accounting Office' }, { id: 4, code: 'TRE', name: 'Treasury Office' }]
const user = { office_id: 3, office_code: 'ACC' }
const doc = { visited_office_codes: ['ENG', 'BUD', 'ACC'], suggested_forward: { office_id: 4 } }
const props = { document: doc, offices, user, destination: '4', isReturn: false, returnReason: '', disabled: false, onDestination() {}, onMode() {}, onReason() {}, onSend() {}, onFile() {} }
const render = changes => renderToStaticMarkup(React.createElement(FolderHandoff, { ...props, ...changes }))

test('shared handoff keeps suggested forward, previous-holder return and terminal Accounting rules', () => {
  assert.equal(preferredForwardDestination(doc, offices), '4')
  assert.deepEqual(handoffDestinations(doc, offices, user, false).map(office => office.code), ['ENG', 'BUD', 'TRE'])
  assert.deepEqual(handoffDestinations(doc, offices, user, true).map(office => office.code), ['ENG', 'BUD'])
  const terminal = { ...doc, can_return_to_accounting: true }
  assert.equal(preferredForwardDestination(terminal, offices), '3')
  assert.deepEqual(handoffDestinations(terminal, offices, { office_id: 4, office_code: 'TRE' }, false).map(office => office.code), ['ACC'])
  const html = render({ document: terminal, user: { office_id: 4, office_code: 'TRE' }, destination: '3' })
  assert.match(html, /Return to Accounting/)
  assert.doesNotMatch(html, /Return for correction|Reason for return/)
})

test('shared return needs a prior office and reason; busy and filing controls stay guarded', () => {
  const invalid = render({ isReturn: true, destination: '4', returnReason: 'Wrong receiving office' })
  assert.doesNotMatch(invalid, /value="4"/)
  assert.match(invalid, /disabled="">Return to office/)
  const short = render({ isReturn: true, destination: '2', returnReason: 'four' })
  assert.match(short, /disabled="">Return to Budget Office/)
  const valid = render({ isReturn: true, destination: '2', returnReason: 'Missing signature' })
  assert.match(valid, /type="button">Return to Budget Office/)
  const filing = render({ document: { ...doc, can_file: true }, disabled: true })
  assert.match(filing, /fieldset disabled=""/)
  assert.match(filing, /class="btn" type="button">File this folder/)
  assert.match(filing, /class="btn-secondary" type="button">Send to Treasury Office/)
  const modes = []
  const element = FolderHandoff({ ...props, disabled: true, onMode: value => modes.push(value) })
  element.props.children.find(child => child?.props?.options)?.props.onChange('return')
  assert.deepEqual(modes, [])
})

test('unavailable offices keep filing available and expose a retry before sending', () => {
  let retries = 0
  let files = 0
  const unavailable = { ...props, document: { ...doc, can_file: true }, offices: [], officeError: 'Connection interrupted', onRetryOffices() { retries++ }, onFile() { files++ } }
  const html = render(unavailable)
  assert.match(html, /Receiving offices unavailable\. Connection interrupted/)
  assert.match(html, /role="alert"/)
  assert.match(html, /class="btn-secondary"[^>]*>Retry receiving offices/)
  assert.match(html, /class="btn" type="button">File this folder/)
  assert.doesNotMatch(html, /fieldset disabled=/)
  assert.match(html, /disabled="">Send to office/)
  const element = FolderHandoff(unavailable)
  element.props.children[0].props.onClick()
  element.props.children.find(child => child?.props?.role === 'alert').props.children.find(child => child?.type === 'button').props.onClick()
  assert.equal(files, 1)
  assert.equal(retries, 1)
  const recovered = render({ ...unavailable, offices, officeError: '' })
  assert.doesNotMatch(recovered, /Receiving offices unavailable|Retry receiving offices/)
  assert.match(recovered, /class="btn-secondary" type="button">Send to Treasury Office/)
  const stale = render({ ...unavailable, offices })
  assert.match(stale, /disabled="">Send to Treasury Office/)
})
