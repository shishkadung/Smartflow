import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'
import { NEW_PASSWORD_MISMATCH, PASSWORDS_DO_NOT_MATCH, passwordsMatch } from '../src/password-rules.js'

// Wherever the phone asks for a new password twice, the web asks twice too, with the same wording.

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { default: SignupPage } = await server.ssrLoadModule('/src/pages/SignupPage.jsx')
const { default: ResetPasswordPage } = await server.ssrLoadModule('/src/pages/ResetPasswordPage.jsx')
const render = Component => renderToStaticMarkup(React.createElement(MemoryRouter, null, React.createElement(Component)))

test('the messages are the phone\'s', () => {
  assert.equal(PASSWORDS_DO_NOT_MATCH, 'Passwords do not match')
  assert.equal(NEW_PASSWORD_MISMATCH, 'New password and confirmation do not match.')
  assert.equal(passwordsMatch('abc12345', 'abc12345'), true)
  assert.equal(passwordsMatch('abc12345', 'abc12346'), false)
  assert.equal(passwordsMatch('abc12345', ''), false)
})

test('sign-up and reset-by-code both ask for the password a second time', () => {
  for (const [name, Page, id] of [['sign-up', SignupPage, 'signup'], ['reset', ResetPasswordPage, 'reset']]) {
    const html = render(Page)
    assert.match(html, new RegExp(`<label for="${id}-confirm">Confirm password</label>`), name)
    assert.match(html, new RegExp(`<input id="${id}-confirm"[^>]*type="password"[^>]*required=""`), name)
    assert.doesNotMatch(html, /Passwords do not match/, `${name}: no complaint before anything is typed`)
  }
})
