import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { AuthShell } from '../components/ui.jsx'
import { SfIcon } from '../icons.jsx'

export default function ForgotPasswordPage() {
  const navigate = useNavigate()
  const [username, setUsername] = useState('')
  const [message, setMessage] = useState('')
  const [devCode, setDevCode] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    setMessage('')
    setDevCode('')
    setLoading(true)
    try {
      const data = await smartflow.forgotPassword(username.trim())
      setMessage(data.message || 'If that account exists, a reset code was sent.')
      const code = data.reset_code || data.code
      if (code) {
        setDevCode(String(code))
        navigate('/reset-password', { state: { username: username.trim(), code } })
      }
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not start reset')
    } finally {
      setLoading(false)
    }
  }

  return (
    <AuthShell
      layout="split"
      welcome="Account recovery"
      showPoints={false}
      body="Enter your username. A one-time code is sent if the account exists."
      strap="Password reset"
      title="Reset password"
      leading={
        <Link className="auth-split__back" to="/">
          <SfIcon name="back" size={14} stroke={2.4} />
          Back to sign in
        </Link>
      }
    >
      <form className="form-card auth-split__form" onSubmit={onSubmit}>
        {error ? <div className="error">{error}</div> : null}
        {message ? <div className="ok">{message}</div> : null}
        {devCode ? <div className="code-chip">Dev code · {devCode}</div> : null}
        <div className="field">
          <label htmlFor="forgot-user">Username</label>
          <input
            id="forgot-user"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
            autoComplete="username"
          />
        </div>
        <button className="btn btn--navy" type="submit" disabled={loading}>
          {loading ? 'Sending…' : 'Send reset code'}
        </button>
        <div className="auth-links">
          <Link to="/reset-password">Already have a code?</Link>
        </div>
      </form>
    </AuthShell>
  )
}
