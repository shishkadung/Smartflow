import { useCallback, useEffect, useState } from 'react'
import { ApiError } from '../api.js'
import { DocTable, LifeEmpty, Overview, StatusPill, Modal } from '../components/ui.jsx'
import { useAuth } from '../auth.jsx'

export default function AdminUsersPage() {
  const { user, smartflow } = useAuth()
  const [users, setUsers] = useState(null)
  const [pending, setPending] = useState(null)
  const [loadError, setLoadError] = useState('')
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [selectedUser, setSelectedUser] = useState(null)
  const [signupChoice, setSignupChoice] = useState(null)
  const [resetTarget, setResetTarget] = useState(null)
  const [resetResult, setResetResult] = useState(null)
  const [resetBusy, setResetBusy] = useState(false)
  const [resetError, setResetError] = useState('')
  const [manageTarget, setManageTarget] = useState(null)
  const [emailTarget, setEmailTarget] = useState(null)
  const [emailValue, setEmailValue] = useState('')
  const [emailBusy, setEmailBusy] = useState(false)
  const [emailError, setEmailError] = useState('')

  async function saveEmail() {
    if (!emailTarget || emailBusy) return
    const next = emailValue.trim()
    if (!EMAIL_PATTERN.test(next) || next.length > 120) { setEmailError('Enter a valid email address, for example name@example.com.'); return }
    setEmailBusy(true)
    setEmailError('')
    try {
      const data = await smartflow.adminSetUserEmail(emailTarget.id, next)
      setOk(data.unchanged ? `${emailTarget.username} already has that email address` : `Email address for ${emailTarget.username} updated`)
      setEmailTarget(null)
      await load()
    } catch (e) {
      setEmailError(e instanceof ApiError ? e.message : 'Could not save the email address. Check the connection and try again.')
    } finally { setEmailBusy(false) }
  }
  function closeEmail() { if (!emailBusy) { setEmailTarget(null); setEmailError('') } }

  async function confirmReset() {
    if (!resetTarget || resetBusy) return
    setResetBusy(true)
    setResetError('')
    try {
      const data = await smartflow.adminResetPassword(resetTarget.id)
      setResetResult({ name: data.user?.name || resetTarget.name, username: data.user?.username || resetTarget.username, password: data.temporary_password, expires: data.expires_at })
    } catch (e) {
      setResetError(e instanceof ApiError ? e.message : 'Could not issue a temporary password. Check the connection and try again.')
    } finally { setResetBusy(false) }
  }
  // Closing discards the temporary password from the page; it cannot be shown again.
  function closeReset() { if (!resetBusy) { setResetTarget(null); setResetResult(null); setResetError('') } }

  const load = useCallback(async () => {
    setLoading(true)
    setLoadError('')
    try {
      const [u, p] = await Promise.all([
        smartflow.usersList(),
        smartflow.signupPending(),
      ])
      setUsers(u.users || [])
      setPending(p.requests || p.pending || [])
    } catch (e) {
      setLoadError(e instanceof ApiError ? e.message : 'Could not load users')
    } finally {
      setLoading(false)
    }
  }, [smartflow])

  useEffect(() => {
    // oxlint-disable-next-line react/set-state-in-effect -- Load the remote directory and pending sign-ups when the page opens.
    load()
  }, [load])

  async function toggleActive(row) {
    if (busy || loading || loadError || row.id === user.id) return
    setBusy(true)
    setError('')
    setOk('')
    try {
      await smartflow.setUserActive(row.id, !row.is_active)
      setOk(`${row.username} ${row.is_active ? 'deactivated' : 'activated'}`)
      setSelectedUser(null)
      await load()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not update user')
    } finally { setBusy(false) }
  }

  async function decide(req, action) {
    if (busy || loading || loadError) return
    setBusy(true)
    setError('')
    try {
      const data = await smartflow.signupApprove(req.id, action)
      setOk(data.message || `Request ${action}d`)
      setSignupChoice(null)
      await load()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not update sign-up')
    } finally { setBusy(false) }
  }

  const chooseSignup = (req, action) => { if (!busy && !loading && !loadError) { setError(''); setSignupChoice({ req, action }) } }

  return <UsersContent user={user} users={users} pending={pending} loadError={loadError} error={error} ok={ok} loading={loading} busy={busy} selectedUser={selectedUser} setSelectedUser={setSelectedUser} load={load} decide={decide} toggleActive={toggleActive} signupChoice={signupChoice} setSignupChoice={setSignupChoice} chooseSignup={chooseSignup}
    emailTarget={emailTarget} emailValue={emailValue} emailBusy={emailBusy} emailError={emailError}
    manageTarget={manageTarget} onStartManage={(row) => { if (!busy && !loading && !loadError) setManageTarget(row) }} onCloseManage={() => setManageTarget(null)}
    onStartEmail={(row) => { if (!busy && !loading && !loadError) { setManageTarget(null); setEmailError(''); setEmailValue(row.email || ''); setEmailTarget(row) } }}
    onEmailChange={setEmailValue} onSaveEmail={saveEmail} onCloseEmail={closeEmail}
    resetTarget={resetTarget} resetResult={resetResult} resetBusy={resetBusy} resetError={resetError}
    onStartReset={(row) => { if (!busy && !loading && !loadError) { setManageTarget(null); setResetError(''); setResetTarget(row) } }} onConfirmReset={confirmReset} onCloseReset={closeReset} />
}

const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/
const DEFAULT_EMAIL_DOMAIN = '@urbiztondo.gov.ph'

// Addresses generated from the username were never confirmed by their owner, so the directory flags them.
export function emailNeedsCheck(row) {
  const email = String(row?.email || '').trim().toLowerCase()
  return !email || email === `${String(row?.username || '').toLowerCase()}${DEFAULT_EMAIL_DOMAIN}`
}

const TEMPORARY_PASSWORD_NOTE = 'Share it privately (in person or by phone), never by chat or email. It is shown only once, expires in 24 hours, and the user must choose a new password at their next sign-in.'

// The temporary password is displayed in groups of four so it is easy to read aloud.
export function TemporaryPasswordResult({ result, onClose }) {
  const [copied, setCopied] = useState(false)
  if (!result) return null
  async function copy() {
    try { await navigator.clipboard.writeText(result.password); setCopied(true) } catch { setCopied(false) }
  }
  return <>
    <p>Temporary password for {result.name} (@{result.username}):</p>
    <p className="temp-password" aria-label="Temporary password" data-testid="temporary-password">{String(result.password).match(/.{1,4}/g)?.join(' ')}</p>
    <div className="temp-password__actions"><button type="button" className="btn-secondary" onClick={copy}>{copied ? 'Copied' : 'Copy password'}</button></div>
    <p className="hint">{TEMPORARY_PASSWORD_NOTE}</p>
    {result.expires ? <p className="hint">Expires {result.expires}.</p> : null}
    <p className="hint">Their other sessions were signed out and the old password no longer works.</p>
    <button type="button" className="btn" onClick={onClose}>I have shared it</button>
  </>
}

export function UsersContent({ user, users, pending, loadError, error, ok, loading, busy, selectedUser, setSelectedUser, load, decide, toggleActive, signupChoice = null, setSignupChoice = () => {}, chooseSignup = null,
  resetTarget = null, resetResult = null, resetBusy = false, resetError = '', onStartReset = () => {}, onConfirmReset = () => {}, onCloseReset = () => {},
  emailTarget = null, emailValue = '', emailBusy = false, emailError = '', onStartEmail = () => {}, onEmailChange = () => {}, onSaveEmail = () => {}, onCloseEmail = () => {},
  manageTarget = null, onStartManage = () => {}, onCloseManage = () => {} }) {
  // The page asks for confirmation before granting or refusing access; callers without that wiring decide directly.
  const pick = (req, action) => (chooseSignup ? chooseSignup(req, action) : decide(req, action))
  return (
    <div className="sf-life users-page">
      <Overview
        title="Users & access"
        actions={!loadError ? <button type="button" className="btn-secondary" disabled={loading || busy} onClick={load}>Refresh users</button> : null}
      />
      {loadError ? <div className="error" role="alert"><strong>{users ? 'Refresh failed' : 'Users and sign-ups unavailable'}</strong><p>{loadError}</p>{users ? <p>Showing previously loaded accounts and sign-ups; they may be out of date. Reload before changing access.</p> : null}<button type="button" className="btn-secondary" disabled={loading || busy} onClick={load}>Retry users and sign-ups</button></div> : null}
      {error ? <div className="error" role="alert">{error}</div> : null}
      {ok ? <div className="ok" role="status">{ok}</div> : null}

      <div className="admin-grid">
        <section className="card sf-life__panel admin-signups" aria-labelledby="admin-signups-title">
          <div className="finishing-panel-heading"><h3 className="section-title" id="admin-signups-title">Pending sign-ups {!loadError && pending?.length ? `(${pending.length})` : ''}</h3><p className="muted">Review the requested office and role before granting access.</p></div>
          {loading ? <p className="muted">Loading…</p> : null}
          {!loading && !loadError && pending?.length === 0 ? (
            <LifeEmpty icon="users" tone="ok">No pending requests.</LifeEmpty>
          ) : null}
          {!loading && pending === null ? <p className="muted">Pending sign-ups have not been verified.</p> : null}
          {(pending || []).map((req) => (
            <div key={req.id} className="pending-card">
              <strong>{req.full_name || req.name}</strong>
              <span className="muted">@{req.username} · {req.office_name || req.office_code}</span>
              <span className="muted">Requested role: {req.requested_role}</span>
              <div className="request-card__actions">
                <button type="button" className="btn-danger" aria-label={`Decline sign-up for ${req.username}`} disabled={busy || loading || Boolean(loadError)} onClick={() => pick(req, 'reject')}>Decline</button>
                <button type="button" className="btn" aria-label={`Approve sign-up for ${req.username}`} disabled={busy || loading || Boolean(loadError)} onClick={() => pick(req, 'approve')}>Approve</button>
              </div>
            </div>
          ))}
        </section>

        <section className="card sf-life__panel admin-directory" aria-labelledby="admin-directory-title">
          <div className="finishing-panel-heading"><h3 className="section-title" id="admin-directory-title">Account directory</h3><p className="muted">Select an account’s status to review an access change. Existing custody records are retained.</p></div>
          {users === null ? <p className="muted">{loading ? 'Loading directory…' : 'The account directory has not been verified.'}</p> : users.length === 0 && !loading && !loadError ? (
            <LifeEmpty icon="users">No users.</LifeEmpty>
          ) : (
            <DocTable
              columns={[
                {
                  key: 'name',
                  label: 'Account',
                  render: (r) => <span className="user-account">
                    <strong className="user-account__name">{r.name}</strong>
                    <span className="user-account__meta">@{r.username} · {r.email || 'email not set'}</span>
                    {['staff', 'head'].includes(r.role) && emailNeedsCheck(r) ? <span className="user-account__meta">Check email</span> : null}
                  </span>,
                },
                { key: 'office_code', label: 'Office' },
                { key: 'role', label: 'Role' },
                {
                  key: 'is_active',
                  label: 'Status',
                  render: (r) => (
                    <button type="button" className="btn-ghost" disabled={busy || loading || Boolean(loadError) || r.id === user.id} aria-label={`${r.is_active ? 'Deactivate' : 'Activate'} ${r.username}${r.id === user.id ? ' (your account)' : ''}`} onClick={(e) => { e.stopPropagation(); setSelectedUser(r) }}>
                      <StatusPill tone={r.is_active ? 'ok' : 'bad'}>{r.is_active ? 'Active' : 'Inactive'}</StatusPill>
                    </button>
                  ),
                },
                {
                  key: 'manage',
                  label: '',
                  render: (r) => (['staff', 'head'].includes(r.role)
                    ? <button type="button" className="btn-secondary" disabled={busy || loading || Boolean(loadError) || resetBusy || emailBusy} aria-label={`Manage ${r.username}`} onClick={(e) => { e.stopPropagation(); onStartManage(r) }}>Manage</button>
                    : <span className="muted" aria-label="No administrator actions available">—</span>),
                },
              ]}
              rows={users}
            />
          )}
        </section>
      </div>
      <Modal open={!!manageTarget} title="Manage account" onClose={onCloseManage} footer={<button className="btn-secondary" type="button" onClick={onCloseManage}>Close</button>}>
        <p>{manageTarget?.name} (@{manageTarget?.username}) · {manageTarget?.office_code} · {manageTarget?.role}</p>
        <div className="manage-actions">
          <button type="button" className="btn-secondary" aria-label={`Edit email for ${manageTarget?.username}`} onClick={() => onStartEmail(manageTarget)}>Edit reset email</button>
          {manageTarget?.is_active && manageTarget?.id !== user.id
            ? <button type="button" className="btn-secondary" aria-label={`Reset password for ${manageTarget?.username}`} onClick={() => onStartReset(manageTarget)}>Reset password</button>
            : <p className="hint">Password reset is available for active accounts only.</p>}
        </div>
      </Modal>
      <Modal open={!!emailTarget} title="Edit reset email" onClose={onCloseEmail} footer={<>
        <button className="btn-secondary" type="button" disabled={emailBusy} onClick={onCloseEmail}>Cancel</button>
        <button className="btn" type="button" disabled={emailBusy} onClick={onSaveEmail}>{emailBusy ? 'Saving…' : 'Save email'}</button>
      </>}>
        <p>{emailTarget?.name} (@{emailTarget?.username}) receives the password reset code at this address.</p>
        <label className="field">Email address
          <input type="email" value={emailValue} maxLength={120} autoComplete="off" disabled={emailBusy} onChange={(e) => onEmailChange(e.target.value)} />
        </label>
        <p className="hint">Use an address the person can open. Any unused reset code sent to the old address stops working.</p>
        {emailError ? <div className="error" role="alert">{emailError}</div> : null}
      </Modal>
      <Modal open={!!resetTarget && !resetResult} title="Issue a temporary password?" onClose={onCloseReset} footer={<>
        <button className="btn-secondary" type="button" disabled={resetBusy} onClick={onCloseReset}>Cancel</button>
        <button className="btn-danger" type="button" disabled={resetBusy} onClick={onConfirmReset}>{resetBusy ? 'Issuing…' : 'Issue temporary password'}</button>
      </>}>
        <p>{resetTarget?.name} (@{resetTarget?.username}) will be signed out everywhere and their current password will stop working. You will see a temporary password once.</p>
        <p className="hint">Use this only when the emailed reset code does not reach the user. Prefer the Forgot password email when it works.</p>
        {resetError ? <div className="error" role="alert">{resetError}</div> : null}
      </Modal>
      <Modal open={!!resetResult} title="Temporary password" onClose={onCloseReset}>
        <TemporaryPasswordResult result={resetResult} onClose={onCloseReset} />
      </Modal>
      <Modal open={!!signupChoice} title={signupChoice?.action === 'approve' ? 'Approve sign-up?' : 'Decline sign-up?'} onClose={() => { if (!busy) setSignupChoice(null) }} footer={<>
        <button className="btn-secondary" type="button" disabled={busy} onClick={() => setSignupChoice(null)}>Cancel</button>
        <button className={signupChoice?.action === 'approve' ? 'btn' : 'btn-danger'} type="button" disabled={busy || loading || Boolean(loadError)} onClick={() => decide(signupChoice.req, signupChoice.action)}>{busy ? 'Saving…' : signupChoice?.action === 'approve' ? 'Approve' : 'Decline'}</button>
      </>}>
        <p>{signupChoice?.action === 'approve'
          ? `${signupChoice?.req?.full_name || signupChoice?.req?.name} (@${signupChoice?.req?.username}) will be able to sign in as ${signupChoice?.req?.requested_role} at ${signupChoice?.req?.office_name || signupChoice?.req?.office_code}.`
          : `${signupChoice?.req?.full_name || signupChoice?.req?.name} (@${signupChoice?.req?.username}) will not receive access. They would need to submit a new request.`}</p>
        {error ? <div className="error" role="alert">{error}</div> : null}
      </Modal>
      <Modal open={!!selectedUser} title={selectedUser?.is_active ? 'Deactivate account?' : 'Activate account?'} onClose={() => { if (!busy) setSelectedUser(null) }} footer={<>
        <button className="btn-secondary" type="button" disabled={busy} onClick={() => setSelectedUser(null)}>Cancel</button>
        <button className={selectedUser?.is_active ? 'btn-danger' : 'btn'} type="button" disabled={busy || loading || Boolean(loadError)} onClick={() => toggleActive(selectedUser)}>{busy ? 'Saving…' : selectedUser?.is_active ? 'Deactivate' : 'Activate'}</button>
      </>}>
        <p>{selectedUser?.name} (@{selectedUser?.username}) {selectedUser?.is_active ? 'will lose access to SmartFlow. Existing custody records stay in the audit trail.' : 'will be able to sign in to SmartFlow again.'}</p>
        {error ? <div className="error" role="alert">{error}</div> : null}
      </Modal>
    </div>
  )
}
