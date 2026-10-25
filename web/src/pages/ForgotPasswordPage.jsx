import { useState } from 'react'
import { Link } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { AuthShell } from '../components/ui.jsx'
import { SfIcon } from '../icons.jsx'

export const FORGOT_CONFIRMATION = 'If that account exists and has an email address on file, a one-time code was emailed to it. It can take a few minutes, so check your spam folder too. The code works for 1 hour. If nothing arrives, ask your administrator for help.'

export default function ForgotPasswordPage() {
  const [username, setUsername] = useState('')
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    setMessage('')
    setLoading(true)
    try {
      await smartflow.forgotPassword(username.trim())
      // The server answers identically for every username, so this wording is fixed here: it says where the code goes
      // and what to do when nothing arrives, without confirming that the account exists.
      setMessage(FORGOT_CONFIRMATION)
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
      body="Enter your username. A one-time code is emailed to the address on your account."
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
