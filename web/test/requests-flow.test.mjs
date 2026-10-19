import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { RequestDetails, RequestActions } = await server.ssrLoadModule('/src/pages/RequestsPage.jsx')
const handler = { id: 8, role: 'staff', office_id: 2, office_code: 'BUD' }
const requester = { id: 5, role: 'staff', office_id: 1, office_code: 'ENG' }
const request = {
  id: 7, request_code: 'REQ-2026-0007', request_kind: 'access', document_category: 'budget',
  status: 'approved', purpose: 'Review the complete road maintenance budget and include the final supporting schedule — END OF FULL PURPOSE.',
  review_notes: 'Missing signed schedule. Attach the complete version — END OF DECISION REASON.',
  required_by: '2026-10-12', created_at: '2026-10-10 08:00:00', reviewed_at: '2026-10-11 09:30:00',
  requester: { user_id: 5, name: 'Engineering requester', office_id: 1, office_name: 'Engineering Office', office_code: 'ENG' },
  handler_office: { office_id: 2, office_name: 'Budget Office', office_code: 'BUD' },
}
const render = (Component, props) => renderToStaticMarkup(React.createElement(MemoryRouter, null, React.createElement(Component, props)))

test('request details retain the full purpose and decline reason for the requester', () => {
  const html = render(RequestDetails, { req: { ...request, status: 'rejected' }, user: requester })
  for (const text of ['END OF FULL PURPOSE.', 'END OF DECISION REASON.', 'Reason for declining', 'Engineering requester', 'Budget Office', 'Submitted', 'Reviewed', 'New request']) assert.ok(html.includes(text), text)
})

test('accepted handler can link or register a folder while requester can only follow up', () => {
  const handlerHtml = render(RequestDetails, { req: request, user: handler })
  assert.match(handlerHtml, /Select existing folder/)
  assert.match(handlerHtml, /href="\/register\?request_id=7"/)
  const requesterHtml = render(RequestDetails, { req: request, user: requester })
  assert.doesNotMatch(requesterHtml, /Select existing folder|Register folder/)
  assert.match(render(RequestActions, { req: request, user: requester }), /Cancel request/)
  assert.doesNotMatch(render(RequestActions, { req: request, user: requester }), /Close request|Accept request/)
  for (const role of ['head', 'admin']) {
    assert.doesNotMatch(render(RequestDetails, { req: request, user: { ...handler, role } }), /href="\/register/)
  }
})

test('DV completion remains a Treasury payment release action', () => {
  const dv = { ...request, document_category: 'disbursement', handler_office: { office_id: 3, office_code: 'ACC' } }
  const accounting = { id: 9, role: 'staff', office_id: 3, office_code: 'ACC' }
  const treasury = { id: 10, role: 'staff', office_id: 4, office_code: 'TRE' }
  assert.doesNotMatch(render(RequestActions, { req: dv, user: accounting }), /Mark payment released|Close request/)
  assert.match(render(RequestActions, { req: dv, user: treasury }), /Mark payment released/)
  assert.doesNotMatch(render(RequestDetails, { req: dv, user: treasury }), /Select existing folder|Register folder/)
  assert.doesNotMatch(render(RequestActions, { req: { ...dv, status: 'fulfilled' }, user: treasury }), /Mark payment released/)
  const saving = render(RequestActions, { req: dv, user: treasury, saving: true })
  assert.match(saving, /disabled=""/)
})

test('linked requests open Documents directly and retain a separate history link', () => {
  const linked = { ...request, related_document_id: 'DOC-2026-000007', is_overdue: true }
  const handlerHtml = render(RequestDetails, { req: linked, user: handler })
  assert.match(handlerHtml, /href="\/documents\?id=DOC-2026-000007"/)
  assert.match(handlerHtml, /Open in Documents/)
  assert.match(handlerHtml, /href="\/history\?id=DOC-2026-000007"/)
  assert.match(handlerHtml, /View custody history/)
  assert.match(handlerHtml, /still awaiting completion/)
  assert.doesNotMatch(handlerHtml, /Select existing folder|Register folder/)
  for (const user of [requester, { ...handler, role: 'head' }, { ...handler, role: 'admin' }]) {
    const html = render(RequestDetails, { req: linked, user })
    assert.match(html, /href="\/documents\?id=DOC-2026-000007"/)
    assert.match(html, /href="\/history\?id=DOC-2026-000007"/)
  }
})

test('request purpose and next step precede metadata without losing notes or requester context', () => {
  const handlerHtml = render(RequestDetails, { req: request, user: handler })
  assert.ok(handlerHtml.indexOf('END OF FULL PURPOSE.') < handlerHtml.indexOf('Next step'))
  assert.ok(handlerHtml.indexOf('Next step') < handlerHtml.indexOf('Requested by'))
  assert.match(handlerHtml, /Linking does not close the request or record a handoff/)
  assert.match(handlerHtml, /END OF DECISION REASON/)
  const requesterHtml = render(RequestDetails, { req: request, user: requester })
  assert.match(requesterHtml, /handling office accepted your request/)
  assert.doesNotMatch(requesterHtml, /Complete the requested work, then close/)
})
