import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'
import { custodyReportReturnPath } from '../src/report-navigation.js'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { default: DocumentJourney, FolderReceiptEvidence } = await server.ssrLoadModule('/src/components/DocumentJourney.jsx')
const { default: DocumentList } = await server.ssrLoadModule('/src/components/DocumentList.jsx')
const { default: HistoryPage, HistoryTimeline } = await server.ssrLoadModule('/src/pages/HistoryPage.jsx')
const { default: DocumentsPage } = await server.ssrLoadModule('/src/pages/DocumentsPage.jsx')
const { AuthProvider } = await server.ssrLoadModule('/src/auth.jsx')
const render = (Component, props) => renderToStaticMarkup(React.createElement(Component, props))
const firstReceipt = {
  registered_total_pages: 8, total_pages: 5, status: 'incomplete',
  reason: 'Three signed pages were missing.\nThe receiving clerk counted every item. END OF EARLIER REASON.',
  items: [
    { id: 'main', name: 'Main document', registered_pages: 3, pages: 3, required: true },
    { id: 'schedule', name: 'Signed supporting schedule', registered_pages: 3, pages: 2, required: true },
    { id: 'authority', name: 'Signed authority', registered_pages: 2, pages: 0, required: true },
  ],
}
const movements = [
  { id: 1, status: 'IN', office_name: 'Budget Office', user_name: 'First receiving clerk', scanned_at: '2026-10-01 08:00:00', contents_receipt: firstReceipt, remarks: 'Keep the original signed folder. END OF CLERK NOTE.' },
  { id: 2, status: 'OUT', office_name: 'Budget Office', destination_office_name: 'Accounting Office', user_name: 'Sending clerk', scanned_at: '2026-10-02 08:00:00' },
  { id: 3, status: 'IN', office_name: 'Accounting Office', user_name: 'Second receiving clerk', scanned_at: '2026-10-03 08:00:00', contents_receipt: { ...firstReceipt, total_pages: 8, status: 'complete', reason: '', items: firstReceipt.items.map(item => ({ ...item, pages: item.registered_pages })) }, is_current: true },
]

test('full History and the custody journey retain every receipt with its own counts and full notes', () => {
  for (const html of [
    render(HistoryTimeline, { document: { id: 'DOC-2026-000001' }, movements }),
    render(DocumentJourney, { document: { tray: 'in_office', current_status: 'IN', current_office_name: 'Accounting Office', journey: movements } }),
  ]) {
    for (const copy of ['8 registered pages · 5 received pages', '8 registered pages · 8 received pages', 'Receipt contents incomplete', 'Receipt contents checked complete', 'Signed supporting schedule: 3 registered → 2 received · 1 page missing', 'Signed authority: 2 registered → 0 received · 2 pages missing · required item missing', 'END OF CLERK NOTE.']) assert.ok(html.includes(copy), copy)
    assert.ok(html.includes(firstReceipt.reason), 'the full earlier discrepancy explanation survives a later complete receipt')
    assert.ok(html.indexOf('5 received pages') < html.indexOf('8 received pages'), 'receipt evidence stays chronological')
    assert.equal((html.match(/Receipt contents (?:incomplete|checked complete)/g) || []).length, 2, 'OUT does not invent a receipt')
  }
})

test('legacy receipts keep unknown counts distinct from recorded zero and retain extra-page evidence', () => {
  const missing = render(FolderReceiptEvidence, { receipt: null })
  assert.match(missing, /Contents not recorded for this receipt/)
  assert.doesNotMatch(missing, /0 received|checked complete/)
  const legacy = render(FolderReceiptEvidence, { receipt: { status: 'discrepancy', reason: 'An extra sheet arrived.', items: [{ id: 'main', name: 'Main document', registered_pages: 2, pages: 3 }, { id: 'unknown', name: 'Legacy attachment' }] } })
  for (const copy of ['Receipt contents discrepancy recorded', 'Page totals not recorded for this receipt.', '2 registered → 3 received · 1 extra page', 'Legacy attachment: received count not recorded', 'An extra sheet arrived.']) assert.ok(legacy.includes(copy), copy)
})

test('computed route completion does not fabricate filing evidence, while an explicit filing keeps its recorded event', () => {
  const doc = { id: 'DOC-2026-000001', title: 'Completed DV', tray: 'completed', trail_complete: true, current_office_name: 'Treasury Office', current_status: 'IN', journey: movements }
  assert.doesNotMatch(render(HistoryTimeline, { document: doc, movements }), /Filed/)
  const journey = render(DocumentJourney, { document: doc })
  assert.match(journey, /Journey complete/)
  assert.doesNotMatch(journey, /Filed|ongoing/)
  assert.doesNotMatch(render(DocumentList, { documents: [doc], onSelect() {} }), /Filed/)
  const explicit = render(HistoryTimeline, { document: { ...doc, filed_by: { filed_at: '2026-10-04 09:00:00', name: 'Filing clerk', office_name: 'Accounting Office' } }, movements })
  assert.match(explicit, /Filed at Accounting Office/)
  assert.match(explicit, /Filing clerk/)
  assert.ok(explicit.indexOf('Second receiving clerk') < explicit.indexOf('Filed at Accounting Office'))
})

test('History and exact Documents links return only to a sanitized local custody report', () => {
  const previous = Object.getOwnPropertyDescriptor(globalThis, 'localStorage')
  const sampleUser = { id: 9001, role: 'admin', office_id: 3, office_code: 'ACC', office_name: 'Accounting Office' }
  Object.defineProperty(globalThis, 'localStorage', { configurable: true, value: { getItem: key => key === 'sf_token' ? 'synthetic-report-navigation-only' : key === 'sf_user' ? JSON.stringify(sampleUser) : null } })
  try {
    for (const Component of [HistoryPage, DocumentsPage]) {
      for (const value of ['/admin/reports?period=month&month=2026-10&scope=outstanding&classification=delayed&q=signed+schedule&page=3', 'https://external.invalid/admin/reports', '//external.invalid/admin/reports', '/documents?id=DOC-2026-000002']) {
        const url = `/history?id=DOC-2026-000001&report_return=${encodeURIComponent(value)}`
        const html = renderToStaticMarkup(React.createElement(MemoryRouter, { initialEntries: [url] }, React.createElement(AuthProvider, null, React.createElement(Component))))
        const expected = custodyReportReturnPath(value)
        if (expected) {
          assert.match(html, /Back to custody report/)
          assert.ok(html.includes(`href="${expected.replaceAll('&', '&amp;')}"`))
          assert.ok(expected.includes('scope=outstanding') && expected.includes('page=3'), 'the report filter and page survive the round trip')
        } else assert.doesNotMatch(html, /Back to custody report/)
        assert.doesNotMatch(html, /href="(?:https:|\/\/external)/)
      }
    }
  } finally {
    if (previous) Object.defineProperty(globalThis, 'localStorage', previous)
    else delete globalThis.localStorage
  }
})
