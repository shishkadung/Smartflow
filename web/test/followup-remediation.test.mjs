import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'
import { smartflow } from '../src/api.js'
import { formatWhen } from '../src/tracking.js'
import { beginScopedRead, failScopedRead, scopedReadView } from '../src/scoped-read.js'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { QrMonitorContent } = await server.ssrLoadModule('/src/pages/AdminQrMonitorPage.jsx')
const { HeadAnalyticsContent } = await server.ssrLoadModule('/src/pages/HeadAnalyticsPage.jsx')
const { RequestDetailPanel, RequestDecisionHistory } = await server.ssrLoadModule('/src/pages/RequestsPage.jsx')
const render = (Component, props) => renderToStaticMarkup(React.createElement(MemoryRouter, null, React.createElement(Component, props)))
const callbacks = { onRetry() {}, onOutcome() {}, onExport() {}, onOpen() {} }

function findElement(node, predicate) {
  if (!React.isValidElement(node)) return undefined
  if (predicate(node)) return node
  return React.Children.toArray(node.props.children).map(child => findElement(child, predicate)).find(Boolean)
}

test('QR monitor initial read failure is unavailable with retry and never an audit all-clear', () => {
  let retries = 0
  const props = { ...callbacks, data: null, error: 'Exception service unavailable', loading: false, outcome: 'all', onRetry() { retries++ } }
  const html = render(QrMonitorContent, props)
  assert.match(html, /QR monitor unavailable/)
  assert.match(html, /Custody exceptions have not been verified/)
  assert.doesNotMatch(html, /No exceptions|No scan events|No admin or account actions/)
  assert.match(html, /disabled="">Download scan CSV/)
  const retry = findElement(QrMonitorContent(props), node => node.type === 'button' && node.props.children === 'Retry monitor')
  assert.equal(retry.props.disabled, false)
  retry.props.onClick()
  assert.equal(retries, 1)
})

test('QR monitor failed refresh retains marked records and suppresses retained empty all-clears', () => {
  const props = { ...callbacks, data: { rows: [{ id: 7, document_id: 'DOC-2026-000007', outcome: 'rejected', message: 'Wrong receiver' }], exceptions: [], activity: [] }, loading: false, error: 'Connection lost', outcome: 'rejected' }
  const html = render(QrMonitorContent, props)
  assert.match(html, /Monitor refresh failed/)
  assert.match(html, /previously loaded records; they may be out of date/)
  assert.match(html, /Wrong receiver/)
  assert.match(html, /<a[^>]*href="\/history\?id=DOC-2026-000007"/)
  assert.match(html, /aria-label="View history of DOC-2026-000007"/)
  assert.doesNotMatch(html, /No exceptions|No admin or account actions/)
  const verified = render(QrMonitorContent, { ...props, error: '', data: { rows: [], exceptions: [], activity: [] } })
  assert.match(verified, /No custody exceptions found/)
  assert.match(verified, /No scan events/)
})

const analyticsProps = { user: { office_name: 'Budget Office', office_code: 'BUD' }, month: '2026-10', onMonth() {}, onRetry() {} }
const analytics = { month: '2026-10', stats: { on_time_percent: 75, unforwarded_percent: 10, delayed_percent: 15, processed: 20, late_count: 3 }, slow_documents: [] }

test('analytics distinguishes failed new-month reads, failed same-month refresh and verified zero', () => {
  const old = { key: 'month-October', data: analytics, error: '', loading: false, updated: new Date() }
  const changed = failScopedRead(beginScopedRead(old, 'month-September'), 'month-September', 'September unavailable')
  const html = render(HeadAnalyticsContent, { ...analyticsProps, month: '2026-09', ...changed })
  assert.match(html, /Analytics unavailable/)
  assert.match(html, /Retry analytics/)
  assert.doesNotMatch(html, /75%|No slow documents|2026-10/)
  const stale = render(HeadAnalyticsContent, { ...analyticsProps, data: analytics, loading: false, error: 'Refresh failed' })
  assert.match(stale, /Showing previously loaded analytics for 2026-10/)
  assert.match(stale, /75%/)
  assert.match(stale, /Slow-folder status is not currently verified/)
  assert.doesNotMatch(stale, /No slow documents/)
  const verified = render(HeadAnalyticsContent, { ...analyticsProps, data: analytics, loading: false, error: '' })
  assert.match(verified, /No slow documents/)
  assert.equal(scopedReadView(old, 'different-account-same-month').data, null)
})

const request = { id: 7, request_code: 'REQ-2026-0007', status: 'pending', purpose: 'Read the original complete purpose before deciding.', requester: { user_id: 5 }, handler_office: { office_id: 3 }, revision: 'a'.repeat(64) }
const requestProps = { req: request, selectedId: '7', user: { id: 8, office_id: 3, office_code: 'ACC', role: 'staff' }, busy: false, onClose() {}, onAction() {}, onNew() {}, onRetry() {} }

test('unverified exact request keeps full purpose but blocks decisions until exact-read recovery', () => {
  for (const state of [{ loading: true, error: '' }, { loading: false, error: 'Selected ticket unavailable' }]) {
    const html = render(RequestDetailPanel, { ...requestProps, ...state, fresh: false })
    assert.match(html, /Read the original complete purpose/)
    assert.match(html, /disabled="">(?:Saving…|Accept request)/)
    assert.match(html, /disabled="">Decline/)
    if (state.error) assert.match(html, /Retry request details/)
    else {
      assert.doesNotMatch(html, /Retry request details/)
      assert.doesNotMatch(html, /Saving…/)
    }
  }
  const recovered = render(RequestDetailPanel, { ...requestProps, loading: false, error: '', fresh: true })
  assert.match(recovered, /class="btn"[^>]*>Accept request/)
  assert.doesNotMatch(recovered, /Verifying the latest request|Latest request details unavailable/)
  const accepted = render(RequestDetailPanel, { ...requestProps, req: { ...request, status: 'approved' }, fresh: false, loading: false, error: 'Refresh failed' })
  assert.match(accepted, /disabled="">Select existing folder/)
})

test('exact ticket freshness is scoped to the account and ticket independently from list snapshots', () => {
  const old = { key: 'user8-office3-ticket7', data: request, error: '', loading: false, updated: new Date() }
  assert.equal(beginScopedRead(old, old.key).loading, true)
  assert.equal(failScopedRead(old, old.key, 'Read failed').error, 'Read failed')
  for (const key of ['user9-office3-ticket7', 'user8-office3-ticket9']) assert.equal(scopedReadView(old, key).data, null)
})

const reviewer = { user_id: 8, name: 'Accounting reviewer', office_name: 'Accounting Office' }
const fulfiller = { user_id: 9, name: 'Treasury release clerk', office_name: 'Treasury Office' }
test('full initial review and payment-release evidence remains separate with recorded actors and times', () => {
  const review = `Accepted after reviewing signed schedules.\n${'Complete acceptance evidence. '.repeat(30)}END ACCEPTANCE`
  const close = `Payment was actually released.\n${'Full Treasury release notes. '.repeat(30)}END RELEASE`
  const html = render(RequestDecisionHistory, { request: { status: 'fulfilled', document_category: 'disbursement', review_notes_kind: 'review', review_notes: review, reviewer, reviewed_at: '2026-10-11 10:00:00', fulfilled_notes: close, fulfiller, fulfilled_at: '2026-10-15 14:30:00' } })
  for (const text of ['Review notes', 'Payment release notes', 'Accounting reviewer', 'Accounting Office', 'Treasury release clerk', 'Treasury Office', 'END ACCEPTANCE', 'END RELEASE']) assert.ok(html.includes(text), text)
  assert.ok(html.indexOf('END ACCEPTANCE') < html.indexOf('Payment release notes'))
  assert.ok(html.includes(review) && html.includes(close))
})

test('cancelled and legacy request evidence never invents an initial review, actor or outcome note', () => {
  const cancelled = render(RequestDecisionHistory, { request: { status: 'cancelled', review_notes_kind: 'review', review_notes: 'Original acceptance remains.', reviewer, reviewed_at: '2026-10-11 10:00:00', cancelled_notes: 'Scope changed.\nCancellation reason complete.', canceller: { name: 'Requester', office_name: 'Engineering' }, cancelled_at: '2026-10-15 15:00:00' } })
  assert.match(cancelled, /Original acceptance remains/)
  assert.match(cancelled, /Cancellation reason complete/)
  assert.match(cancelled, /Cancellation notes/)
  const legacy = render(RequestDecisionHistory, { request: { status: 'fulfilled', review_notes_kind: 'legacy', review_notes: 'Older mixed record', reviewed_at: '2026-10-11 10:00:00', fulfilled_notes: null, fulfilled_at: '2026-10-15 15:00:00', reviewer, fulfiller: null } })
  assert.match(legacy, /Existing recorded notes/)
  assert.match(legacy, /notes and recorded metadata may refer to either stage/)
  assert.doesNotMatch(legacy, /Review notes|Reviewed ·/)
  assert.match(legacy, /Recorded · Accounting reviewer · Accounting Office/)
  assert.match(legacy, new RegExp(formatWhen('2026-10-11 10:00:00').replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
  assert.match(legacy, /Actor not recorded/)
})

test('filing submits the captured reviewed movement without reading or rebasing it first', async () => {
  const originalFetch = globalThis.fetch
  const originalStorage = globalThis.localStorage
  const originalWindow = globalThis.window
  globalThis.localStorage = { getItem() { return 'synthetic-session' } }
  globalThis.window = { dispatchEvent() {} }
  const calls = []
  globalThis.fetch = async (url, options) => { calls.push({ url, ...options }); return new Response(JSON.stringify({ success: true, message: 'Filed' }), { headers: { 'Content-Type': 'application/json' } }) }
  try {
    const reviewed = { id: 'DOC-2026-000007', last_movement_id: 42 }
    await smartflow.fileDocument(reviewed.id, reviewed.last_movement_id)
    assert.equal(calls.length, 1)
    assert.match(calls[0].url, /documents-file.php$/)
    assert.equal(calls[0].method, 'POST')
    assert.deepEqual(JSON.parse(calls[0].body), { document_id: reviewed.id, expected_movement_id: 42 })
  } finally { globalThis.fetch = originalFetch; globalThis.localStorage = originalStorage; globalThis.window = originalWindow }
})
