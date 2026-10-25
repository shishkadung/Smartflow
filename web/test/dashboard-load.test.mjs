import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { HeadDashboardContent } = await server.ssrLoadModule('/src/pages/HeadHomePage.jsx')
const { AdminDashboardContent } = await server.ssrLoadModule('/src/pages/AdminHomePage.jsx')
const render = (Component, props) => renderToStaticMarkup(React.createElement(MemoryRouter, null,
  React.createElement(Component, { onRetry() {}, ...props })))

test('head queue labels completed and elsewhere-held folders with the server status, not "In office"', () => {
  const data = {
    stats: { in_office: 1, overdue: 0, avg_hours: 1 },
    queue: [
      { document_id: 'DOC-1', title: 'Filed folder', status_label: 'completed', status_pill: 'Completed', last_status: 'IN', meta: 'Trail complete', hours_pending: 5 },
      { document_id: 'DOC-2', title: 'Desk folder', status_label: 'in_office', status_pill: 'In office', last_status: 'IN', meta: '2h at ACC', hours_pending: 2 },
      { document_id: 'DOC-3', title: 'Elsewhere folder', status_label: 'on_time', status_pill: 'On time', last_status: 'IN', meta: 'At Budget Office', hours_pending: 3 },
    ],
  }
  const html = render(HeadDashboardContent, { error: '', loading: false, data })
  const pills = [...html.matchAll(/class="status-pill[^"]*">([^<]+)</g)].map((m) => m[1])
  assert.deepEqual(pills, ['Completed', 'On time', 'In office']) // default sort: longest wait first
})

for (const [role, Component] of [['head', HeadDashboardContent], ['admin', AdminDashboardContent]]) {
  test(`${role} failed dashboard exposes retry without fabricated counts or all-clear`, () => {
    const html = render(Component, { error: 'Cannot reach portal', loading: false, data: null })
    assert.match(html, /Dashboard unavailable/)
    assert.match(html, /Cannot reach portal/)
    assert.match(html, /Try again/)
    assert.doesNotMatch(html, /workspace-metrics|No documents in the office queue|Counts appear after an IN or OUT scan|On track/)
  })

  test(`${role} keeps last successful metrics but labels a failed refresh as stale`, () => {
    const data = { stats: { in_office: 4, overdue: 2, avg_hours: 3, active_documents: 4, pending_signups: 1 }, queue: [], office_totals: [] }
    const html = render(Component, { error: 'Connection lost', loading: false, data })
    assert.match(html, /Refresh failed/)
    assert.match(html, /Showing previously loaded data; counts may be out of date/)
    assert.match(html, /workspace-metrics/)
    assert.doesNotMatch(html, /No documents in the office queue|Counts appear after an IN or OUT scan/)
    const recovered = render(Component, { error: '', loading: false, data })
    assert.doesNotMatch(recovered, /Refresh failed|Dashboard unavailable/)
    assert.match(recovered, role === 'head' ? /No documents in the office queue/ : /Counts appear after an IN or OUT scan/)
  })
}
