import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = (path) => readFile(new URL(`../src/${path}`, import.meta.url), 'utf8')

// Everything the journey and the department bars animate is a keyframe over opacity or transform only: those run on the
// graphics card, so they stay smooth on a slow office PC. Nothing animates width, height or margin.
function keyframes(css, name) {
  const start = css.indexOf(`@keyframes ${name}`)
  assert.notEqual(start, -1, `@keyframes ${name} exists`)
  const open = css.indexOf('{', start)
  let depth = 0
  for (let i = open; i < css.length; i++) {
    if (css[i] === '{') depth++
    if (css[i] === '}' && --depth === 0) return css.slice(open + 1, i)
  }
  throw new Error(`@keyframes ${name} is not closed`)
}
const properties = (body) => [...new Set([...body.matchAll(/([a-z-]+)\s*:/g)].map((m) => m[1]))].sort()

test('the document journey appears step by step, with a capped stagger', async () => {
  const jsx = await read('components/DocumentJourney.jsx')
  assert.match(jsx, /steps\.map\(\(step, index\) =>[^]*style=\{\{ '--i': Math\.min\(index, 8\) \}\}/)
  const css = await read('sf-life.css')
  assert.match(css, /\.journey-steps li \{ animation: sf-trail-in 260ms ease-out both; animation-delay: calc\(var\(--i, 0\) \* 45ms\); \}/)
  assert.match(css, /\.journey-steps li::before \{ animation: sf-trail-dot 320ms [^;]*both; animation-delay: calc\(var\(--i, 0\) \* 45ms \+ 80ms\); \}/)
  assert.deepEqual(properties(keyframes(css, 'sf-trail-in')), ['opacity', 'transform'])
  assert.deepEqual(properties(keyframes(css, 'sf-trail-dot')), ['transform'])
})

test('department bars grow from the baseline and the numbers fade in after them', async () => {
  const jsx = await read('components/DepartmentPerformance.jsx')
  assert.match(jsx, /office\.months\.map\(\(month, index\) =>[^]*className="department-performance__bar" style=\{\{ '--n': index \}\}/)
  const css = await read('components/department-performance.css')
  assert.match(css, /__track i \{ transform-origin: bottom; animation: sf-bar-grow 480ms /)
  assert.match(css, /__track b \{ animation: sf-bar-label 240ms [^;]*both; animation-delay: calc\(var\(--n, 0\) \* 40ms \+ 300ms\); \}/)
  assert.deepEqual(properties(keyframes(css, 'sf-bar-grow')), ['transform'])
  assert.deepEqual(properties(keyframes(css, 'sf-bar-label')), ['opacity'])
  // The bar's final height still comes from the data (--v); the animation never replaces or fakes it.
  assert.match(css, /height: calc\(\(100% - var\(--top-pad\)\) \* var\(--v, 0\)\)/)
})

test('reduced motion removes the delays too, so nothing waits invisible before it appears', async () => {
  const css = await read('page-layout.css')
  const block = css.slice(css.indexOf('@media (prefers-reduced-motion: reduce)'))
  assert.match(block, /animation-delay: 0ms !important;/)
  assert.match(block, /animation-duration: 0\.01ms !important;/)
  // Every rule that adds a delay is an entrance that starts hidden, so the rule above must cover the whole app.
  assert.match(block, /\*, \*::before, \*::after \{/)
})
