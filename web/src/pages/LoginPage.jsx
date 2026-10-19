import { useState } from 'react'
import { Link, Navigate, useLocation, useNavigate } from 'react-router-dom'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { AuthShell } from '../components/ui.jsx'
import { homePath } from '../tracking.js'

export default function LoginPage() {
  const { isAuthenticated, user, login, sessionMessage } = useAuth()
  const navigate = useNavigate()
  const { state } = useLocation()
  const destination = typeof state?.from === 'string' && /^\/documents(?:\?|$)/.test(state.from) ? state.from : null
  const notice = typeof state?.notice === 'string' ? state.notice : ''
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  if (isAuthenticated) {
    return <Navigate to={destination || homePath(user?.role)} replace />
  }

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const path = await login(username.trim(), password)
      navigate(destination || path, { replace: true })
    } catch (err) {
      const msg = err instanceof ApiError
        ? err.message
        : (/^(Connection interrupted|Cannot reach|Failed to fetch)/.test(err?.message || '')
          // Sign-in records nothing, so the shared "check whether the action was recorded" wording would mislead here.
          ? 'Cannot connect to the municipal portal right now. You are not signed in. Check the office network, then try again.'
          : (err?.message || 'Could not sign in'))
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <AuthShell
      layout="split"
      welcome="Inter-office document tracking"
      strap="Office account"
      title="Sign in"
      body="Sign in with your office account to track folders and requests."
      points={[
        'Find which office holds a folder now',
        'Follow request tickets between offices',
        'Staff record handoffs; heads and administrators monitor',
      ]}
    >
      <form className="form-card auth-split__form" onSubmit={onSubmit}>
        {notice && !error && !sessionMessage ? <div className="ok" role="status">{notice}</div> : null}
        {sessionMessage && !error ? <div className="error" role="alert">{sessionMessage}</div> : null}
        {error ? <div className="error" role="alert">{error}</div> : null}
        <div className="field">
          <label htmlFor="sf-login-user">Username</label>
          <input
            id="sf-login-user"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            autoFocus
          />
        </div>
        <div className="field">
          <label htmlFor="sf-login-pass">Password</label>
          <div className="field-password">
            <input
              id="sf-login-pass"
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
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
          <div className="auth-forgot"><Link to="/forgot-password">Forgot password?</Link></div>
        </div>
        <button className="btn btn--navy" type="submit" disabled={loading}>
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
        <div className="auth-newuser">
          <span>No account yet?</span>
          <div className="auth-links">
            <Link to="/signup">Request access</Link>
            <Link to="/signup/pending">Check access request</Link>
          </div>
        </div>
        <p className="auth-session-note">Sign-ins are recorded.</p>
      </form>
    </AuthShell>
  )
}
