import { test } from 'node:test'
import assert from 'node:assert/strict'
import { api, apiText, apiUpload, openPrintableLabel, smartflow } from '../src/api.js'

test('authenticated JSON, multipart, and print retrieval keep bearer credentials out of URLs and bodies', async () => {
  globalThis.localStorage = { getItem: () => 'private-session' }
  globalThis.window = { dispatchEvent() {} }
  const requests = []
  globalThis.fetch = async (url, options) => {
    requests.push({ url, options })
    return new Response(url.includes('qr-label.php') ? '<!doctype html><head></head><body>Label</body>' : '{"success":true}')
  }
  await api('check.php', { query: { id: 'DOC-1' } })
  await api('write.php', { method: 'POST', body: { note: 'visible value' } })
  const form = new FormData(); form.set('remove', '1')
  await apiUpload('avatar.php', form)
  await apiText('qr-label.php', { id: 'DOC-1' })
  for (const { url, options } of requests) {
    assert.ok(!url.includes('private-session'))
    assert.equal(options.headers.Authorization, 'Bearer private-session')
    assert.equal(options.headers['X-Smartflow-Token'], 'private-session')
    const body = options.body instanceof FormData ? [...options.body].flat().join(' ') : options.body || ''
    assert.ok(!body.includes('private-session'))
  }
})

test('signup status proof is a POST body and does not attach an unrelated session', async () => {
  globalThis.localStorage = { getItem: () => 'unrelated-session' }
  globalThis.fetch = async (url, options) => {
    assert.equal(url, '/smartflow-api/signup-status.php')
    assert.equal(options.method, 'POST')
    assert.equal(options.headers.Authorization, undefined)
    assert.deepEqual(JSON.parse(options.body), { request_code: 'REQ-1', status_key: 'owner-proof' })
    return new Response('{"success":true,"request":{"status":"pending"}}')
  }
  await smartflow.signupStatus({ code: 'REQ-1', statusKey: 'owner-proof' })
})

test('printable label opens an authenticated blob preview and closes failed previews', async () => {
  globalThis.localStorage = { getItem: () => 'private-session' }
  const previews = []
  globalThis.window = { location: { href: 'http://localhost:5173/register' }, dispatchEvent() {}, open() {
    const preview = { opener: {}, location: { replace(url) { preview.url = url } }, close() { preview.closed = true } }
    previews.push(preview); return preview
  } }
  const originalCreate = URL.createObjectURL
  const originalRevoke = URL.revokeObjectURL
  const originalTimeout = globalThis.setTimeout
  let savedBlob
  URL.createObjectURL = (blob) => { savedBlob = blob; return 'blob:private-label-preview' }
  URL.revokeObjectURL = () => {}
  globalThis.setTimeout = fn => { fn(); return 0 }
  try {
    globalThis.fetch = async (url, options) => {
      assert.ok(!url.includes('private-session'))
      assert.equal(options.headers.Authorization, 'Bearer private-session')
      return new Response('<!doctype html><head></head><body>Label</body>')
    }
    await openPrintableLabel('DOC-1')
    assert.equal(previews[0].url, 'blob:private-label-preview')
    assert.equal(previews[0].opener, null)
    const html = await savedBlob.text()
    assert.match(html, /<base href="http:\/\/localhost:5173\/smartflow-api\/">/)
    assert.ok(!html.includes('private-session'))
    globalThis.fetch = async () => new Response('{"message":"Service unavailable"}', { status: 503 })
    await assert.rejects(openPrintableLabel('DOC-1'), /Service unavailable/)
    assert.equal(previews[1].closed, true)
  } finally {
    URL.createObjectURL = originalCreate
    URL.revokeObjectURL = originalRevoke
    globalThis.setTimeout = originalTimeout
  }
})
