import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'
import { createSessionClient } from '../src/api.js'
import { recordConfirmedFiling, recordConfirmedReceipt } from '../src/custody-actions.js'
import { submitCreation } from '../src/creation-recovery.js'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { default: ForgotPasswordPage } = await server.ssrLoadModule('/src/pages/ForgotPasswordPage.jsx')
const { default: ResetPasswordPage } = await server.ssrLoadModule('/src/pages/ResetPasswordPage.jsx')

test('password recovery keeps manual email-code entry and ignores old navigation-prefilled codes', () => {
  const render = Component => renderToStaticMarkup(React.createElement(MemoryRouter, { initialEntries: [{ pathname: '/reset-password', state: { username: 'sample', code: 'obsolete-autofill-code' } }] }, React.createElement(Component)))
  const forgot = render(ForgotPasswordPage)
  assert.match(forgot, /one-time code is emailed to the address on your account/)
  assert.match(forgot, /href="\/reset-password"/)
  assert.doesNotMatch(forgot, /Dev code|obsolete-autofill-code/)
  const reset = render(ResetPasswordPage)
  assert.match(reset, /reset code from your email/)
  assert.doesNotMatch(reset, /obsolete-autofill-code/)
  assert.match(reset, /id="reset-code"[^>]*value=""/)
})

function setup() {
  const stored = new Map([['sf_token', 'sample-A'], ['sf_user', JSON.stringify({ id: 1, office_id: 3 })]])
  const calls = [], events = []
  globalThis.localStorage = { getItem: key => stored.get(key) ?? null, setItem: (key, value) => stored.set(key, value), removeItem: key => stored.delete(key) }
  globalThis.CustomEvent = class { constructor(type, options = {}) { this.type = type; this.detail = options.detail } }
  globalThis.window = { dispatchEvent: event => events.push(event) }
  globalThis.fetch = async (url, options) => { calls.push({ url, options }); return new Response('{"success":true}') }
  const switchAccount = () => { stored.set('sf_token', 'sample-B'); stored.set('sf_user', JSON.stringify({ id: 2, office_id: 3 })) }
  return { stored, calls, events, switchAccount, first: createSessionClient('sample-A') }
}

test('a filing confirmation opened by A cannot submit under a later same-office B login', async () => {
  const { first, switchAccount, calls } = setup()
  const document = { id: 'DOC-SAMPLE', title: 'Inspection folder', last_movement_id: 10 }
  await assert.rejects(recordConfirmedFiling(document, async () => { switchAccount(); return true }, first.smartflow.fileDocument), /account changed/)
  assert.equal(calls.length, 0, 'the obsolete confirmation makes no HTTP request')
})

test('a receipt confirmation and captured request decision retain their reviewed login', async () => {
  const { first, switchAccount, calls } = setup()
  const decision = first.smartflow.documentRequestUpdate
  await assert.rejects(recordConfirmedReceipt({ id: 'DOC-SAMPLE' }, async () => { switchAccount(); return { confirmed: true } }, first.smartflow.recordMovement, { status: 'IN' }), /account changed/)
  await assert.rejects(decision({ request_id: 10, action: 'approve', expected_status: 'pending' }), /account changed/)
  assert.equal(calls.length, 0)
})

test('the newly reviewed B client sends B headers while the old client remains unusable', async () => {
  const { first, switchAccount, calls } = setup()
  switchAccount()
  await assert.rejects(first.smartflow.recordMovement({ document_id: 'DOC-SAMPLE', status: 'OUT' }), /account changed/)
  await createSessionClient('sample-B').smartflow.recordMovement({ document_id: 'DOC-SAMPLE', status: 'OUT' })
  assert.equal(calls.length, 1)
  assert.equal(calls[0].options.headers.Authorization, 'Bearer sample-B')
  assert.ok(!calls[0].url.includes('sample-B'))
  assert.ok(!calls[0].options.body.includes('sample-B'))
})

test('JSON, upload and export reject A responses when B signs in during body consumption', async () => {
  for (const kind of ['json', 'upload', 'export']) {
    const { first, switchAccount, events } = setup()
    globalThis.fetch = async () => ({ ok: true, status: 200, async text() { switchAccount(); return kind === 'export' ? 'private A report' : '{"success":true,"user":{"id":1}}' } })
    const operation = kind === 'json' ? first.api('auth-session.php') : kind === 'upload' ? first.smartflow.removeAvatar() : first.apiText('reports-summary.php')
    await assert.rejects(operation, error => error.data.session_changed === true)
    assert.equal(events.filter(event => event.type === 'sf-session-invalid').length, 0)
  }
})

test('stale A authentication failure cannot invalidate B, and cross-tab logout blocks A writes immediately', async () => {
  const { first, switchAccount, events, stored, calls } = setup()
  globalThis.fetch = async () => { switchAccount(); return new Response('{"message":"Expired"}', { status: 401 }) }
  await assert.rejects(first.api('auth-session.php'), /account changed/)
  assert.equal(stored.get('sf_token'), 'sample-B')
  assert.equal(events.filter(event => event.type === 'sf-session-invalid').length, 0)
  stored.delete('sf_token')
  await assert.rejects(first.smartflow.fileDocument('DOC-SAMPLE', 10), /account changed/)
  assert.equal(calls.length, 0)
})

test('an account switch after a creation write preserves A recovery evidence without writing or retrying as B', async () => {
  const { first, switchAccount, stored, calls } = setup()
  const previousNavigator = globalThis.navigator
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: {} })
  globalThis.fetch = async (url, options) => { calls.push({ url, options }); switchAccount(); return new Response('{"success":true,"request":{"id":42}}') }
  try {
    await assert.rejects(first.smartflow.documentRequestCreate({ purpose: 'Sample request' }), /Recover this submission in the original account/)
    assert.equal(calls.length, 1)
    assert.equal(calls[0].options.headers.Authorization, 'Bearer sample-A')
    assert.ok(stored.has('sf_creation_v1_1_3_request'))
    assert.equal(stored.has('sf_creation_v1_2_3_request'), false)
  } finally { Object.defineProperty(globalThis, 'navigator', { configurable: true, value: previousNavigator }) }
})

test('a saved-creation lock acquired after switching accounts cannot create B recovery state', async () => {
  const { first, switchAccount, stored, calls } = setup()
  const previousNavigator = globalThis.navigator
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { locks: { async request(_key, run) { switchAccount(); return run() } } } })
  try {
    await assert.rejects(submitCreation('request', { purpose: 'Sample request' }, first.api), /account changed/)
    assert.equal(calls.length, 0)
    assert.equal(stored.has('sf_creation_v1_1_3_request'), false)
    assert.equal(stored.has('sf_creation_v1_2_3_request'), false)
  } finally { Object.defineProperty(globalThis, 'navigator', { configurable: true, value: previousNavigator }) }
})

test('upload, export and label opened from the old account cannot obtain B data', async () => {
  const { first, switchAccount, calls } = setup()
  const preview = { close() { this.closed = true } }
  globalThis.window.open = () => preview
  switchAccount()
  await assert.rejects(first.smartflow.removeAvatar(), /account changed/)
  await assert.rejects(first.apiText('reports-summary.php'), /account changed/)
  await assert.rejects(first.openPrintableLabel('DOC-SAMPLE'), /account changed/)
  assert.equal(preview.closed, true)
  assert.equal(calls.length, 0)
})
