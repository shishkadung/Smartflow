import { useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { AuthShell } from '../components/ui.jsx'
import { SfIcon } from '../icons.jsx'
import { PASSWORDS_DO_NOT_MATCH, passwordsMatch } from '../password-rules.js'

export default function ResetPasswordPage() {
  const navigate = useNavigate()
  const { state } = useLocation()
  const [username, setUsername] = useState(state?.username || '')
  const [code, setCode] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const [loading, setLoading] = useState(false)

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    setOk('')
    if (!passwordsMatch(password, confirm)) { setError(PASSWORDS_DO_NOT_MATCH); return }
    setLoading(true)
    try {
      const data = await smartflow.resetPassword({
        username: username.trim(),
        code: code.trim(),
        new_password: password,
      })
      // Carry the confirmation to the sign-in page so it stays visible after the redirect.
      setOk(data.message || 'Password updated. You can sign in.')
      navigate('/', { replace: true, state: { notice: 'Password updated. Sign in with your new password.' } })
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not reset password')
    } finally {
      setLoading(false)
    }
  }

  return (
    <AuthShell
      layout="split"
      welcome="Account recovery"
      showPoints={false}
      body="Use the reset code from your email, then choose a new password (8+ characters)."
      strap="Password reset"
      title="New password"
      leading={
        <Link className="auth-split__back" to="/">
          <SfIcon name="back" size={14} stroke={2.4} />
          Back to sign in
        </Link>
      }
    >
      <form className="form-card auth-split__form" onSubmit={onSubmit}>
        {error ? <div className="error">{error}</div> : null}
        {ok ? <div className="ok">{ok}</div> : null}
        <div className="field">
          <label htmlFor="reset-user">Username</label>
          <input id="reset-user" value={username} onChange={(e) => setUsername(e.target.value)} required />
        </div>
        <div className="field">
          <label htmlFor="reset-code">Reset code</label>
          <input id="reset-code" value={code} onChange={(e) => setCode(e.target.value)} required />
        </div>
        <div className="field">
          <label htmlFor="reset-pass">New password (8+)</label>
          <div className="field-password">
            <input
              id="reset-pass"
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={8}
              autoComplete="new-password"
              placeholder="Enter your password"
            />
            <button
              type="button"
              className="field-password__toggle"
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? 'Hide password' : 'Show password'}
            >
              {showPassword ? 'Hide' : 'Show'}
            </button>
          </div>
        </div>
        <div className="field">
          <label htmlFor="reset-confirm">Confirm password</label>
          <div className="field-password">
            <input
              id="reset-confirm"
              type={showPassword ? 'text' : 'password'}
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              required
              autoComplete="new-password"
              placeholder="Enter your password again"
              aria-invalid={confirm !== '' && confirm !== password}
              aria-describedby={confirm !== '' && confirm !== password ? 'reset-confirm-error' : undefined}
            />
          </div>
          {confirm !== '' && confirm !== password ? <p className="field-error" id="reset-confirm-error">{PASSWORDS_DO_NOT_MATCH}</p> : null}
        </div>
        <button className="btn btn--navy" type="submit" disabled={loading}>
          {loading ? 'Saving…' : 'Update password'}
        </button>
      </form>
    </AuthShell>
  )
}
