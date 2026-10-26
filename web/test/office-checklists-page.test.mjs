import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'
import { HELP_PAGES, helpPageForPath } from '../src/help.js'
import { pageTitle } from '../src/page-title.js'

// Office checklists are one feature on the web and the phone: a page for heads and administrators, a place in the menus,
// and the checklist-only editor (names and required flags, no page counts or confirmation).

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
const originalStorage = globalThis.localStorage
const originalFetch = globalThis.fetch
after(async () => {
  await server.close()
  if (originalStorage === undefined) delete globalThis.localStorage
  else globalThis.localStorage = originalStorage
  globalThis.fetch = originalFetch
})
const { AuthProvider } = await server.ssrLoadModule('/src/auth.jsx')
const { default: Layout } = await server.ssrLoadModule('/src/components/Layout.jsx')
const { FolderInventoryEditor } = await server.ssrLoadModule('/src/components/FolderContents.jsx')

function desktopNavigation(role, path = '/') {
  const stored = new Map([
    ['sf_token', 'synthetic-navigation-session'],
    ['sf_user', JSON.stringify({ id: 1, role, name: 'Sample user', office_id: 1, office_code: 'ENG', office_name: 'Engineering Office' })],
  ])
  globalThis.localStorage = { getItem: key => stored.get(key) ?? null }
  globalThis.fetch = () => { throw new Error('Navigation rendering must not call the API') }
  const html = renderToStaticMarkup(React.createElement(AuthProvider, null, React.createElement(MemoryRouter, { initialEntries: [path] }, React.createElement(Layout))))
  const nav = html.match(/<nav class="nav nav--desktop"[^>]*>([\s\S]*?)<\/nav>/)?.[1] || ''
  return [...nav.matchAll(/<a\b[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/g)].map(([, href, content]) => ({ href, label: content.replace(/<[^>]*>/g, '').trim() }))
}

test('heads and administrators have Office checklists in the sidebar; staff do not', () => {
  for (const role of ['head', 'admin']) {
    assert.ok(desktopNavigation(role).some(link => link.href === '/checklists' && link.label === 'Office checklists'), role)
  }
  assert.equal(desktopNavigation('staff').some(link => link.href === '/checklists'), false)
})

test('the page has a title and its own help', () => {
  assert.equal(pageTitle('/checklists'), 'Office checklists · SmartFlow')
  assert.equal(helpPageForPath('/checklists'), 'officeChecklists')
  const guide = HELP_PAGES.officeChecklists
  assert.equal(guide.title, 'How to use Office checklists')
  assert.ok(guide.purpose && guide.steps.length >= 3)
})

const draft = {
  count_confirmed: true,
  items: [{ name: 'Main document', pages: '4', required: true }, { name: 'Receipts', pages: '2', required: false }],
}
const render = props => renderToStaticMarkup(React.createElement(FolderInventoryEditor, { value: draft, onChange() {}, ...props }))

test('the checklist editor lists attachment names and required flags only', () => {
  const html = render({ checklistOnly: true })
  assert.match(html, /<legend>Checklist attachments<\/legend>/)
  assert.match(html, /Define attachment names and which are required\. Staff enter actual page counts when registering a physical folder\./)
  assert.match(html, /placeholder="Name from your office checklist"/)
  assert.match(html, /Required attachment/)
  assert.match(html, /Remove attachment/)
  assert.match(html, /Add attachment/)
  assert.doesNotMatch(html, /Main document pages|Attachment pages|type="number"/)
  assert.doesNotMatch(html, /physically hold this folder/)
})

test('the registration contents editor is unchanged: pages and the physical confirmation', () => {
  const html = render({})
  assert.match(html, /<legend>Folder contents<\/legend>/)
  assert.match(html, /Main document pages/)
  assert.match(html, /Attachment pages/)
  assert.match(html, /I physically hold this folder and counted its contents\./)
})
