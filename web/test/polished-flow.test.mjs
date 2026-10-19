import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createMemoryRouter, MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'
import { createdRequestNavigation, requestReturnPath, requestViewFromSearch } from '../src/request-navigation.js'
import { checkCreation } from '../src/creation-recovery.js'
import { recordConfirmedFiling, saveCustodyAndRefresh } from '../src/custody-actions.js'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { RequestDetails } = await server.ssrLoadModule('/src/pages/RequestsPage.jsx')
const { FolderFilingConfirmation } = await server.ssrLoadModule('/src/components/FolderFiling.jsx')
const { ScanCustodyRecovery } = await server.ssrLoadModule('/src/pages/ScanPage.jsx')
const render = (Component, props) => renderToStaticMarkup(React.createElement(MemoryRouter, null, React.createElement(Component, props)))
function findElement(node, predicate) {
  if (!React.isValidElement(node)) return undefined
  if (predicate(node)) return node
  return React.Children.toArray(node.props.children).map(child => findElement(child, predicate)).find(Boolean)
}

test('creation opens the returned exact ticket beyond Inbox and retained filters, with the previous committed view', async () => {
  for (const previous of ['/requests', '/requests?tab=outbox&filter=past&q=old+bridge&page=4&id=7', '/requests?filter=overdue&q=cost&page=2']) {
    const view = requestViewFromSearch(previous.split('?')[1])
    const target = createdRequestNavigation({ request: { id: 42 } }, view)
    const router = createMemoryRouter([{ path: '*', element: null }], { initialEntries: [previous] })
    try {
      await router.navigate(`/requests?${target.params}`, { state: target.state })
      assert.deepEqual(requestViewFromSearch(router.state.location.search), { tab: 'outbox', filter: 'active', q: '', page: 1, id: '42' })
      assert.equal(router.state.location.state.requestCreationReturnTo, requestReturnPath(view))
      await router.navigate(router.state.location.state.requestCreationReturnTo)
      assert.deepEqual(requestViewFromSearch(router.state.location.search), view)
    } finally { router.dispose() }
  }
  for (const id of [undefined, -1, 'NaN', '2e3']) assert.throws(() => createdRequestNavigation({ request: { id } }, {}), /Request saved/)
})

test('creation recovery opens the saved ticket without a second write', async () => {
  const originalStorage = globalThis.localStorage
  const saved = new Map([['sf_user', JSON.stringify({ id: 8, office_id: 3 })], ['sf_creation_v1_8_3_request', JSON.stringify({ id: 'a'.repeat(32), body: { purpose: 'Interrupted request' } })]])
  globalThis.localStorage = { getItem: key => saved.get(key) ?? null, removeItem: key => saved.delete(key) }
  try {
    const calls = []
    const outcome = await checkCreation('request', async (endpoint, options) => { calls.push({ endpoint, options }); return { state: 'recorded', result: { request: { id: 99 } } } })
    const target = createdRequestNavigation(outcome.result, requestViewFromSearch('tab=outbox&filter=past&q=old&page=3'))
    assert.equal(target.params.get('id'), '99')
    assert.equal(target.params.get('filter'), null)
    assert.equal(target.state.requestCreationReturnTo, '/requests?tab=outbox&filter=past&q=old&page=3')
    assert.equal(calls.length, 1)
    assert.equal(calls[0].options.method, undefined)
    assert.equal(saved.has('sf_creation_v1_8_3_request'), false)
  } finally { globalThis.localStorage = originalStorage }
})

test('created-ticket previous view survives its linked-folder navigation state', () => {
  const returnState = { requestCreationReturnTo: '/requests?filter=past&q=old&page=2&id=7' }
  const request = { id: 42, status: 'approved', requester: {}, handler_office: {}, related_document_id: 'DOC-2026-000042' }
  const tree = RequestDetails({ req: request, user: { role: 'staff', office_code: 'ENG' }, returnTo: '/requests?tab=outbox&id=42', returnState })
  const link = findElement(tree, node => node.props.to === '/documents?id=DOC-2026-000042')
  assert.deepEqual(link.props.state.requestReturnState, returnState)
  assert.equal(link.props.state.requestReturnTo, '/requests?tab=outbox&id=42')
})

test('cancelled filing never posts, and confirmation keeps the reviewed movement even if custody changes while open', async () => {
  const doc = { id: 'DOC-2026-000007', title: 'Inspection schedules', last_movement_id: 42 }
  const writes = []
  const file = async (...args) => { writes.push(args); return { message: 'Filed' } }
  assert.equal(await recordConfirmedFiling(doc, async () => false, file), null)
  assert.deepEqual(writes, [])
  await recordConfirmedFiling(doc, async snapshot => { assert.equal(snapshot.last_movement_id, 42); doc.last_movement_id = 99; return true }, file)
  assert.deepEqual(writes, [['DOC-2026-000007', 42]])
  for (const id of [undefined, 0, -1, 'NaN']) await assert.rejects(recordConfirmedFiling({ ...doc, last_movement_id: id }, async () => true, file), /Current movement unavailable/)
  assert.equal(writes.length, 1)
})

test('shared filing dialog explains completion and uses explicit confirm and cancel callbacks', () => {
  let confirmed = 0, cancelled = 0
  const props = { document: { id: 'DOC-2026-000007', title: 'Complete inspection folder' }, onConfirm() { confirmed++ }, onCancel() { cancelled++ } }
  const html = render(FolderFilingConfirmation, props)
  assert.match(html, /File this folder\?/)
  assert.match(html, /Complete inspection folder/)
  assert.match(html, /can no longer be sent to another office/)
  assert.match(html, /Completed/)
  assert.doesNotMatch(html, /checkbox|Check folder contents|Confirm receipt/)
  const dialog = FolderFilingConfirmation(props)
  findElement(dialog.props.footer, node => node.type === 'button' && node.props.children === 'Confirm filing').props.onClick()
  findElement(dialog.props.footer, node => node.type === 'button' && node.props.children === 'Cancel').props.onClick()
  assert.equal(confirmed, 1)
  assert.equal(cancelled, 1)
})

test('confirmed custody save survives a failed follow-up read and recovery only reads', async () => {
  const trace = []
  let message = '', readError = '', writes = 0, reads = 0
  const read = async () => { reads++; if (reads === 1) throw new Error('Details service unavailable'); return { document: { id: 'DOC-2026-000007', last_movement_id: 43, current_status: 'OUT' } } }
  const current = await saveCustodyAndRefresh(async () => { writes++; trace.push('write'); return { message: 'Sent successfully' } }, read, result => { message = result.message; trace.push('saved') }, error => { readError = error.message; trace.push('unverified') })
  assert.equal(current, null)
  assert.equal(message, 'Sent successfully')
  assert.equal(readError, 'Details service unavailable')
  assert.deepEqual(trace, ['write', 'saved', 'unverified'])
  assert.equal((await read()).document.last_movement_id, 43)
  assert.equal(writes, 1)
  assert.equal(reads, 2)
})

test('cancelled physical check and failed write never imply success or retry a write', async () => {
  let reads = 0, saved = 0, writes = 0
  const read = async () => { reads++; return { document: {} } }
  const onSaved = () => saved++
  assert.equal(await saveCustodyAndRefresh(async () => null, read, onSaved, () => assert.fail('cancel is not a read failure')), null)
  await assert.rejects(saveCustodyAndRefresh(async () => { writes++; throw new Error('Response was lost') }, read, onSaved, () => assert.fail('write error must remain separate')), /Response was lost/)
  assert.equal(reads, 0)
  assert.equal(saved, 0)
  assert.equal(writes, 1)
})

test('Scan recovery clearly separates saved action from unverified custody and exposes a read-only retry', () => {
  let retries = 0
  const props = { saved: true, error: 'Sample read failed', busy: false, onRetry() { retries++ } }
  const html = render(ScanCustodyRecovery, props)
  assert.match(html, /The action was saved/)
  assert.match(html, /displayed custody may be out of date/)
  assert.match(html, /Receive, Send, File and destination correction stay disabled/)
  assert.match(html, /Sample read failed/)
  findElement(ScanCustodyRecovery(props), node => node.type === 'button').props.onClick()
  assert.equal(retries, 1)
  const unknown = render(ScanCustodyRecovery, { ...props, saved: false, busy: true })
  assert.doesNotMatch(unknown, /The action was saved/)
  assert.match(unknown, /disabled=""[^>]*>Checking folder details/)
})
