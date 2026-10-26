import { after, test } from 'node:test'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { createServer } from 'vite'
import { QUEUE_PAGE_SIZE, filterQueue, queueCounts, queueState, spanLabel, waitLabel } from '../src/head-queue.js'

const server = await createServer({ server: { middlewareMode: true, hmr: false, ws: false }, appType: 'custom' })
after(() => server.close())
const { HeadDashboardContent } = await server.ssrLoadModule('/src/pages/HeadHomePage.jsx')
const render = (props) => renderToStaticMarkup(React.createElement(MemoryRouter, null, React.createElement(HeadDashboardContent, { onRetry() {}, error: '', loading: false, ...props })))

const item = (id, status_label, hours_pending, extra = {}) => ({ document_id: id, title: `Folder ${id}`, status_label, last_status: 'IN', meta: '', hours_pending, ...extra })
const sample = [
  item('DOC-A', 'completed', 10),
  item('DOC-B', 'in_office', 30),
  item('DOC-C', 'overdue', 5),
  item('DOC-D', 'on_time', 12, { last_status: 'OUT', meta: 'Forwarded from ACC · awaiting receive scan' }),
  item('DOC-E', 'overdue', 70),
  item('DOC-F', 'completed', 200),
  item('DOC-G', 'in_office', 90),
]
const ids = (list) => list.map((row) => row.document_id)

test('the default view leaves out finished folders and puts overdue first, longest wait first', () => {
  assert.deepEqual(ids(filterQueue(sample)), ['DOC-E', 'DOC-C', 'DOC-G', 'DOC-B', 'DOC-D'])
})

test('completed folders have their own view, newest first, and All still reaches everything', () => {
  assert.deepEqual(ids(filterQueue(sample, { filter: 'completed' })), ['DOC-A', 'DOC-F'])
  assert.equal(filterQueue(sample, { filter: 'all' }).length, sample.length)
  assert.deepEqual(ids(filterQueue(sample, { filter: 'all' })).slice(-2), ['DOC-A', 'DOC-F'])
})

test('Overdue, In office and Awaiting receive keep their earlier meaning', () => {
  assert.deepEqual(ids(filterQueue(sample, { filter: 'overdue' })), ['DOC-E', 'DOC-C'])
  assert.deepEqual(ids(filterQueue(sample, { filter: 'in_office' })), ['DOC-G', 'DOC-B'])
  assert.deepEqual(ids(filterQueue(sample, { filter: 'awaiting' })), ['DOC-D'])
})

test('an overdue folder that is also waiting for a receive scan stays under both filters, shown as overdue', () => {
  const both = item('DOC-H', 'overdue', 8, { last_status: 'OUT', meta: 'Document due Oct 20 · awaiting receive scan' })
  assert.equal(queueState(both), 'overdue')
  assert.deepEqual(ids(filterQueue([both], { filter: 'overdue' })), ['DOC-H'])
  assert.deepEqual(ids(filterQueue([both], { filter: 'awaiting' })), ['DOC-H'])
})

test('the other sort orders still work', () => {
  assert.deepEqual(ids(filterQueue(sample, { filter: 'all', sort: 'hoursDesc' }))[0], 'DOC-F')
  assert.deepEqual(ids(filterQueue(sample, { filter: 'all', sort: 'hoursAsc' }))[0], 'DOC-C')
  assert.deepEqual(ids(filterQueue(sample, { filter: 'all', sort: 'id' })), ['DOC-A', 'DOC-B', 'DOC-C', 'DOC-D', 'DOC-E', 'DOC-F', 'DOC-G'])
})

test('search matches the tracking ID or the title in the chosen view only', () => {
  assert.deepEqual(ids(filterQueue(sample, { query: 'doc-e' })), ['DOC-E'])
  assert.deepEqual(ids(filterQueue(sample, { query: 'DOC-F' })), [])
  assert.deepEqual(ids(filterQueue(sample, { query: 'folder doc-f', filter: 'all' })), ['DOC-F'])
})

test('counts per view match what each view lists', () => {
  const counts = queueCounts(sample)
  assert.deepEqual(counts, { active: 5, overdue: 2, in_office: 2, awaiting: 1, completed: 2, all: 7 })
  for (const filter of Object.keys(counts)) assert.equal(filterQueue(sample, { filter }).length, counts[filter])
})

test('long waits read in days, short ones in hours, and completed folders never say "waiting"', () => {
  assert.equal(spanLabel(0), '')
  assert.equal(spanLabel(5), '5h')
  assert.equal(spanLabel(47), '47h')
  assert.equal(spanLabel(48), '2d')
  assert.equal(spanLabel(99), '4d 3h')
  assert.equal(waitLabel(item('X', 'in_office', 96)), '4d waiting')
  assert.equal(waitLabel(item('X', 'in_office', 0)), 'Just recorded')
  assert.equal(waitLabel(item('X', 'completed', 3888)), 'Completed 162d ago')
  assert.equal(waitLabel(item('X', 'completed', 0)), 'Completed just now')
  assert.doesNotMatch(waitLabel(item('X', 'completed', 30)), /waiting/)
})

test('a long queue starts with one page, tells the head how many more exist and hides finished folders', () => {
  const queue = Array.from({ length: 45 }, (_, index) => item(`DOC-${String(index + 1).padStart(3, '0')}`, index < 40 ? 'in_office' : 'completed', index + 1))
  const html = render({ data: { stats: { in_office: 40, overdue: 0, avg_hours: 2 }, queue } })
  assert.equal([...html.matchAll(/class="work-card /g)].length, QUEUE_PAGE_SIZE)
  assert.match(html, /Showing 20 of 40/)
  assert.match(html, /Show 20 more/)
  assert.match(html, /Completed<span class="segmented__badge">5</)
})

test('with only finished folders the default view says so and points to Completed', () => {
  const html = render({ data: { stats: {}, queue: [item('DOC-1', 'completed', 4)] } })
  assert.match(html, /No active documents/)
  assert.match(html, /Show completed/)
  assert.doesNotMatch(html, /work-card/)
})
