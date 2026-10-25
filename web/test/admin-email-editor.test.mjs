import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { UsersContent, emailNeedsCheck } = await server.ssrLoadModule('/src/pages/AdminUsersPage.jsx')
const render = (props) => renderToStaticMarkup(React.createElement(UsersContent, props))

const users = [
  { id: 1, name: 'Admin', username: 'self.admin', email: 'admin@example.com', office_code: 'ACC', role: 'admin', is_active: true },
  { id: 3, name: 'Clerk One', username: 'clerk.one', email: 'clerk.one@urbiztondo.gov.ph', office_code: 'ENG', role: 'staff', is_active: true },
  { id: 4, name: 'Head One', username: 'head.one', email: 'real.head@gmail.com', office_code: 'BUD', role: 'head', is_active: true },
  { id: 5, name: 'No Mail', username: 'no.mail', email: null, office_code: 'HR', role: 'staff', is_active: true },
]
const base = { user: { id: 1 }, users, pending: [], loadError: '', error: '', ok: '', loading: false, busy: false, selectedUser: null, setSelectedUser() {}, load() {}, decide() {}, toggleActive() {} }

test('generated or missing addresses are flagged and confirmed ones are not', () => {
  assert.equal(emailNeedsCheck(users[1]), true)
  assert.equal(emailNeedsCheck(users[3]), true)
  assert.equal(emailNeedsCheck(users[2]), false)
})

test('each account shows its email under the name, with a Manage action for staff and head only', () => {
  const html = render(base)
  assert.match(html, /@head.one · real.head@gmail.com/)
  assert.match(html, /@no.mail · email not set/)
  assert.match(html, /aria-label="Manage clerk.one"/)
  assert.doesNotMatch(html, /Manage self.admin/)
  assert.equal((html.match(/>Check email</g) || []).length, 2)
})

test('the editor dialog shows the person, the current value, an error and the busy state', () => {
  const html = render({ ...base, emailTarget: users[1], emailValue: 'typed@example.com', emailError: 'That email address is already used by another account.' })
  assert.match(html, /Edit reset email/)
  assert.match(html, /value="typed@example\.com"/)
  assert.match(html, /already used by another account/)
  assert.match(html, /Save email/)
  assert.match(render({ ...base, emailTarget: users[1], emailBusy: true }), /Saving…/)
})

test('Manage is disabled while the directory is loading or failed to load', () => {
  assert.match(render({ ...base, loading: true }), /disabled=""[^>]*aria-label="Manage clerk.one"/)
})
