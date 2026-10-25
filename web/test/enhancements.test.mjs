import { test } from 'node:test'
import assert from 'node:assert/strict'
import { documentQueue } from '../src/document-queue.js'
import { connectionSnapshot, portalFetch } from '../src/connection.js'
import { apiText } from '../src/api.js'
import { movementDestination, reportPeriodBounds } from '../src/tracking.js'

const documents = [
  { id: 'C', title: 'Later folder', tray: 'in_office', is_overdue: false, due_at: '2026-10-04', hours_waiting: 6, last_scanned_at: '2026-10-03' },
  { id: 'A', title: 'First folder', tray: 'incoming', is_overdue: true, due_at: '2026-10-01', hours_waiting: 40, reference_no: 'ABC', last_scanned_at: '2026-10-01' },
  { id: 'B', title: 'Second folder', tray: 'incoming', is_overdue: true, due_at: '2026-10-02', hours_waiting: 50, last_scanned_at: '2026-09-30' },
  { id: 'D', title: 'Filed folder', tray: 'completed', is_overdue: false, hours_waiting: 100 },
]
test('queue urgency, wait, newest, search and overdue across open trays', () => {
  const ids = options => documentQueue(documents, options).map(d => d.id)
  assert.deepEqual(ids({ tray: 'incoming' }), ['A', 'B'])
  assert.deepEqual(ids({ tray: 'incoming', sort: 'waiting' }), ['B', 'A'])
  assert.deepEqual(ids({ tray: 'incoming', sort: 'recent' }), ['A', 'B'])
  assert.deepEqual(ids({ tray: 'in_office', overdueOnly: true }), ['A', 'B'])
  assert.deepEqual(ids({ tray: 'incoming', search: 'abc' }), ['A'])
  assert.deepEqual(documents.map(d => d.id), ['C', 'A', 'B', 'D'])
})
test('municipal office drilldowns keep only the selected current holder and overdue records', () => {
  const records = documents.map((doc, index) => ({ ...doc, current_office_id: index % 2 === 0 ? 1 : 2 }))
  assert.deepEqual(documentQueue(records, { tray: 'in_office', officeId: '1' }).map(doc => doc.id), ['C'])
  assert.deepEqual(documentQueue(records, { tray: 'in_office', officeId: '2', overdueOnly: true }).map(doc => doc.id), ['A'])
  assert.equal(documentQueue(records, { tray: 'in_office', officeId: '99' }).length, 0)
})
test('scan and document sends validate the same destination and correction reason', () => {
  assert.deepEqual(movementDestination({ destinationOfficeId: '2' }), { destination_office_id: 2 })
  assert.deepEqual(movementDestination({ destinationOfficeId: 2, isReturn: true, returnReason: '  Missing signed schedule  ' }),
    { destination_office_id: 2, is_return: true, remarks: 'Missing signed schedule' })
  for (const destinationOfficeId of ['', 0, -1, '2.5', 'wrong']) assert.throws(() => movementDestination({ destinationOfficeId }), /receiving office/)
  for (const returnReason of ['', 'four', 'x'.repeat(201)]) assert.throws(() => movementDestination({ destinationOfficeId: 2, isReturn: true, returnReason }), /return reason/)
})
test('all report pickers share fifteen calendar years and exclude future periods', () => {
  const bounds = reportPeriodBounds(new Date(2026, 9, 14))
  assert.equal(bounds.minYear, 2012)
  assert.equal(bounds.maxYear, 2026)
  assert.equal(bounds.minMonth, '2012-01')
  assert.equal(bounds.maxMonth, '2026-10')
  assert.equal(bounds.quarters[0], '2026-Q4')
  assert.equal(bounds.quarters.at(-1), '2012-Q1')
  assert.equal(bounds.quarters.length, 60)
  assert.equal(reportPeriodBounds(new Date(2026, 0, 1)).quarters[0], '2026-Q1')
})
test('transport failure retains last contact and never retries a write', async () => {
  let calls = 0
  globalThis.fetch = async () => { calls++; return new Response('{}', { status: 200 }) }
  await portalFetch('/okay')
  const lastContact = connectionSnapshot().lastSuccess
  globalThis.fetch = async () => { calls++; throw new TypeError('Failed to fetch') }
  await assert.rejects(portalFetch('/move', { method: 'POST' }), /check whether the action was recorded/)
  assert.equal(calls, 2)
  assert.equal(connectionSnapshot().unavailable, true)
  assert.equal(connectionSnapshot().lastSuccess, lastContact)
  globalThis.fetch = async () => new Response('Unavailable', { status: 503 })
  await portalFetch('/503')
  assert.equal(connectionSnapshot().unavailable, true)
  globalThis.fetch = async () => new Response('{}', { status: 200 })
  await portalFetch('/restored')
  assert.equal(connectionSnapshot().unavailable, false)
})
test('report text carries authentication and rejects failed exports', async () => {
  globalThis.localStorage = { getItem: () => 'fixture-token' }
  globalThis.window = { dispatchEvent() {} }
  globalThis.CustomEvent = class { constructor(type) { this.type = type } }
  globalThis.fetch = async (url, options) => {
    assert.match(url, /format=csv/)
    assert.equal(options.headers.Authorization, 'Bearer fixture-token')
    return new Response('\uFEFFPeriod,October\r\n', { status: 200 })
  }
  assert.match(await apiText('reports-summary.php', { format: 'csv' }), /Period,October/)
  globalThis.fetch = async () => new Response('{"message":"Accounting only"}', { status: 403 })
  await assert.rejects(apiText('reports-summary.php', { format: 'csv' }), /Accounting only/)
})
