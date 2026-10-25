import { test, beforeEach } from 'node:test'
import assert from 'node:assert/strict'
import { webcrypto } from 'node:crypto'
import { pendingCreation, submitCreation, checkCreation } from '../src/creation-recovery.js'

let saved
beforeEach(() => {
  saved = new Map([['sf_user', JSON.stringify({ id: 1, office_id: 2 })]])
  globalThis.localStorage = { getItem: key => saved.get(key) ?? null, setItem: (key, value) => saved.set(key, value), removeItem: key => saved.delete(key) }
  Object.defineProperty(globalThis, 'crypto', { value: webcrypto, configurable: true })
})
test('lost creation response reads saved result without resubmitting', async () => {
  const calls = []
  const call = async (path, options) => {
    calls.push([path, options])
    if (options.method === 'POST') throw new Error('Response lost')
    return { state: 'recorded', result: { document: { id: 'DOC-TEST' } } }
  }
  assert.equal((await submitCreation('document', { title: 'Folder' }, call)).document.id, 'DOC-TEST')
  assert.deepEqual(calls.map(row => row[0]), ['documents-create.php', 'creation-requests.php'])
  assert.equal(pendingCreation('document'), null)
})
test('unknown outcome survives restart, blocks changed forms, and explicit retry reuses ID', async () => {
  const ids = []
  let succeeds = false
  const call = async (path, options) => {
    if (options.method !== 'POST') return { state: 'unknown' }
    ids.push(options.body.operation_id)
    if (!succeeds) throw new Error('Offline')
    return { request: { id: 42 } }
  }
  await assert.rejects(submitCreation('request', { purpose: 'Original' }, call), /pending/)
  assert.match(pendingCreation('request').id, /^[a-f0-9]{32}$/)
  await assert.rejects(submitCreation('request', { purpose: 'Changed' }, call), /previous submission/)
  assert.equal(ids.length, 1)
  succeeds = true
  assert.equal((await submitCreation('request', { purpose: 'Original' }, call)).request.id, 42)
  assert.equal(ids[0], ids[1])
  assert.equal(pendingCreation('request'), null)
})
test('storage failure prevents POST; definite rejection clears recovery; account scopes remain separate', async () => {
  let posts = 0
  const reject = async () => { posts++; throw Object.assign(new Error('Invalid form'), { status: 400 }) }
  await assert.rejects(submitCreation('document', { title: 'Bad' }, reject), /Invalid form/)
  assert.equal(pendingCreation('document'), null)
  localStorage.setItem = () => { throw new Error('Storage blocked') }
  await assert.rejects(submitCreation('document', { title: 'New' }, reject), /Storage blocked/)
  assert.equal(posts, 1)
  assert.equal(await checkCreation('request', reject), null)
})
test('a delayed outcome check cannot erase a newer saved submission', async () => {
  const key = 'sf_creation_v1_1_2_document'
  saved.set(key, JSON.stringify({ id: 'a'.repeat(32), body: { title: 'Old' } }))
  let resolve
  const checked = checkCreation('document', () => new Promise(done => { resolve = done }))
  saved.set(key, JSON.stringify({ id: 'b'.repeat(32), body: { title: 'New' } }))
  resolve({ state: 'recorded', result: { document: { id: 'OLD' } } })
  await assert.rejects(checked, /saved submission changed/)
  assert.equal(pendingCreation('document').id, 'b'.repeat(32))
})

test('lost destination correction response checks its movement operation without another POST', async () => {
  const calls = []
  const body = { document_id: 'DOC-2026-000001', expected_movement_id: 3, expected_destination_office_id: 4, expected_correction_id: 0, destination_office_id: 5, reason: 'Correct recorded office', correction_confirmed: true }
  const result = await submitCreation('correction', body, async (path, options) => {
    calls.push([path, options])
    if (options.method === 'POST') throw new Error('Lost response')
    return { state: 'recorded', result: { correction_id: 9 } }
  })
  assert.equal(result.correction_id, 9)
  assert.deepEqual(calls.map(row => row[0]), ['movements-correct-destination.php', 'movement-requests.php'])
  assert.match(calls[0][1].body.request_id, /^[a-f0-9]{32}$/)
  assert.equal(calls[1][1].query.request_id, calls[0][1].body.request_id)
  assert.equal(calls[0][1].body.operation_id, undefined)
  assert.equal(pendingCreation('correction'), null)
})
