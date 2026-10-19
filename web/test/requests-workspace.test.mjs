import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { RequestActions, RequestDetailPanel } = await server.ssrLoadModule('/src/pages/RequestsPage.jsx')
const user = { id: 8, role: 'staff', office_id: 2, office_code: 'BUD' }
const request = {
  id: 7, request_code: 'REQ-2026-0007', request_kind: 'access', document_category: 'budget',
  status: 'approved', purpose: 'Review every supporting schedule. END OF COMPLETE PURPOSE.',
  review_notes: 'Include the signed copy. END OF COMPLETE NOTES.', required_by: '2026-10-20',
  requester: { user_id: 5, name: 'Engineering requester', office_name: 'Engineering Office', office_code: 'ENG' },
  handler_office: { office_id: 2, office_name: 'Budget Office', office_code: 'BUD' },
}
const render = (props) => renderToStaticMarkup(React.createElement(MemoryRouter, null,
  React.createElement(RequestDetailPanel, { user, onAction() {}, ...props })))
const renderActions = (req, actor) => renderToStaticMarkup(React.createElement(RequestActions, {
  req, user: actor, onAction() {},
}))
const requester = { id: 5, role: 'staff', office_id: 1, office_code: 'ENG' }
const head = { ...user, role: 'head' }
const admin = { id: 19, role: 'admin', office_id: 9, office_code: 'MAY' }
const treasury = { id: 20, role: 'staff', office_id: 4, office_code: 'TRE' }

test('desktop details retain the full request and its permitted actions beside the list', () => {
  const html = render({ req: request, selectedId: '7' })
  for (const text of ['END OF COMPLETE PURPOSE.', 'END OF COMPLETE NOTES.', 'Clear selection', 'Select existing folder', 'Close request']) assert.ok(html.includes(text), text)
  assert.match(html, /id="request-workspace-detail"/)
  assert.doesNotMatch(html, /role="dialog"/)
})

test('empty and unavailable selections never expose request actions', () => {
  const empty = render({ selectedId: '' })
  assert.match(empty, /Select a request/)
  assert.doesNotMatch(empty, /Close request|Accept request|Select existing folder/)
  assert.doesNotMatch(empty, /request-workspace__actions/)
  const unavailable = render({ selectedId: '999' })
  assert.match(unavailable, /This request is unavailable/)
  assert.doesNotMatch(unavailable, /Close request|Accept request|Select existing folder/)
  assert.doesNotMatch(unavailable, /request-workspace__actions/)
})

test('open dialogs or form drafts block detail actions until the workspace is available', () => {
  const html = render({ req: request, selectedId: '7', busy: true })
  assert.match(html, /disabled="">Clear selection/)
  assert.match(html, /disabled="">Select existing folder/)
  assert.match(html, /disabled="">Close request/)
  assert.match(html, /aria-disabled="true"[^>]*href="\/register\?request_id=7"/)
})

test('terminal requests retain their details without an empty action footer for any actor', () => {
  for (const status of ['rejected', 'fulfilled', 'cancelled']) {
    const req = { ...request, status }
    for (const actor of [user, head, admin, treasury, requester]) {
      const html = render({ req, selectedId: '7', user: actor })
      assert.match(html, /END OF COMPLETE PURPOSE\./)
      assert.match(html, /END OF COMPLETE NOTES\./)
      assert.doesNotMatch(html, /request-workspace__actions|class="row-btns request-actions"/,
        `${status} must not reserve an action-footer box for ${actor.role}/${actor.office_code}`)
      assert.equal(renderActions(req, actor), '', `${status} has no state-changing footer actions`)
    }
  }
})

test('active requests without decision or cancellation authority do not reserve a footer', () => {
  const observer = { id: 30, role: 'head', office_id: 8, office_code: 'ENG' }
  const accounting = { id: 31, role: 'head', office_id: 3, office_code: 'ACC' }
  const cases = [
    [{ ...request, status: 'pending' }, observer],
    [request, observer],
    [{ ...request, document_category: 'disbursement', handler_office: { office_id: 3, office_code: 'ACC' } }, accounting],
  ]
  for (const [req, actor] of cases) {
    const html = render({ req, selectedId: '7', user: actor })
    assert.match(html, /END OF COMPLETE PURPOSE\./)
    assert.doesNotMatch(html, /request-workspace__actions|class="row-btns request-actions"/)
    assert.equal(renderActions(req, actor), '')
  }
})

test('permitted staff, head, admin, Treasury and requester actions keep their footer', () => {
  const dv = { ...request, document_category: 'disbursement', handler_office: { office_id: 3, office_code: 'ACC' } }
  const cases = [
    ...[user, head, admin].map(actor => [{ ...request, status: 'pending' }, actor, ['Accept request', 'Decline']]),
    ...[user, head, admin].map(actor => [request, actor, ['Close request']]),
    [dv, treasury, ['Mark payment released']],
    [dv, admin, ['Mark payment released']],
    [{ ...request, status: 'pending' }, requester, ['Cancel request']],
    [request, requester, ['Cancel request']],
  ]
  for (const [req, actor, labels] of cases) {
    const html = render({ req, selectedId: '7', user: actor })
    assert.match(html, /class="request-workspace__actions"/)
    const footer = html.slice(html.indexOf('class="request-workspace__actions"'))
    for (const label of labels) assert.ok(footer.includes(label), `${actor.role}/${actor.office_code}: ${label}`)
    if (actor === requester) assert.doesNotMatch(footer, /Accept request|Decline|Close request|Mark payment released/)
    if (actor === treasury) assert.doesNotMatch(footer, /Accept request|Decline|Close request/)

    for (const blocked of [{ busy: true }, { fresh: false }]) {
      const blockedHtml = render({ req, selectedId: '7', user: actor, ...blocked })
      const blockedFooter = blockedHtml.slice(blockedHtml.indexOf('class="request-workspace__actions"'))
      assert.match(blockedHtml, /class="request-workspace__actions"/)
      const buttons = [...blockedFooter.matchAll(/<button\b([^>]*)>/g)]
      assert.equal(buttons.length, labels.length, 'Busy or stale state keeps the same permitted action set')
      for (const [, attributes] of buttons) assert.match(attributes, /\bdisabled=""/)
    }
  }
})

test('footer availability preserves accepted-DV release and requester cancellation guards', () => {
  const dv = { ...request, document_category: 'disbursement', handler_office: { office_id: 3, office_code: 'ACC' } }
  const accounting = { id: 31, role: 'head', office_id: 3, office_code: 'ACC' }
  assert.equal(renderActions(null, user), '')
  assert.equal(renderActions({ ...dv, status: 'pending' }, treasury), '')
  assert.equal(renderActions(dv, accounting), '')
  const treasuryHtml = renderActions(dv, treasury)
  assert.match(treasuryHtml, /Mark payment released/)
  assert.doesNotMatch(treasuryHtml, /Accept request|Decline|Close request|Cancel request/)
  const pendingAdminHtml = renderActions({ ...dv, status: 'pending' }, admin)
  assert.match(pendingAdminHtml, /Accept request/)
  assert.match(pendingAdminHtml, /Decline/)
  assert.doesNotMatch(pendingAdminHtml, /Mark payment released|Close request|Cancel request/)
  const acceptedAdminHtml = renderActions(dv, admin)
  assert.match(acceptedAdminHtml, /Mark payment released/)
  assert.doesNotMatch(acceptedAdminHtml, /Accept request|Decline|Close request|Cancel request/)
  const requesterHtml = renderActions(dv, requester)
  assert.match(requesterHtml, /Cancel request/)
  assert.doesNotMatch(requesterHtml, /Accept request|Decline|Mark payment released|Close request/)
})
