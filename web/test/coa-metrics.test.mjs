import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { ReportFlowMetrics, ReportOfficeTotals, formatHours } = await server.ssrLoadModule('/src/pages/AdminReportsPage.jsx')
const render = (Component, props) => renderToStaticMarkup(React.createElement(Component, props))

const completion = { completed: 4, of: 12, percent: 33.3, basis: 'Completion counts folders whose trail was finished at the cutoff. It measures the physical trail, not financial approval or payment.' }
const processingTime = { average_hours: 4.9, forwarded_stays: 15, open_stays: 10, basis: 'Average time at an office covers forwarded folders only.' }

test('completion rate and average time at an office are shown with their counts and basis', () => {
  const html = render(ReportFlowMetrics, { data: { completion, processing_time: processingTime } })
  assert.match(html, /Completion and time at offices/)
  assert.match(html, /4 of 12 folders · 33\.3%/)
  assert.match(html, /4\.9 h before forwarding · 15 forwarded, 10 still at the office/)
  assert.match(html, /How these are counted/)
  assert.match(html, /not financial approval or payment/)
  assert.match(html, /covers forwarded folders only/)
})

test('an empty period shows no invented completion rate or average', () => {
  const html = render(ReportFlowMetrics, { data: { completion: { completed: 0, of: 0, percent: null, basis: '' }, processing_time: { average_hours: null, forwarded_stays: 0, open_stays: 0, basis: '' } } })
  assert.match(html, /No folders with activity in this period/)
  assert.match(html, /No folders were forwarded in this period/)
  assert.doesNotMatch(html, /NaN|0%|0 h/)
})

test('an API response without the new fields renders nothing and does not break the report', () => {
  assert.equal(render(ReportFlowMetrics, { data: null }), '')
  assert.equal(render(ReportFlowMetrics, { data: { totals: { documents_in_period: 3 } } }), '')
})

test('long stays are also expressed in days', () => {
  assert.equal(formatHours(4.9), '4.9 h')
  assert.equal(formatHours(47.9), '47.9 h')
  assert.equal(formatHours(60), '60 h (2.5 days)')
  assert.match(render(ReportFlowMetrics, { data: { processing_time: { average_hours: 72, forwarded_stays: 2, open_stays: 0, basis: '' } } }), /72 h \(3\.0 days\) before forwarding/)
})

test('office totals add the average time per office and keep the existing counts', () => {
  const data = { office_totals: [
    { office_id: 1, office_code: 'ENG', office_name: 'Engineering Office', docs_processed: 7, forwarded_stays: 4, open_stays: 2, avg_hours_at_office: 5 },
    { office_id: 2, office_code: 'HR', office_name: 'Human Resources', docs_processed: 3, forwarded_stays: 0, open_stays: 3, avg_hours_at_office: null },
    { office_id: 3, office_code: 'BUD', office_name: 'Budget Office', docs_processed: 2 },
  ] }
  const html = render(ReportOfficeTotals, { data, loading: false, periodNoun: 'month' })
  assert.match(html, /Engineering Office<\/strong><span class="muted">7 folders with activity · avg 5 h before forwarding/)
  assert.match(html, /3 folders with activity · none forwarded/)
  assert.match(html, /2 folders with activity<\/span>/, 'an older response keeps the original wording')
})
