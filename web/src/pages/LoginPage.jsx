import { useState } from 'react'
import { Link, Navigate, useNavigate } from 'react-router-dom'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { AuthShell } from '../components/ui.jsx'
import { homePath } from '../tracking.js'

/** Twin of Flutter Get Started + Login — same strap, pitch, fields, links, footer. */
export default function LoginPage() {
  const { isAuthenticated, user, login } = useAuth()
  const navigate = useNavigate()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  if (isAuthenticated) {
    return <Navigate to={homePath(user?.role)} replace />
  }

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const path = await login(username.trim(), password)
      navigate(path, { replace: true })
    } catch (err) {
      const msg = err instanceof ApiError
        ? err.message
        : (err?.message === 'Failed to fetch'
          ? 'Cannot connect to the municipal portal right now. Confirm the office network service is running, then try again.'
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
      strap="Official portal · Authorized users"
      title="Sign in"
      body="Secure QR handoffs and custody records for the Municipality of Urbiztondo — for accountability and COA preparation."
    >
      <form className="form-card auth-split__form" onSubmit={onSubmit}>
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
        </div>
        <button className="btn btn--navy" type="submit" disabled={loading}>
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
        <p className="auth-session-note">
          Sessions and custody events are logged for municipal accountability.
        </p>
        <div className="auth-links">
          <Link to="/forgot-password">Forgot password?</Link>
          <Link to="/signup">Request access</Link>
        </div>
      </form>
    </AuthShell>
  )
}
