import { test } from 'node:test'
import assert from 'node:assert/strict'
import { clerkScanActions } from '../src/tracking.js'

test('only staff receive or send from the same custody snapshot', () => {
  for (const snapshot of [
    { lastStatus: 'IN', lastOfficeId: 1 },
    { lastStatus: 'OUT', lastOfficeId: 2 },
    { lastStatus: null, lastOfficeId: null },
  ]) {
    const context = { ...snapshot, myOfficeId: 1, currentOfficeName: 'Engineering Office' }
    const staff = clerkScanActions({ ...context, role: 'staff' })
    assert.ok(staff.canIn || staff.canOut)
    for (const role of ['head', 'admin', 'auditor']) {
      const monitor = clerkScanActions({ ...context, role })
      assert.equal(monitor.canIn, false)
      assert.equal(monitor.canOut, false)
      assert.match(monitor.blockReason, /Read-only custody/)
    }
  }
})
