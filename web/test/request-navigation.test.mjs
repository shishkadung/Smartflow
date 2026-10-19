import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { createMemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'
import { requestReturnPath, requestViewFromSearch, requestViewParams } from '../src/request-navigation.js'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { RequestDetails } = await server.ssrLoadModule('/src/pages/RequestsPage.jsx')
const request = { id: 907, request_code: 'REQ-2026-0907', related_document_id: 'DOC-2026-000007', status: 'approved', requester: {}, handler_office: {} }
const user = { id: 2, role: 'staff', office_id: 1, office_code: 'ENG' }

function findLink(node, path) {
  if (!React.isValidElement(node)) return undefined
  if (node.props.to === path) return node
  return React.Children.toArray(node.props.children).map((child) => findLink(child, path)).find(Boolean)
}

test('linked folder visit returns to the committed request view and exact older selection', async () => {
  const original = '/requests?tab=outbox&filter=overdue&q=road+%26+budget&page=4&id=907'
  const view = requestViewFromSearch(original.split('?')[1])
  const link = findLink(RequestDetails({ req: request, user, returnTo: requestReturnPath(view) }), '/documents?id=DOC-2026-000007')
  assert.deepEqual(link.props.state, { requestReturnTo: original, requestCode: 'REQ-2026-0907' })
  const router = createMemoryRouter([{ path: '*', element: null }], { initialEntries: [original] })
  try {
    await router.navigate(link.props.to, { state: link.props.state })
    assert.equal(router.state.location.pathname, '/documents')
    await router.navigate(router.state.location.state.requestReturnTo)
    assert.deepEqual(requestViewFromSearch(router.state.location.search), {
      tab: 'outbox', filter: 'overdue', q: 'road & budget', page: 4, id: '907',
    })
  } finally { router.dispose() }
})

test('invalid view values do not become API filters or selected request IDs', () => {
  const view = requestViewFromSearch('?tab=admin&filter=fulfilled&page=1e9&id=-7&q=%20road%20')
  assert.deepEqual(view, { tab: 'inbox', filter: 'active', q: 'road', page: 1, id: '' })
  for (const page of ['0', '-1', '2.5', 'Infinity', '9007199254740992']) {
    assert.equal(requestViewFromSearch(`page=${page}`).page, 1)
  }
  assert.equal(requestViewFromSearch(`q=${'x'.repeat(250)}`).q.length, 200)
  assert.equal(requestViewParams(view).toString(), 'q=road')
})

test('active is the initial request view while past and explicit all survive a folder round trip', () => {
  assert.equal(requestViewFromSearch('').filter, 'active')
  for (const filter of ['active', 'past', 'all', 'pending', 'overdue']) {
    const view = { tab: 'outbox', filter, q: 'signed schedule', page: 4, id: '907' }
    const restored = requestViewFromSearch(requestReturnPath(view).split('?')[1])
    assert.deepEqual(restored, view)
  }
  assert.equal(requestViewParams({ filter: 'all' }).get('filter'), 'all')
  assert.equal(requestViewParams({ filter: 'active' }).has('filter'), false)
})

test('clearing a request selection retains its list context and busy links cannot navigate', () => {
  const view = requestViewFromSearch('?tab=outbox&filter=pending&q=drainage&page=3&id=907')
  const cleared = requestViewFromSearch(requestViewParams({ ...view, id: '' }))
  assert.deepEqual(cleared, { ...view, id: '' })
  const link = findLink(RequestDetails({ req: request, user, saving: true }), '/documents?id=DOC-2026-000007')
  assert.equal(link.props.state.requestReturnTo, '/requests?id=907')
  let prevented = false
  link.props.onClick({ preventDefault() { prevented = true } })
  assert.equal(prevented, true)
})
