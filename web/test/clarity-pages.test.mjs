import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { AlertsContent } = await server.ssrLoadModule('/src/pages/AlertsPage.jsx')
const { HistoryTimeline } = await server.ssrLoadModule('/src/pages/HistoryPage.jsx')
const { default: DocumentSummary } = await server.ssrLoadModule('/src/components/DocumentSummary.jsx')
const render = (Component, props) => renderToStaticMarkup(React.createElement(Component, props))
const alertProps = { user: { role: 'admin' }, loading: false, filter: 'all', onFilter() {}, onRetry() {}, onOpen() {} }

test('failed first alert read is unavailable with retry, never an empty all-clear', () => {
  const html = render(AlertsContent, { ...alertProps, alerts: null, error: 'Connection interrupted' })
  assert.match(html, /Alerts unavailable/)
  assert.match(html, /Connection interrupted/)
  assert.match(html, /Retry alerts/)
  assert.doesNotMatch(html, /No alerts right now|No alerts in this filter/)
})

test('failed alert refresh retains records and marks them stale, including a previously empty snapshot', () => {
  const record = { document_id: 'DOC-2026-000001', document_title: 'Road works', kind: 'delayed', last_office_name: 'Accounting Office', last_status: 'IN', detail: 'Document due date passed (Oct 12, 2026)' }
  const html = render(AlertsContent, { ...alertProps, alerts: [record], error: 'Connection lost' })
  assert.match(html, /Refresh failed/)
  assert.match(html, /Showing previously loaded alerts; they may be out of date/)
  assert.match(html, /Road works/)
  assert.match(html, /Document due date passed/)
  const empty = render(AlertsContent, { ...alertProps, alerts: [], error: 'Connection lost' })
  assert.match(empty, /Current alert status could not be verified/)
  assert.doesNotMatch(empty, /No alerts right now/)
  const verified = render(AlertsContent, { ...alertProps, alerts: [], error: '' })
  assert.match(verified, /No alerts right now/)
})

test('sent alerts describe missing receipt and keep the server deadline evidence', () => {
  const outgoing = { document_id: 'DOC-2026-000002', document_title: 'Sent folder', kind: 'unconfirmed', last_office_name: 'Budget Office', last_status: 'OUT', days_pending: 3 }
  const html = render(AlertsContent, { ...alertProps, alerts: [outgoing], error: '' })
  assert.match(html, /Sent from Budget Office/)
  assert.match(html, /3 days since sent; receipt not recorded/)
  assert.doesNotMatch(html, /at this desk|3 days at this office|No IN scan/)
  const detailed = render(AlertsContent, { ...alertProps, alerts: [{ ...outgoing, detail: 'Marked OUT · no receive scan after 24h (due Oct 13, 2026)' }], error: '' })
  assert.match(detailed, /Sent · receipt not recorded after 24h \(due Oct 13, 2026\)/)
})

test('simplified history retains chronological registration, request, movement and full correction reasons', () => {
  const reason = 'Corrected the receiving office recorded in error.\nThe physical folder has not been received.'
  const document = { registered_by: { name: 'Sample registrar', office_name: 'Engineering', registered_at: '2026-10-01 08:00:00' }, linked_requests: [{ id: 7, purpose: 'Complete supporting schedules for the municipal access road', user_name: 'Sample requester', office_name: 'Budget', created_at: '2026-10-01 07:30:00' }] }
  const movements = [{ id: 3, status: 'OUT', office_name: 'Engineering', destination_office_name: 'Accounting', user_name: 'Sample sender', scanned_at: '2026-10-01 09:00:00', remarks: 'Hold all signed supporting pages together.', destination_corrections: [{ id: 1, previous_destination_office_name: 'Budget', destination_office_name: 'Accounting', corrected_at: '2026-10-01 09:05:00', corrected_by_name: 'Sample sender', corrected_by_office_name: 'Engineering', reason }] }]
  const html = render(HistoryTimeline, { document, movements })
  assert.match(html, /Complete supporting schedules for the municipal access road/)
  assert.match(html, /Registered at Engineering/)
  assert.match(html, /Hold all signed supporting pages together\./)
  assert.match(html, /Destination corrected: Budget → Accounting/)
  assert.ok(html.includes(reason))
  assert.ok(html.indexOf('Complete supporting schedules') < html.indexOf('Registered at Engineering'))
  assert.ok(html.indexOf('Sent to Accounting') < html.indexOf('Destination corrected'))
})

test('folder summary keeps custody separate from deadline and retains actual content discrepancy evidence', () => {
  const document = { id: 'DOC-2026-000003', title: 'Engineering schedules', type: 'Others: Schedules', tray: 'forwarded', current_status: 'OUT', current_office_name: 'Engineering', destination_office_name: 'Budget', origin_office_name: 'Engineering', is_overdue: true, due_at_display: 'Oct 14, 2026', folder_inventory: { total_pages: 5, items: [] }, contents_status: 'discrepancy', current_contents_receipt: { total_pages: 3, reason: 'Two signed pages missing.', items: [{ id: 'main', name: 'Main document', registered_pages: 5, pages: 3 }] } }
  const html = render(DocumentSummary, { document })
  assert.match(html, /Forwarded/)
  assert.match(html, /Overdue/)
  assert.match(html, /Not recorded by the receiving office yet/)
  assert.match(html, /Contents discrepancy recorded/)
  assert.match(html, /5 registered pages · 3 last received/)
  assert.match(html, /Two signed pages missing\./)
  assert.doesNotMatch(html, /<button/)
  const completed = render(DocumentSummary, { document: { ...document, tray: 'completed' } })
  assert.doesNotMatch(completed, /Overdue|Past deadline/)
})
