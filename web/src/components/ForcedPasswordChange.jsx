import { useState } from 'react'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { AuthShell } from './ui.jsx'

// Shown instead of every page while an administrator-issued temporary password is still in use.
// The server refuses all other requests until the password has been replaced.
export default function ForcedPasswordChange() {
  const { token, smartflow, endSession, logout, user } = useAuth()
  const [current, setCurrent] = useState('')
  const [next, setNext] = useState('')
  const [confirm, setConfirm] = useState('')
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  async function submit(e) {
    e.preventDefault()
    setError('')
    if (next.length < 8) { setError('Choose a password of at least 8 characters.'); return }
    if (next !== confirm) { setError('The two new passwords do not match.'); return }
    if (next === current) { setError('Choose a password different from the temporary one.'); return }
    setSaving(true)
    try {
      const data = await smartflow.changePassword(current, next)
      endSession(token, data.message || 'Password changed. Sign in again with your new password.')
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not change the password. Check the connection and try again.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <AuthShell
      layout="split"
      welcome="Security"
      showPoints={false}
      strap="Security"
      title="Choose a new password"
      body={`${user?.name ? `${user.name}, your` : 'Your'} administrator gave you a temporary password. Choose your own password to continue.`}
    >
      <form className="form-card auth-split__form" onSubmit={submit}>
        {error ? <div className="error" role="alert">{error}</div> : null}
        <div className="field">
          <label htmlFor="forced-current">Temporary password</label>
          <input id="forced-current" type="password" autoComplete="current-password" value={current} onChange={(e) => setCurrent(e.target.value)} required />
        </div>
        <div className="field">
          <label htmlFor="forced-new">New password (8+ characters)</label>
          <input id="forced-new" type="password" autoComplete="new-password" minLength={8} value={next} onChange={(e) => setNext(e.target.value)} required />
        </div>
        <div className="field">
          <label htmlFor="forced-confirm">Repeat the new password</label>
          <input id="forced-confirm" type="password" autoComplete="new-password" value={confirm} onChange={(e) => setConfirm(e.target.value)} required />
        </div>
        <button className="btn btn--navy" type="submit" disabled={saving}>{saving ? 'Saving…' : 'Save new password'}</button>
        <div className="auth-links"><button type="button" className="btn-ghost" onClick={() => logout().catch(() => {})}>Log out</button></div>
        <p className="auth-session-note">You will sign in again with the new password.</p>
      </form>
    </AuthShell>
  )
}
