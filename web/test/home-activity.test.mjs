import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'
import { movementListTime, movementScanSubtitle } from '../src/tracking.js'

// The web home pages show the same "today's activity", "office on track" and "updated" cues as the phone home pages.

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { HeadDashboardContent } = await server.ssrLoadModule('/src/pages/HeadHomePage.jsx')
const { HomeActivity, HomeUpdated } = await server.ssrLoadModule('/src/components/HomeWorkspace.jsx')
const render = (Component, props) => renderToStaticMarkup(React.createElement(MemoryRouter, null, React.createElement(Component, props)))

const now = new Date(2026, 9, 26, 15, 30)
const scan = { document_id: 'DOC-2026-000003', title: 'DV – Road Repair', status: 'OUT', scanned_at: '2026-10-26 14:14:00', destination_office_code: 'TRE', user_name: 'Ana Reyes' }

test('a row says the time, where it went and who scanned it, as the phone does', () => {
  assert.equal(movementListTime('2026-10-26 14:14:00', now), '2:14 PM')
  assert.equal(movementListTime('2026-10-24 09:05:00', now), 'Oct 24 · 9:05 AM')
  assert.equal(movementListTime('2026-09-01 09:05:00', now), 'Sep 1, 9:05 AM')
  assert.equal(movementListTime('', now), '—')
  assert.equal(movementListTime('not a date', now), 'not a date')
  assert.equal(movementScanSubtitle(scan, now), '2:14 PM · To TRE · Ana Reyes')
  assert.equal(movementScanSubtitle({ ...scan, status: 'IN', destination_office_code: null }, now), '2:14 PM · At your office · Ana Reyes')
  assert.equal(movementScanSubtitle({ status: 'OUT', scanned_at: '2026-10-26 08:00:00' }, now), '8:00 AM')
})

test('staff activity names the folder with its ID beneath; the head list leads with the ID', () => {
  const staff = render(HomeActivity, { title: "Today's activity", caption: 'Latest scans at your office (newest first)', rows: [scan], named: true, onOpen() {} })
  assert.match(staff, /Today&#x27;s activity/)
  assert.match(staff, /Latest scans at your office \(newest first\)/)
  assert.match(staff, /<strong>DV – Road Repair<\/strong><span>DOC-2026-000003<\/span>/)
  assert.match(staff, />SENT</)
  const head = render(HomeActivity, { title: 'Staff activity today', rows: [{ ...scan, status: 'IN' }], onOpen() {} })
  assert.match(head, /<strong>DOC-2026-000003<\/strong>/)
  assert.doesNotMatch(head, /DV – Road Repair/)
  assert.match(head, />IN</)
})

test('the list shows at most the limit, and nothing at all when there are no scans', () => {
  const many = Array.from({ length: 9 }, (_, i) => ({ ...scan, document_id: `DOC-2026-0000${i}0`, scanned_at: `2026-10-26 1${i % 5}:00:00` }))
  assert.equal((render(HomeActivity, { title: 'x', rows: many, limit: 6, onOpen() {} }).match(/home-activity__row/g) || []).length, 6)
  assert.equal(render(HomeActivity, { title: 'x', rows: [], onOpen() {} }), '')
  assert.equal(render(HomeActivity, { title: 'x', rows: undefined, onOpen() {} }), '')
})

test('a row opens its folder', () => {
  let opened = ''
  const tree = HomeActivity({ title: 'x', rows: [scan], onOpen: id => { opened = id } })
  const find = (node) => {
    if (!React.isValidElement(node)) return null
    if (node.type === 'button') return node
    return React.Children.toArray(node.props.children).map(find).find(Boolean) || null
  }
  find(tree).props.onClick()
  assert.equal(opened, 'DOC-2026-000003')
})

const head = (overrides = {}) => ({
  stats: { in_office: 4, overdue: 0, avg_hours: 6 },
  queue: [{ document_id: 'DOC-2026-000001', title: 'Road Repair', status_label: 'in_office', hours_pending: 4 }],
  recent_movements: [{ ...scan, status: 'IN' }],
  ...overrides,
})

test('the head home shows staff activity and, when nothing is late or unconfirmed, says the office is on track', () => {
  const html = render(HeadDashboardContent, { data: head(), error: '', loading: false, onRetry() {} })
  assert.match(html, /Staff activity today/)
  assert.match(html, /Office on track — no overdue or unconfirmed forwards right now\./)
})

test('the on-track note is never claimed over an overdue folder, a failed refresh or a read in progress', () => {
  const overdue = head({ queue: [{ document_id: 'DOC-2026-000009', title: 'Late', status_label: 'overdue', hours_pending: 99 }] })
  assert.doesNotMatch(render(HeadDashboardContent, { data: overdue, error: '', loading: false, onRetry() {} }), /Office on track/)
  assert.doesNotMatch(render(HeadDashboardContent, { data: head(), error: 'Connection lost', loading: false, onRetry() {} }), /Office on track/)
  assert.doesNotMatch(render(HeadDashboardContent, { data: head(), error: '', loading: true, onRetry() {} }), /Office on track/)
  assert.doesNotMatch(render(HeadDashboardContent, { data: head({ stats: { in_office: 0, overdue: 0, avg_hours: 0 }, queue: [] }), error: '', loading: false, onRetry() {} }), /Office on track/)
})

test('no activity section without scans, and none before the dashboard has loaded', () => {
  assert.doesNotMatch(render(HeadDashboardContent, { data: head({ recent_movements: [] }), error: '', loading: false, onRetry() {} }), /Staff activity today/)
  assert.doesNotMatch(render(HeadDashboardContent, { data: null, error: 'Down', loading: false, onRetry() {} }), /Staff activity today|Office on track/)
})

test('the freshness line says when the data loaded, and when it is the last good load', () => {
  const at = new Date(2026, 9, 26, 15, 30)
  assert.match(render(HomeUpdated, { at }), /Updated 3:30 PM/)
  assert.match(render(HomeUpdated, { at, failed: true }), /Last successful update 3:30 PM/)
  assert.equal(render(HomeUpdated, { at: null }), '')
  const html = render(HeadDashboardContent, { data: head(), error: '', loading: false, updated: at, onRetry() {} })
  assert.match(html, /Updated 3:30 PM/)
})
