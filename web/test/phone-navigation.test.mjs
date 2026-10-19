import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'

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

function phoneNavigation(role, path) {
  const stored = new Map([
    ['sf_token', 'synthetic-navigation-session'],
    ['sf_user', JSON.stringify({ id: 1, role, name: 'Sample user', office_id: 1, office_code: 'ENG', office_name: 'Engineering Office' })],
  ])
  globalThis.localStorage = { getItem: key => stored.get(key) ?? null }
  globalThis.fetch = () => { throw new Error('Navigation rendering must not call the API') }
  const html = renderToStaticMarkup(React.createElement(AuthProvider, null,
    React.createElement(MemoryRouter, { initialEntries: [path] }, React.createElement(Layout))))
  const nav = html.match(/<nav class="nav nav--phone"[^>]*>([\s\S]*?)<\/nav>/)?.[1]
  assert.ok(nav, 'the real shell renders its phone navigation')
  const tabs = [...nav.matchAll(/<(a|button)\b([^>]*)>([\s\S]*?)<\/\1>/g)].map(([, tag, attributes, content]) => ({
    tag,
    href: attributes.match(/href="([^"]*)"/)?.[1],
    active: /class="[^"]*\bactive\b/.test(attributes),
    elevated: /class="[^"]*\bnav-elevated\b/.test(attributes),
    expanded: attributes.match(/aria-expanded="([^"]*)"/)?.[1],
    label: [...content.matchAll(/<span>([^<]*)<\/span>/g)].at(-1)?.[1],
  }))
  const header = html.match(/<header class="topbar">([\s\S]*?)<\/header>/)?.[1]
  const profile = header?.match(/<a\b([^>]*class="[^"]*\bprofile-launch\b[^>]*>)[\s\S]*?<\/a>/)?.[1]
  assert.ok(profile, 'phone header keeps a direct Profile link')
  return { tabs, header, profile }
}

for (const [role, labels, secondPath] of [
  ['staff', ['Home', 'Documents', 'Scan', 'Alerts', 'Menu'], '/documents'],
  ['head', ['Home', 'Queue', 'Scan', 'Alerts', 'Menu'], '/head#office-queue'],
  ['admin', ['Home', 'History', 'Reports', 'Alerts', 'Menu'], '/history'],
]) {
  test(`${role} phone Alerts stays fourth and route selection follows the reordered tabs`, () => {
    const { tabs: alerts, header, profile } = phoneNavigation(role, '/alerts')
    assert.deepEqual(alerts.map(tab => tab.label), labels)
    assert.equal(alerts[3].href, '/alerts')
    assert.deepEqual(alerts.map(tab => tab.active), [false, false, false, true, false])
    assert.deepEqual(alerts.map(tab => tab.elevated), [false, false, true, false, false])
    assert.equal(alerts[4].tag, 'button')
    assert.equal(alerts[4].href, undefined)
    assert.equal(alerts[4].expanded, 'false')
    assert.match(profile, /href="\/profile"/)
    assert.doesNotMatch(header, /aria-label="Menu/)
    const { tabs: second } = phoneNavigation(role, secondPath)
    assert.deepEqual(second.map(tab => tab.active), [false, true, false, false, false])
    assert.equal(second[1].href, secondPath)
  })

  test(`${role} phone Profile opens from the header and secondary destinations select Menu`, () => {
    const { tabs, profile } = phoneNavigation(role, '/profile')
    assert.match(profile, /class="[^"]*\bactive\b/)
    assert.deepEqual(tabs.map(tab => tab.active), [false, false, false, false, false])
    const paths = role === 'admin'
      ? ['/documents', '/requests', '/admin/users', '/admin/offices', '/admin/thresholds', '/admin/qr-monitor', '/admin/system']
      : role === 'head' ? ['/head/analytics', '/history', '/documents', '/requests'] : ['/register', '/history', '/requests']
    for (const path of paths) {
      const secondary = phoneNavigation(role, path)
      assert.deepEqual(secondary.tabs.map(tab => tab.active), [false, false, false, false, true], path)
      assert.doesNotMatch(secondary.profile, /class="[^"]*\bactive\b/)
    }
    if (role !== 'admin') {
      assert.equal(phoneNavigation(role, '/admin/users').tabs[4].active, false, 'unavailable admin destination does not select Menu')
    }
  })
}
