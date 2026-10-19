import { test } from 'node:test'
import assert from 'node:assert/strict'
import { api, apiUpload } from '../src/api.js'

test('authenticated failures clear only the matching invalid session', async () => {
  let stored = 'current-token'
  const events = []
  globalThis.localStorage = { getItem: () => stored }
  globalThis.window = { dispatchEvent: event => { if (event.type === 'sf-session-invalid') events.push(event) } }
  globalThis.CustomEvent = class { constructor(type, options = {}) { this.type = type; this.detail = options.detail } }
  const cases = [
    ['expired', 401, '{"message":"Expired"}', true, true],
    ['non-JSON expiry', 401, 'Unauthorized', true, true],
    ['inactive', 403, '{"message":"This account has been deactivated"}', true, true],
    ['office permission', 403, '{"message":"Office access denied"}', true, false],
    ['public login rejection', 401, '{"message":"Invalid password"}', false, false],
    ['server error', 500, '{"message":"Server unavailable"}', true, false],
  ]
  for (const [label, status, body, auth, invalidates] of cases) {
    events.length = 0
    globalThis.fetch = async () => new Response(body, { status })
    await assert.rejects(api('test.php', { auth }))
    assert.equal(events.length, Number(invalidates), label)
    if (invalidates) assert.equal(events[0].detail.token, stored, label)
    if (invalidates) assert.equal(events[0].detail.status, status, `${label} reports its HTTP status for the sign-in message`)
  }
  events.length = 0
  globalThis.fetch = async () => { stored = 'new-token'; return new Response('{}', { status: 401 }) }
  await assert.rejects(api('old-request.php'))
  assert.equal(events.length, 0, 'an obsolete response cannot clear a newer login')
  globalThis.fetch = async () => new Response('Unauthorized', { status: 401 })
  await assert.rejects(apiUpload('upload.php', new FormData()))
  assert.equal(events.length, 1, 'multipart expiry also invalidates the session')
})
