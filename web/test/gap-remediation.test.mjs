import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'
import { clerkScanActions, movementNote } from '../src/tracking.js'
import { beginScopedRead, failScopedRead, scopedReadView } from '../src/scoped-read.js'
import { requestReturnPath, requestViewFromSearch } from '../src/request-navigation.js'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { HistoryTimeline } = await server.ssrLoadModule('/src/pages/HistoryPage.jsx')
const { UsersContent } = await server.ssrLoadModule('/src/pages/AdminUsersPage.jsx')
const { ReportOfficeTotals } = await server.ssrLoadModule('/src/pages/AdminReportsPage.jsx')
const { CoaSummaryHero } = await server.ssrLoadModule('/src/components/ui.jsx')
const render = (Component, props) => renderToStaticMarkup(React.createElement(Component, props))

function findElement(node, predicate) {
  if (!React.isValidElement(node)) return undefined
  if (predicate(node)) return node
  return React.Children.toArray(node.props.children).map(child => findElement(child, predicate)).find(Boolean)
}

test('history preserves receipt counts and full multiline reasons appended to boilerplate', () => {
  const reason = 'Two signed supporting pages were missing.\nThe receiving clerk counted the physical folder.'
  const receipt = `Incomplete contents: 3/5 registered pages; Signed supporting schedule: 1/3 pages; ${reason}`
  const movement = { id: 12, status: 'IN', office_name: 'Accounting Office', user_name: 'Receiving clerk', scanned_at: '2026-10-15 08:00:00' }
  for (const prefix of ['Registered and received at origin office', 'Received at Accounting Office']) {
    const remarks = `${prefix}\n${receipt}`
    assert.equal(movementNote({ ...movement, remarks }).note, remarks)
    const html = render(HistoryTimeline, { movements: [{ ...movement, remarks }] })
    assert.ok(html.includes(receipt), 'the complete counted receipt and both reason lines remain visible')
  }
  const boilerplate = render(HistoryTimeline, { movements: [{ ...movement, remarks: 'Received at Accounting Office' }] })
  assert.doesNotMatch(boilerplate, /timeline__note/)
})

test('history shows who filed a completed folder, and keeps the step when the filer was not recorded', () => {
  const movement = { id: 30, status: 'IN', office_name: 'Budget Office', user_name: 'Receiving clerk', scanned_at: '2026-10-19 00:52:00' }
  const filed = render(HistoryTimeline, {
    document: { filed_by: { filed_at: '2026-10-19 00:52:35', name: 'Buenaventura, Angel A.', office_name: 'Budget Office' } },
    movements: [movement],
  })
  assert.match(filed, /Filed at Budget Office/)
  assert.match(filed, /Buenaventura, Angel A\./)
  assert.ok(filed.indexOf('Received at Budget Office') < filed.indexOf('Filed at Budget Office'), 'filing follows the receipt chronologically')
  const legacy = render(HistoryTimeline, { document: { filed_by: { filed_at: '2026-10-19 00:52:35', name: null } }, movements: [movement] })
  assert.match(legacy, /Filed/)
  assert.match(legacy, /name not recorded/)
  assert.doesNotMatch(render(HistoryTimeline, { document: { filed_by: null }, movements: [movement] }), /Filed/)
})

test('return history retains all reason lines and clerk notes are not mistaken for boilerplate', () => {
  const reason = 'Missing signed schedule.\nReturn the complete supporting folder.'
  const remarks = `Returned to Budget Office (BUD): ${reason}`
  assert.deepEqual(movementNote({ remarks }), { isReturn: true, returnedTo: 'Budget Office (BUD)', note: reason })
  const html = render(HistoryTimeline, { movements: [{ id: 13, status: 'OUT', office_name: 'Accounting Office', destination_office_name: 'Budget Office', remarks }] })
  assert.ok(html.includes(reason))
  for (const note of ['Received at Accounting Office after checking the signed copy.', 'Forwarded from Accounting Office → Budget Office (BUD)\nKeep the original schedules together.']) {
    assert.equal(movementNote({ office_name: 'Accounting Office', destination_office_name: 'Budget Office', destination_office_code: 'BUD', remarks: note }).note, note)
  }
})

test('Scan permits only the effective OUT receiver after a destination correction', () => {
  const out = { lastStatus: 'OUT', lastOfficeId: 1, currentOfficeName: 'Engineering Office', destinationOfficeId: 2, destinationOfficeName: 'Budget Office' }
  const oldReceiver = clerkScanActions({ ...out, myOfficeId: 2 })
  assert.equal(oldReceiver.canIn, true)
  const wrongReceiver = clerkScanActions({ ...out, myOfficeId: 3 })
  assert.equal(wrongReceiver.canIn, false)
  assert.equal(wrongReceiver.canOut, false)
  assert.match(wrongReceiver.blockReason, /Sent to Budget Office.*Only that receiving office can confirm receipt.*sending office to correct it/)
  const corrected = { ...out, destinationOfficeId: '3', destinationOfficeName: 'Accounting Office' }
  assert.equal(clerkScanActions({ ...corrected, myOfficeId: 2 }).canIn, false)
  assert.equal(clerkScanActions({ ...corrected, myOfficeId: 3 }).canIn, true)
  assert.equal(clerkScanActions({ ...corrected, myOfficeId: 1 }).canIn, false)
  for (const role of ['head', 'admin']) {
    const actions = clerkScanActions({ ...corrected, myOfficeId: 3, role })
    assert.equal(actions.canIn, false)
    assert.equal(actions.canOut, false)
  }
})

const updated = new Date('2026-10-15T08:00:00Z')
const requestKey = (search, user = 8, office = 3) => {
  const { tab, filter, q, page } = requestViewFromSearch(search.split('?').at(-1))
  return JSON.stringify([user, office, tab, filter, q, page])
}
const snapshot = (key, data) => ({ key, data, updated, error: '', loading: false })

test('Active/Past and Back isolate snapshots; only a same-query failed refresh retains rows and update evidence', () => {
  const activeView = requestViewFromSearch('?tab=outbox&q=road&page=2&id=7')
  const activeKey = requestKey(requestReturnPath(activeView))
  const pastKey = requestKey('?tab=outbox&filter=past&q=road&page=2')
  const active = snapshot(activeKey, { outbox: [{ id: 7, status: 'approved' }] })
  const pastLoading = beginScopedRead(active, pastKey)
  assert.equal(pastLoading.data, null)
  assert.equal(pastLoading.updated, null)
  const failedPast = failScopedRead(pastLoading, pastKey, 'Past requests could not be loaded')
  assert.equal(failedPast.data, null)
  assert.equal(failedPast.updated, null)
  const past = snapshot(pastKey, { outbox: [{ id: 9, status: 'fulfilled' }] })
  const backKey = requestKey(requestReturnPath(activeView))
  assert.equal(backKey, activeKey)
  assert.equal(scopedReadView(past, backKey).data, null, 'Back cannot show Past rows under Active')
  const failedBack = failScopedRead(beginScopedRead(past, backKey), backKey, 'Connection lost')
  assert.equal(failedBack.data, null)
  assert.equal(failedBack.updated, null)
  const sameQueryFailure = failScopedRead(beginScopedRead(active, activeKey), activeKey, 'Connection lost')
  assert.equal(sameQueryFailure.data, active.data)
  assert.equal(sameQueryFailure.updated, updated, 'the last successful update remains available for stale labeling')
  assert.equal(sameQueryFailure.error, 'Connection lost')
  assert.equal(sameQueryFailure.loading, false)
  assert.equal(active.error, '', 'a failed refresh does not mutate the successful snapshot')
})

test('request query, page, office and account changes cannot retain another view; selection alone can', () => {
  const key = requestKey('?q=road&id=7')
  const previous = snapshot(key, { inbox: [{ id: 7 }] })
  assert.equal(scopedReadView(previous, requestKey('?q=road&id=9')), previous)
  const changes = [requestKey('?tab=outbox&q=road'), requestKey('?filter=past&q=road'), requestKey('?q=budget'), requestKey('?q=road&page=2'), requestKey('?q=road', 9), requestKey('?q=road', 8, 2)]
  for (const changedKey of changes) {
    const failed = failScopedRead(previous, changedKey, 'Unavailable')
    assert.equal(failed.data, null)
    assert.equal(failed.updated, null)
    assert.equal(failed.error, 'Unavailable')
  }
})

test('municipal office changes and failed Back reads never reuse the wrong office snapshot', () => {
  const key = office => JSON.stringify([8, 3, true, office])
  const engineering = snapshot(key('1'), [{ id: 'DOC-2026-000001', current_office_id: 1 }])
  const budget = snapshot(key('2'), [{ id: 'DOC-2026-000002', current_office_id: 2 }])
  for (const nextOffice of ['2', '']) {
    const failed = failScopedRead(beginScopedRead(engineering, key(nextOffice)), key(nextOffice), 'Office documents unavailable')
    assert.equal(failed.data, null)
    assert.equal(failed.updated, null)
  }
  assert.equal(scopedReadView(budget, key('1')).data, null)
  const retained = failScopedRead(beginScopedRead(budget, key('2')), key('2'), 'Refresh failed')
  assert.equal(retained.data, budget.data)
  assert.equal(retained.updated, updated)
  const empty = failScopedRead(snapshot(key('2'), []), key('2'), 'Refresh failed')
  assert.deepEqual(empty.data, [])
  assert.equal(empty.error, 'Refresh failed', 'a retained empty list still carries the failed verification')
})

test('unavailable report counts and office totals differ from a verified empty report', () => {
  const unknown = render(CoaSummaryHero, { monthLabel: 'October 2026', docsInPeriod: null })
  assert.match(unknown, /Activity count not verified/)
  assert.doesNotMatch(unknown, /0 documents with activity/)
  const zero = render(CoaSummaryHero, { monthLabel: 'October 2026', docsInPeriod: 0 })
  assert.match(zero, /0 documents with activity/)
  assert.doesNotMatch(zero, /Activity count not verified/)
  const unavailable = render(ReportOfficeTotals, { data: null, loading: false, periodNoun: 'month' })
  assert.match(unavailable, /Office totals are unavailable until the report loads/)
  assert.doesNotMatch(unavailable, /No office totals/)
  const loading = render(ReportOfficeTotals, { data: null, loading: true, periodNoun: 'month' })
  assert.match(loading, /Loading office totals/)
  assert.doesNotMatch(loading, /No office totals/)
  const verified = render(ReportOfficeTotals, { data: { office_totals: [] }, loading: false, periodNoun: 'quarter' })
  assert.match(verified, /No office totals for this quarter/)
})

const usersProps = { user: { id: 8 }, users: null, pending: null, loading: false, busy: false, loadError: '', error: '', ok: '', selectedUser: null, setSelectedUser() {}, load() {}, decide() {}, toggleActive() {} }

test('failed initial users read exposes a working retry without empty directory or healthy pending state', () => {
  let retries = 0
  const props = { ...usersProps, loadError: 'Connection interrupted', load() { retries++ } }
  const html = render(UsersContent, props)
  assert.match(html, /Users and sign-ups unavailable/)
  assert.match(html, /Connection interrupted/)
  assert.match(html, /Pending sign-ups have not been verified/)
  assert.match(html, /account directory has not been verified/)
  assert.doesNotMatch(html, /No pending requests|No users\.|sf-life__empty-icon--ok/)
  const retry = findElement(UsersContent(props), node => node.type === 'button' && node.props.children === 'Retry users and sign-ups')
  assert.ok(retry)
  assert.equal(retry.props.disabled, false)
  retry.props.onClick()
  assert.equal(retries, 1)
})

test('failed users refresh retains accounts but blocks access changes and suppresses stale empty all-clears', () => {
  const account = { id: 9, name: 'Budget clerk', username: 'budget_clerk', office_code: 'BUD', role: 'staff', is_active: true }
  const pending = [{ id: 17, full_name: 'Applicant', username: 'applicant', office_code: 'ENG', requested_role: 'staff' }]
  const props = { ...usersProps, users: [account], pending, loadError: 'Connection lost', selectedUser: account }
  const html = render(UsersContent, props)
  assert.match(html, /Refresh failed/)
  assert.match(html, /previously loaded accounts and sign-ups; they may be out of date/)
  assert.match(html, /Budget clerk/)
  assert.match(html, /Applicant/)
  assert.match(html, /disabled="" aria-label="Deactivate budget_clerk"/)
  for (const action of ['Decline', 'Approve', 'Deactivate']) assert.match(html, new RegExp(`disabled="">${action}</button>`))
  const empty = render(UsersContent, { ...usersProps, users: [], pending: [], loadError: 'Connection lost' })
  assert.match(empty, /Refresh failed/)
  assert.doesNotMatch(empty, /No pending requests|No users\.|sf-life__empty-icon--ok/)
  const recoveredProps = { ...props, loadError: '', selectedUser: null }
  const recovered = render(UsersContent, recoveredProps)
  const approve = findElement(UsersContent(recoveredProps), node => node.type === 'button' && node.props['aria-label'] === 'Approve sign-up for applicant')
  assert.ok(approve)
  assert.equal(approve.props.disabled, false)
  assert.equal(approve.props.children, 'Approve')
  assert.doesNotMatch(recovered, /Refresh failed|may be out of date/)
})

test('sign-up decisions ask for confirmation before granting or refusing access', () => {
  const req = { id: 5, full_name: 'Test Applicant', username: 'applicant', office_name: 'Engineering Office', requested_role: 'staff' }
  const calls = []
  const props = { ...usersProps, users: [], pending: [req], decide: (...args) => calls.push(['decide', ...args]), chooseSignup: (...args) => calls.push(['choose', ...args]) }
  const approve = findElement(UsersContent(props), node => node.type === 'button' && node.props['aria-label'] === 'Approve sign-up for applicant')
  approve.props.onClick()
  assert.deepEqual(calls, [['choose', req, 'approve']], 'Approve opens the confirmation instead of deciding immediately')
  const html = render(UsersContent, { ...props, signupChoice: { req, action: 'approve' } })
  assert.match(html, /Approve sign-up\?/)
  assert.match(html, /will be able to sign in as staff at Engineering Office/)
  const decline = render(UsersContent, { ...props, signupChoice: { req, action: 'reject' } })
  assert.match(decline, /Decline sign-up\?/)
  assert.match(decline, /will not receive access/)
})

test('successful empty users reads preserve the verified empty states', () => {
  const html = render(UsersContent, { ...usersProps, users: [], pending: [] })
  assert.match(html, /No pending requests\./)
  assert.match(html, /No users\./)
  assert.doesNotMatch(html, /unavailable|not been verified|Refresh failed/)
})
