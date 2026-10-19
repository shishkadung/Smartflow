import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { UsersContent, TemporaryPasswordResult } = await server.ssrLoadModule('/src/pages/AdminUsersPage.jsx')
const render = (Component, props) => renderToStaticMarkup(React.createElement(Component, props))

const users = [
  { id: 1, name: 'Admin', username: 'self.admin', office_code: 'ACC', role: 'admin', is_active: true },
  { id: 2, name: 'Other Admin', username: 'other.admin', office_code: 'ACC', role: 'admin', is_active: true },
  { id: 3, name: 'Clerk One', username: 'clerk.one', office_code: 'ENG', role: 'staff', is_active: true },
  { id: 4, name: 'Head One', username: 'head.one', office_code: 'BUD', role: 'head', is_active: true },
  { id: 5, name: 'Gone Clerk', username: 'gone.clerk', office_code: 'HR', role: 'staff', is_active: false },
]
const base = { user: { id: 1 }, users, pending: [], loadError: '', error: '', ok: '', loading: false, busy: false, selectedUser: null, setSelectedUser() {}, load() {}, decide() {}, toggleActive() {} }

test('Manage is offered for staff and head accounts only, and Reset password only for active ones in its dialog', () => {
  const html = render(UsersContent, base)
  assert.match(html, /aria-label="Manage clerk.one"/)
  assert.match(html, /aria-label="Manage head.one"/)
  assert.doesNotMatch(html, /aria-label="Manage (self|other).admin"/)
  assert.doesNotMatch(html, /Reset password for/, "no row button is shown until the Manage dialog opens")
  const active = render(UsersContent, { ...base, manageTarget: users[2] })
  assert.match(active, /Manage account/)
  assert.match(active, /aria-label="Reset password for clerk.one"/)
  assert.match(active, /aria-label="Edit email for clerk.one"/)
  const gone = render(UsersContent, { ...base, manageTarget: users[4] })
  assert.match(gone, /aria-label="Edit email for gone.clerk"/)
  assert.doesNotMatch(gone, /aria-label="Reset password for gone.clerk"/)
  assert.match(gone, /active accounts only/)
})

test('the confirmation explains the consequences and keeps the email reset as the preferred path', () => {
  const html = render(UsersContent, { ...base, resetTarget: users[2] })
  assert.match(html, /Issue a temporary password\?/)
  assert.match(html, /Clerk One \(@clerk\.one\) will be signed out everywhere/)
  assert.match(html, /only when the emailed reset code does not reach the user/)
  assert.match(html, /Issue temporary password/)
  assert.doesNotMatch(html, /data-testid="temporary-password"/)
  const failed = render(UsersContent, { ...base, resetTarget: users[2], resetError: 'Activate the account before resetting its password.' })
  assert.match(failed, /role="alert">Activate the account before resetting its password/)
  assert.match(render(UsersContent, { ...base, resetTarget: users[2], resetBusy: true }), /Issuing…/)
})

test('the temporary password is shown once, in readable groups, with sharing and expiry guidance', () => {
  const result = { name: 'Clerk One', username: 'clerk.one', password: 'Abcd2345Efgh', expires: '2026-10-20 13:00:00' }
  const html = render(UsersContent, { ...base, resetTarget: users[2], resetResult: result })
  assert.match(html, /Temporary password for Clerk One \(@clerk\.one\)/)
  assert.match(html, /data-testid="temporary-password">Abcd 2345 Efgh</)
  assert.match(html, /never by chat or email/)
  assert.match(html, /shown only once, expires in 24 hours/)
  assert.match(html, /Expires 2026-10-20 13:00:00/)
  assert.match(html, /I have shared it/)
  assert.doesNotMatch(html, /Issue temporary password/, 'the confirmation closes once the password is shown')
  const closed = render(UsersContent, base)
  assert.doesNotMatch(closed, /Abcd|data-testid="temporary-password"/)
  assert.equal(render(TemporaryPasswordResult, { result: null }), '')
  assert.match(render(TemporaryPasswordResult, { result, onClose() {} }), /Copy password/)
})
