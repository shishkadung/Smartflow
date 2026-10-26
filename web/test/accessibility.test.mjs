import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { scrollBehavior } from '../src/motion.js'

const read = (path) => readFile(new URL(`../src/${path}`, import.meta.url), 'utf8')

const luminance = ([r, g, b]) => {
  const channel = (value) => { const s = value / 255; return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4 }
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
}
const contrast = (a, b) => { const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x); return (hi + 0.05) / (lo + 0.05) }
const hex = (value) => [1, 3, 5].map((i) => parseInt(value.slice(i, i + 2), 16))

test('the first Tab stop lets keyboard users skip the navigation', async () => {
  const layout = await read('components/Layout.jsx')
  const skip = layout.indexOf('className="skip-link"')
  assert.ok(skip > 0 && skip < layout.indexOf('<aside'), 'the skip link comes before the brand and navigation')
  assert.match(layout, /<main className="main" id="main-content" tabIndex=\{-1\}>/)
  assert.match(layout, /getElementById\('main-content'\)\?\.focus\(\)/)
  const css = await read('page-layout.css')
  assert.match(css, /\.app-shell \.skip-link:focus \{ transform: none;/)
})

test('phones keep a level-one heading even though the visible office heading is desktop-only', async () => {
  const layout = await read('components/Layout.jsx')
  assert.match(layout, /<h1 className="sr-only mobile-only">\{isAdmin \? 'Municipal Admin' : user\?\.office_name\}<\/h1>/)
  assert.equal([...layout.matchAll(/<h1[ >]/g)].length, 2, 'one heading per breakpoint, each hidden at the other')
  const css = await read('index.css')
  assert.match(css, /\.desktop-only \{ display: none !important; \}/)
  assert.match(css, /\.mobile-only \{ display: none !important; \}/)
})

test('an admin status banner that says the API is online meets 4.5:1', async () => {
  const css = await read('index.css')
  const color = css.match(/\.admin-status-banner--ok \{[^}]*?\bcolor: (#[0-9a-f]{6})/s)?.[1]
  assert.ok(color, 'the online banner sets a text colour')
  // Measured background when the banner sits on the profile card (tinted green over a light panel).
  assert.ok(contrast(hex(color), [218, 238, 232]) >= 4.5, `${color} on the banner background`)
})

test('focus indicators on fields, the top search and the navigation rows are full-strength blue', async () => {
  const index = await read('index.css')
  const layout = await read('page-layout.css')
  assert.match(index, /\.field input:focus, \.field select:focus, \.field textarea:focus \{\s*border-color: var\(--sf-blue\);/)
  assert.match(index, /\.top-search:focus \{\s*outline: 2px solid var\(--sf-blue\);/)
  assert.match(layout, /\.navigation-row:focus-visible \{ outline: 3px solid var\(--sf-blue\);/)
  // The brand blue itself stands out from a white page by at least 3:1.
  const blue = index.match(/--sf-blue: (#[0-9a-f]{6})/)?.[1]
  assert.ok(contrast(hex(blue), [255, 255, 255]) >= 3)
})

test('people who reduce motion get no animations, transitions or smooth scrolling', async () => {
  const css = await read('page-layout.css')
  assert.match(css, /@media \(prefers-reduced-motion: reduce\) \{\s*\*, \*::before, \*::after \{[^}]*animation-duration: 0\.01ms !important;[^}]*transition-duration: 0\.01ms !important;/)
  const original = globalThis.window
  try {
    globalThis.window = { matchMedia: (query) => ({ matches: query.includes('reduce') }) }
    assert.equal(scrollBehavior(), 'auto')
    globalThis.window = { matchMedia: () => ({ matches: false }) }
    assert.equal(scrollBehavior(), 'smooth')
    globalThis.window = {}
    assert.equal(scrollBehavior(), 'smooth')
  } finally {
    if (original === undefined) delete globalThis.window
    else globalThis.window = original
  }
  for (const page of ['pages/HeadHomePage.jsx', 'pages/AdminReportsPage.jsx']) {
    const source = await read(page)
    assert.doesNotMatch(source, /behavior: 'smooth'/, `${page} asks scrollBehavior() instead of forcing smooth scrolling`)
  }
})
