import { test } from 'node:test'
import assert from 'node:assert/strict'
import { applyDraft, draftIsDirty, parseDraft, registrationDraftKey, serializeDraft } from '../src/registration-draft.js'

// The web Register form keeps a half-filled folder like the phone does: same stored fields, never the physical count confirmation.

const blank = () => ({
  title: '', otherName: '', comment: '', reference: '', payee: '', fundSource: '', receivedFrom: '', dueDate: '',
  type: 'Disbursement Voucher',
  inventory: { count_confirmed: false, items: [{ name: 'Main document', pages: '', required: true }] },
})
const types = ['Disbursement Voucher', 'Approved Budget', 'Others']

test('the draft is kept per account, office and linked request', () => {
  assert.equal(registrationDraftKey({ id: 7, office_id: 3 }), 'sf_registration_draft_v1_7_3')
  assert.equal(registrationDraftKey({ id: 7, office_id: 3 }, '42'), 'sf_registration_draft_v1_7_3_request_42')
  assert.notEqual(registrationDraftKey({ id: 8, office_id: 3 }), registrationDraftKey({ id: 7, office_id: 3 }))
})

test('a blank form has nothing to keep; any field, a changed type or counted pages is worth keeping', () => {
  assert.equal(draftIsDirty(blank(), 'Disbursement Voucher'), false)
  assert.equal(serializeDraft(blank(), 'Disbursement Voucher'), null)
  for (const change of [
    { title: 'Road repair' }, { otherName: 'x' }, { comment: 'note' }, { reference: 'DV-1' }, { payee: 'ABC' }, { fundSource: 'MOOE' },
    { dueDate: '2026-11-30' }, { receivedFrom: '2' }, { type: 'Approved Budget' },
    { inventory: { count_confirmed: false, items: [{ name: 'Main document', pages: '4', required: true }] } },
    { inventory: { count_confirmed: false, items: [{ name: 'Main document', pages: '', required: true }, { name: '', pages: '', required: true }] } },
    { inventory: { count_confirmed: true, items: [{ name: 'Main document', pages: '', required: true }] } },
  ]) assert.equal(draftIsDirty({ ...blank(), ...change }, 'Disbursement Voucher'), true, JSON.stringify(change))
  assert.equal(draftIsDirty({ ...blank(), title: '   ' }, 'Disbursement Voucher'), false, 'spaces alone are not a draft')
})

test('what is saved is read back, except the physical count confirmation', () => {
  const form = {
    ...blank(), title: 'DV – Road Repair', reference: 'DV-2026-001', payee: 'ABC Builders', fundSource: 'MOOE', comment: 'Rush',
    dueDate: '2026-11-30', receivedFrom: '5', type: 'Approved Budget',
    inventory: { count_confirmed: true, items: [{ name: 'Main document', pages: '12', required: true }, { name: 'Receipts', pages: '0', required: false }] },
  }
  const stored = serializeDraft(form, 'Disbursement Voucher')
  assert.ok(!stored.includes('count_confirmed'), 'the confirmation is not stored')
  const restored = parseDraft(stored, { types })
  assert.deepEqual(restored, {
    title: 'DV – Road Repair', otherName: '', comment: 'Rush', reference: 'DV-2026-001', payee: 'ABC Builders', fundSource: 'MOOE',
    receivedFrom: '5', dueDate: '2026-11-30', type: 'Approved Budget',
    inventory: { count_confirmed: false, items: [{ name: 'Main document', pages: '12', required: true }, { name: 'Receipts', pages: '0', required: false }] },
  })
})

test('it reads the fields the phone stores, including an ISO due date and a numeric sender', () => {
  const fromPhone = JSON.stringify({
    title: 'Plantilla', other: '', comment: '', reference: 'R-9', payee: '', fund: '', type: 'Others',
    due: '2026-12-01T00:00:00.000', sender: 4, inventory: { items: [{ name: 'Whatever', pages: '3', required: false }] },
  })
  const restored = parseDraft(fromPhone, { types })
  assert.equal(restored.dueDate, '2026-12-01')
  assert.equal(restored.receivedFrom, '4')
  assert.equal(restored.type, 'Others')
  assert.deepEqual(restored.inventory.items, [{ name: 'Main document', pages: '3', required: true }], 'the first row is always the main document')
})

test('a type this office cannot register is ignored, and contents that cannot be read refuse the whole draft', () => {
  assert.equal(parseDraft(JSON.stringify({ title: 'x', type: 'Payroll' }), { types }).type, null)
  assert.equal(parseDraft(JSON.stringify({ title: 'x' }), { types }).inventory, null)
  for (const bad of ['not json', '[]', 'null', '"text"', JSON.stringify({ inventory: { items: 'nope' } }), JSON.stringify({ inventory: { items: [3] } }), JSON.stringify({ inventory: {} })]) {
    assert.throws(() => parseDraft(bad, { types }), undefined, bad)
  }
})

test('no more than twenty attachments come back, and an empty list leaves the contents alone', () => {
  const items = Array.from({ length: 30 }, (_, i) => ({ name: `Item ${i}`, pages: '1', required: true }))
  assert.equal(parseDraft(JSON.stringify({ inventory: { items } }), { types }).inventory.items.length, 21)
  assert.equal(parseDraft(JSON.stringify({ inventory: { items: [] } }), { types }).inventory, null)
})

test('laying a draft over the form keeps what the draft did not say', () => {
  const current = { ...blank(), title: 'From the request', comment: 'For REQ-1', type: 'Approved Budget' }
  const merged = applyDraft(current, parseDraft(JSON.stringify({ title: 'Edited title', type: 'Payroll' }), { types }))
  assert.equal(merged.title, 'Edited title')
  assert.equal(merged.type, 'Approved Budget', 'an unavailable type keeps the current one')
  assert.equal(merged.comment, '', 'a field the draft has empty is empty, as typed')
  assert.deepEqual(merged.inventory, current.inventory)
  // The merged form serializes to the same text the draft was read from, so restoring does not rewrite it.
  const stored = serializeDraft(merged, 'Disbursement Voucher')
  assert.equal(serializeDraft(applyDraft(merged, parseDraft(stored, { types })), 'Disbursement Voucher'), stored)
})
