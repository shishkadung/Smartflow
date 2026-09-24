import { useEffect, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { DocTable, LifeEmpty, Overview, StatusPill } from '../components/ui.jsx'

export default function AdminUsersPage() {
  const [users, setUsers] = useState([])
  const [pending, setPending] = useState([])
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    setError('')
    try {
      const [u, p] = await Promise.all([
        smartflow.usersList(),
        smartflow.signupPending(),
      ])
      setUsers(u.users || [])
      setPending(p.requests || p.pending || [])
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not load users')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  async function toggleActive(row) {
    try {
      await smartflow.setUserActive(row.id, !row.is_active)
      setOk(`${row.username} ${row.is_active ? 'deactivated' : 'activated'}`)
      await load()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not update user')
    }
  }

  async function decide(req, action) {
    try {
      const data = await smartflow.signupApprove(req.id, action)
      setOk(data.message || `Request ${action}d`)
      await load()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not update sign-up')
    }
  }

  return (
    <div className="sf-life">
      <Overview
        title="Users & access"
        body="Approve sign-ups and activate or deactivate accounts."
      />
      {error ? <div className="error">{error}</div> : null}
      {ok ? <div className="ok">{ok}</div> : null}

      <div className="admin-grid">
        <div className="card sf-life__panel">
          <h3 className="section-title">Pending sign-ups {pending.length ? `(${pending.length})` : ''}</h3>
          {loading ? <p className="muted">Loading…</p> : null}
          {!loading && pending.length === 0 ? (
            <LifeEmpty icon="users" tone="ok">No pending requests.</LifeEmpty>
          ) : null}
          {pending.map((req) => (
            <div key={req.id} className="pending-card">
              <strong>{req.full_name || req.name}</strong>
              <span className="muted">@{req.username} · {req.office_name || req.office_code}</span>
              <StatusPill tone="warn">wants {req.requested_role}</StatusPill>
              <div className="request-card__actions">
                <button type="button" className="btn-danger" onClick={() => decide(req, 'reject')}>Reject</button>
                <button type="button" className="btn" onClick={() => decide(req, 'approve')}>Approve</button>
              </div>
            </div>
          ))}
        </div>

        <div className="card sf-life__panel">
          <h3 className="section-title">Directory</h3>
          {users.length === 0 && !loading ? (
            <LifeEmpty icon="users">No users.</LifeEmpty>
          ) : (
            <DocTable
              columns={[
                { key: 'name', label: 'Name' },
                { key: 'username', label: 'Username' },
                { key: 'office_code', label: 'Office' },
                { key: 'role', label: 'Role' },
                {
                  key: 'is_active',
                  label: 'Status',
                  render: (r) => (
                    <button type="button" className="btn-ghost" onClick={(e) => { e.stopPropagation(); toggleActive(r) }}>
                      <StatusPill tone={r.is_active ? 'ok' : 'bad'}>{r.is_active ? 'Active' : 'Inactive'}</StatusPill>
                    </button>
                  ),
                },
              ]}
              rows={users}
            />
          )}
        </div>
      </div>
    </div>
  )
}
