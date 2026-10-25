import { test } from 'node:test'
import assert from 'node:assert/strict'
import { loadDocumentDetail } from '../src/document-detail.js'

test('linked folder outside office tray opens existing tracking access with all writes disabled', async () => {
  const calls = []
  const result = await loadDocumentDetail('DOC-2026-000001', false, {
    officeDocuments: async () => { calls.push('office'); throw Object.assign(new Error('Outside tray'), {status:404}) },
    documentShow: async () => { calls.push('tracking'); return { document:{id:'DOC-2026-000001',current_office_name:'Treasury Office',can_file:true,can_correct_destination:true} } },
    documentMovements: async () => { calls.push('history'); return { movements:[{id:9,status:'IN',office_name:'Treasury Office'}] } },
  })
  assert.deepEqual(calls, ['office','tracking','history'])
  assert.equal(result.read_only, true)
  assert.equal(result.document.tray, 'elsewhere')
  assert.equal(result.document.can_file, false)
  assert.equal(result.document.can_correct_destination, false)
  assert.equal(result.document.journey[0].id, 9)
})

test('office and municipal authorization failures are never replaced by broader tracking lookup', async () => {
  for (const [status, municipal] of [[403,false],[401,false],[500,false],[404,true]]) {
    const failure = Object.assign(new Error('Denied'), {status})
    await assert.rejects(loadDocumentDetail('DOC-2026-000001', municipal, {
      officeDocuments: async () => { throw failure },
      documentShow: async () => { assert.fail('Must not bypass office authorization failure') },
    }), error => error === failure)
  }
})
