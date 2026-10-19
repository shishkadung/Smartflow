import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { EmailChannelCard } = await server.ssrLoadModule('/src/pages/AdminSystemPage.jsx')
const { FORGOT_CONFIRMATION } = await server.ssrLoadModule('/src/pages/ForgotPasswordPage.jsx')
const render = props => renderToStaticMarkup(React.createElement(EmailChannelCard, props))
const live = { mode: 'live', configured: true, ready_for_real_delivery: true, sender_domain: 'verified.example', problems: [], last_attempt: null }

function findElement(node, predicate) {
  if (!React.isValidElement(node)) return undefined
  if (predicate(node)) return node
  return React.Children.toArray(node.props.children).map(child => findElement(child, predicate)).find(Boolean)
}

test('the email card reports the exact problem of a sandbox address that the provider rejects', () => {
  const html = render({ email: {
    mode: 'sandbox', configured: true, ready_for_real_delivery: false, sender_domain: 'urbiztondo.gov.ph',
    problems: ['Sandbox mode captures messages in a test inbox; they never reach real recipients.', 'The sandbox address has no inbox number, so the provider rejects every request (HTTP 404).'],
    last_attempt: { at: '2026-10-19 11:30:03', purpose: 'password_reset', accepted: false, http: 404 },
  } })
  assert.match(html, /Last attempt failed/)
  assert.match(html, /Sandbox \(test inbox only\)/)
  assert.match(html, /never reach real recipients/)
  assert.match(html, /rejects every request \(HTTP 404\)/)
  assert.match(html, /Last attempt \(password reset\): rejected \(HTTP 404\) · 2026-10-19 11:30:03/)
})

test('the email card distinguishes ready, not configured, unverified and no-history states', () => {
  assert.match(render({ email: live }), /Ready/)
  assert.match(render({ email: live }), /No email has been sent since this check was added/)
  assert.match(render({ email: { ...live, configured: false, mode: 'not_configured', ready_for_real_delivery: false, problems: ['No sending token is configured, so no email can be sent.'] } }), /Not configured/)
  assert.match(render({ email: { ...live, last_attempt: { at: '2026-10-19 12:00:00', purpose: 'test', accepted: true, http: 202 } } }), /Last attempt \(test email\): accepted by the provider/)
  const stale = render({ email: live, stale: true })
  assert.match(stale, /Unverified/)
  assert.doesNotMatch(stale, />Ready</)
  assert.equal(render({ email: null }), '')
})

test('the email card describes a Gmail (SMTP) channel, its missing App Password and SMTP rejection codes', () => {
  const ready = render({ email: { mode: 'gmail', configured: true, ready_for_real_delivery: true, sender_domain: 'gmail.com', problems: [],
    last_attempt: { at: '2026-10-19 13:00:00', purpose: 'test', accepted: true, http: null, code: 250 } } })
  assert.match(ready, /Gmail \(SMTP\) · sender domain gmail\.com/)
  assert.match(ready, /Ready/)
  assert.match(ready, /Last attempt \(test email\): accepted by the provider/)
  const missing = render({ email: { mode: 'gmail', configured: false, ready_for_real_delivery: false, sender_domain: 'gmail.com',
    problems: ['No Gmail App Password is configured. Gmail needs an App Password (2-Step Verification must be on), not the normal Gmail password.'], last_attempt: null } })
  assert.match(missing, /Not configured/)
  assert.match(missing, /Gmail needs an App Password/)
  const refused = render({ email: { mode: 'gmail', configured: true, ready_for_real_delivery: true, sender_domain: 'gmail.com', problems: [],
    last_attempt: { at: '2026-10-19 13:05:00', purpose: 'password_reset', accepted: false, http: null, code: 535 } } })
  assert.match(refused, /Last attempt failed/)
  assert.match(refused, /Last attempt \(password reset\): rejected \(code 535\) · 2026-10-19 13:05:00/)
  assert.match(render({ email: { ...live, mode: 'smtp' } }), /SMTP mail server/)
})

test('the test button reflects progress, shows the provider result and the call result is honest about delivery', () => {
  let clicks = 0
  const button = findElement(EmailChannelCard({ email: live, onTest() { clicks++ } }), node => node.type === 'button')
  assert.equal(button.props.disabled, false)
  button.props.onClick()
  assert.equal(clicks, 1)
  assert.match(render({ email: live }), /Send test email to my address/)
  assert.match(render({ email: live }), /does not guarantee it reaches the inbox/)
  const busy = render({ email: live, testing: true })
  assert.match(busy, /Sending test…/)
  assert.match(busy, /disabled=""/)
  const accepted = render({ email: live, result: { accepted: true, message: 'The mail provider accepted a test message for o***@x.test.' } })
  assert.match(accepted, /class="ok"[^>]*>The mail provider accepted a test message/)
  const rejected = render({ email: live, result: { accepted: false, message: 'The mail provider could not find the address it was given (HTTP 404).' } })
  assert.match(rejected, /class="error"[^>]*>The mail provider could not find the address/)
  assert.match(render({ email: live, testError: 'Your administrator account has no valid email address.' }), /role="alert">Your administrator account has no valid email address/)
})

test('the forgot-password confirmation says where the code goes and what to do when nothing arrives', () => {
  assert.match(FORGOT_CONFIRMATION, /emailed/)
  assert.match(FORGOT_CONFIRMATION, /spam/)
  assert.match(FORGOT_CONFIRMATION, /1 hour/)
  assert.match(FORGOT_CONFIRMATION, /ask your administrator/)
  assert.doesNotMatch(FORGOT_CONFIRMATION, /has been generated/)
})
