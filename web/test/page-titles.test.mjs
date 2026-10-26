import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { pageTitle, siteTitle } from '../src/page-title.js'

test('every page names itself in the browser tab', () => {
  assert.equal(pageTitle('/documents'), 'Documents · SmartFlow')
  assert.equal(pageTitle('/admin/reports'), 'Custody reports · SmartFlow')
  assert.equal(pageTitle('/admin/users'), 'Users & access · SmartFlow')
  assert.equal(pageTitle('/head/analytics'), 'Analytics · SmartFlow')
  assert.equal(pageTitle('/register'), 'Register folder · SmartFlow')
})

test('the three role homes are all called Dashboard', () => {
  for (const path of ['/home', '/head', '/admin']) assert.equal(pageTitle(path), 'Dashboard · SmartFlow')
})

test('a trailing slash or an unknown path never produces a wrong or broken title', () => {
  assert.equal(pageTitle('/alerts/'), 'Alerts · SmartFlow')
  assert.equal(pageTitle('/'), 'Sign in · SmartFlow')
  assert.equal(pageTitle(''), 'Sign in · SmartFlow')
  assert.equal(pageTitle(undefined), 'Sign in · SmartFlow')
  for (const path of ['/nowhere', '/constructor', '/__proto__', '/admin/unknown']) assert.equal(pageTitle(path), siteTitle)
})

test('no route in the app is left with the generic site title', async () => {
  const source = await readFile(new URL('../src/App.jsx', import.meta.url), 'utf8')
  const paths = [...source.matchAll(/<Route[^>]*?\bpath="([^"]+)"/gs)].map(match => match[1]).filter(path => path !== '*')
  assert.ok(paths.length >= 20, `found ${paths.length} routes`)
  for (const path of paths) assert.notEqual(pageTitle(path), siteTitle, `${path} needs a page title`)
})

test('different pages do not share a title, apart from the three role homes', () => {
  const titles = new Map()
  for (const path of ['/login', '/get-started', '/signup', '/signup/pending', '/signup/approved', '/forgot-password', '/reset-password', '/head/analytics', '/scan', '/documents', '/register', '/requests', '/history', '/alerts', '/profile', '/admin/users', '/admin/offices', '/admin/thresholds', '/admin/reports', '/admin/qr-monitor', '/admin/system']) {
    const title = pageTitle(path)
    assert.ok(!titles.has(title), `${path} repeats the title of ${titles.get(title)}`)
    titles.set(title, path)
  }
})
