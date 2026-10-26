import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'
import { emptyAccountFilters, filterAccounts, filtersActive, officeCodes } from '../src/user-directory.js'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { UsersContent } = await server.ssrLoadModule('/src/pages/AdminUsersPage.jsx')

const users = [
  { id: 1, name: 'Ana Reyes', username: 'ana_acc', email: 'ana@urbiztondo.gov.ph', office_code: 'ACC', role: 'staff', is_active: true },
  { id: 2, name: 'Ben Cruz', username: 'ben_bud', email: 'ben.cruz@example.com', office_code: 'BUD', role: 'staff', is_active: false },
  { id: 3, name: 'Carla Diaz', username: 'carla_acc', email: 'carla@example.com', office_code: 'ACC', role: 'head', is_active: true },
  { id: 4, name: 'System Admin', username: 'admin', email: 'admin@example.com', office_code: 'MAY', role: 'admin', is_active: true },
]
const names = (list) => list.map((row) => row.name)
const props = { user: { id: 4 }, users, pending: [], loading: false, busy: false, loadError: '', error: '', ok: '', selectedUser: null, setSelectedUser() {}, load() {}, decide() {}, toggleActive() {} }

test('no filter lists everyone; search needs every typed word and ignores case', () => {
  assert.equal(filterAccounts(users).length, 4)
  assert.deepEqual(names(filterAccounts(users, { ...emptyAccountFilters, query: 'ANA' })), ['Ana Reyes'])
  assert.deepEqual(names(filterAccounts(users, { ...emptyAccountFilters, query: 'acc head' })), [])
  assert.deepEqual(names(filterAccounts(users, { ...emptyAccountFilters, query: 'carla acc' })), ['Carla Diaz'])
  assert.deepEqual(names(filterAccounts(users, { ...emptyAccountFilters, query: 'example.com' })), ['Ben Cruz', 'Carla Diaz', 'System Admin'])
  assert.deepEqual(names(filterAccounts(users, { ...emptyAccountFilters, query: '   ' })).length, 4)
})

test('office, role and status narrow the list together', () => {
  assert.deepEqual(names(filterAccounts(users, { ...emptyAccountFilters, office: 'ACC' })), ['Ana Reyes', 'Carla Diaz'])
  assert.deepEqual(names(filterAccounts(users, { ...emptyAccountFilters, office: 'ACC', role: 'head' })), ['Carla Diaz'])
  assert.deepEqual(names(filterAccounts(users, { ...emptyAccountFilters, status: 'inactive' })), ['Ben Cruz'])
  assert.deepEqual(names(filterAccounts(users, { ...emptyAccountFilters, status: 'active', role: 'staff' })), ['Ana Reyes'])
})

test('office choices come from the accounts, sorted, without repeats', () => {
  assert.deepEqual(officeCodes(users), ['ACC', 'BUD', 'MAY'])
  assert.deepEqual(officeCodes(null), [])
})

test('filters count as active only when something is chosen', () => {
  assert.equal(filtersActive(emptyAccountFilters), false)
  assert.equal(filtersActive({ ...emptyAccountFilters, query: '  ' }), false)
  assert.equal(filtersActive({ ...emptyAccountFilters, status: 'active' }), true)
})

test('the directory page shows the filters above every account, with the total', () => {
  const html = renderToStaticMarkup(React.createElement(UsersContent, props))
  assert.match(html, /Find an account/)
  assert.match(html, /All offices/)
  assert.match(html, /<option value="ACC">ACC<\/option>/)
  assert.match(html, /4 accounts/)
  for (const name of ['Ana Reyes', 'Ben Cruz', 'Carla Diaz', 'System Admin']) assert.match(html, new RegExp(name))
})

test('a directory that is empty or could not be read shows no filters', () => {
  const empty = renderToStaticMarkup(React.createElement(UsersContent, { ...props, users: [] }))
  assert.doesNotMatch(empty, /Find an account/)
  assert.match(empty, /No users\./)
  const unread = renderToStaticMarkup(React.createElement(UsersContent, { ...props, users: null, loadError: 'Down' }))
  assert.doesNotMatch(unread, /Find an account/)
})
