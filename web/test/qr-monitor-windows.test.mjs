import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'

// The web QR monitor offers the same time windows, counts, review list and reject reasons as the phone one.

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { QrMonitorContent } = await server.ssrLoadModule('/src/pages/AdminQrMonitorPage.jsx')
const render = props => renderToStaticMarkup(React.createElement(MemoryRouter, null, React.createElement(QrMonitorContent, props)))
const callbacks = { onRetry() {}, onOutcome() {}, onHours() {}, onExport() {}, onOpen() {} }
const data = {
  rows: [{ id: 1, document_id: 'DOC-2026-000001', outcome: 'rejected', message: 'Wrong receiver', created_at: '2026-10-26 08:00:00' }],
  summary: { accepted: 3, rejected: 2, total: 5 },
  suspicious: [{ user_id: 7, user_name: 'Ana Reyes', username: 'ana_acc', office_code: 'ACC', reject_count: 4 }],
  topReasons: [{ code: 'WRONG_OFFICE', count: 3 }, { code: 'DUPLICATE', count: 1 }],
  exceptions: [],
  activity: [],
}
const props = { ...callbacks, data, error: '', loading: false, outcome: 'all', hours: 48 }

test('the monitor offers 24 hours, 48 hours and 7 days like the phone, with the chosen one selected', () => {
  for (const [hours, selected] of [[24, '24h'], [48, '48h'], [168, '7 days']]) {
    const html = render({ ...props, hours })
    for (const label of ['24h', '48h', '7 days']) assert.match(html, new RegExp(`>${label}<`))
    assert.match(html, new RegExp(`aria-selected="true" class="is-active">${selected}<`))
  }
})

test('choosing a window reports its hours', () => {
  const chosen = []
  const tree = QrMonitorContent({ ...props, onHours: hours => chosen.push(hours) })
  const find = node => {
    if (!React.isValidElement(node)) return null
    if (Array.isArray(node.props?.options) && node.props.options.some(option => option.label === '7 days')) return node
    return [node.props?.children, node.props?.actions].flatMap(child => React.Children.toArray(child)).map(find).find(Boolean) || null
  }
  const windows = find(tree)
  assert.deepEqual(windows.props.options.map(option => option.value), [24, 48, 168])
  windows.props.onChange(168)
  assert.deepEqual(chosen, [168])
})

test('the scan panel names the chosen window', () => {
  assert.match(render({ ...props, hours: 24 }), /Scan events · last (<!-- -->)?24 hours/)
  assert.match(render({ ...props, hours: 168 }), /Scan events · last (<!-- -->)?7 days/)
})

test('accepted and rejected counts, staff to review and top reject reasons are shown', () => {
  const html = render(props)
  assert.match(html, /<b>3<\/b><span>Accepted<\/span>/)
  assert.match(html, /<b>2<\/b><span>Rejected<\/span>/)
  assert.match(html, /Needs review/)
  assert.match(html, /Staff with 3\+ rejected scans in this window/)
  assert.match(html, /Ana Reyes/)
  assert.match(html, /Top reject reasons/)
  assert.match(html, /WRONG_OFFICE · 3/)
  assert.match(html, /DUPLICATE · 1/)
})

test('without verified data there are no counts, review list or reasons to claim', () => {
  const html = render({ ...props, data: null, error: 'Service unavailable' })
  assert.doesNotMatch(html, /Accepted<\/span>|Needs review|Top reject reasons/)
  assert.match(html, /QR monitor unavailable/)
})

test('a window with no scans points to a longer one, and shows no review list', () => {
  const html = render({ ...props, data: { ...data, rows: [], suspicious: [], topReasons: [], summary: { accepted: 0, rejected: 0, total: 0 } } })
  assert.match(html, /No scan events\. Try a longer time window/)
  assert.doesNotMatch(html, /Needs review|Top reject reasons/)
  assert.match(html, /<b>0<\/b><span>Accepted<\/span>/)
})
