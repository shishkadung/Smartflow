import { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { AuthShell, roleLabel } from '../components/ui.jsx'
import { SfIcon } from '../icons.jsx'

function BackLink({ to = '/' }) {
  return (
    <Link className="auth-split__back" to={to}>
      <SfIcon name="back" size={14} stroke={2.4} />
      Back to sign in
    </Link>
  )
}

export default function SignupPage() {
  const navigate = useNavigate()
  const [offices, setOffices] = useState([])
  const [fullName, setFullName] = useState('')
  const [username, setUsername] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [officeId, setOfficeId] = useState('')
  const [role, setRole] = useState('staff')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    smartflow.offices()
      .then((d) => {
        setOffices(d.offices || [])
        if (d.offices?.[0]) setOfficeId(String(d.offices[0].id))
      })
      .catch(() => setError('Could not load offices'))
  }, [])

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const data = await smartflow.signup({
        full_name: fullName.trim(),
        username: username.trim(),
        email: email.trim(),
        password,
        office_id: Number(officeId),
        requested_role: role,
      })
      navigate('/signup/pending', {
        replace: true,
        state: {
          code: data.request?.request_code || data.request_code || data.code || '',
          username: username.trim(),
          message: data.message,
        },
      })
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not submit sign-up')
    } finally {
      setLoading(false)
    }
  }

  return (
    <AuthShell
      layout="split"
      welcome="Join the portal"
      showPoints={false}
      body="Request access for your municipal office. Sign-in works only after approval."
      strap="Account request"
      title="Request access"
      note="Admin approval required"
      leading={<BackLink />}
    >
      <form className="form-card auth-split__form auth-signup" onSubmit={onSubmit}>
        {error ? <div className="error" role="alert">{error}</div> : null}
        <div className="field">
          <label htmlFor="signup-name">Full name</label>
          <input id="signup-name" value={fullName} onChange={(e) => setFullName(e.target.value)} required autoComplete="name" />
        </div>
        <div className="field">
          <label htmlFor="signup-user">Username</label>
          <input id="signup-user" value={username} onChange={(e) => setUsername(e.target.value)} required autoComplete="username" />
        </div>
        <div className="field">
          <label htmlFor="signup-email">Email</label>
          <input id="signup-email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" />
        </div>
        <div className="field">
          <label htmlFor="signup-pass">Password (8+ chars)</label>
          <div className="field-password">
            <input
              id="signup-pass"
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
          <label htmlFor="signup-office">Office</label>
          <select id="signup-office" value={officeId} onChange={(e) => setOfficeId(e.target.value)} required>
            {offices.length === 0 ? <option value="">Loading offices…</option> : null}
            {offices.map((o) => (
              <option key={o.id} value={o.id}>
                {o.code} — {o.name}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="signup-role">Requested role</label>
          <select id="signup-role" value={role} onChange={(e) => setRole(e.target.value)}>
            <option value="staff">Clerk / staff</option>
            <option value="head">Department head</option>
            <option value="admin">Municipal accountant / admin</option>
          </select>
        </div>
        <button className="btn btn--navy" type="submit" disabled={loading || !officeId}>
          {loading ? 'Submitting…' : 'Submit for approval'}
        </button>
        <div className="auth-links">
          <Link to="/">Already have an account? Sign in</Link>
        </div>
      </form>
    </AuthShell>
  )
}

export function SignupPendingPage() {
  const { state } = useLocation()
  const navigate = useNavigate()
  const [checking, setChecking] = useState(false)
  const [statusError, setStatusError] = useState('')

  async function refresh() {
    if (!state?.code && !state?.username) return
    setChecking(true)
    setStatusError('')
    try {
      const data = await smartflow.signupStatus({ code: state?.code, username: state?.username })
      const req = data.request || {}
      if (req.status === 'approved') {
        navigate('/signup/approved', { replace: true, state: req })
        return
      }
      if (req.status === 'rejected') {
        setStatusError(req.review_notes || 'This request was declined. Contact the Municipal Accountant.')
      }
    } catch (err) {
      setStatusError(err instanceof ApiError ? err.message : 'Could not check status')
    } finally {
      setChecking(false)
    }
  }

  useEffect(() => { refresh() }, [])

  return (
    <AuthShell
      layout="split"
      welcome="Request sent"
      showPoints={false}
      body={state?.message || 'Your access request is awaiting review by the Municipal Accountant.'}
      strap="Pending approval"
      title="Request received"
      leading={<BackLink />}
    >
      <div className="form-card auth-split__form">
        {state?.code ? (
          <div className="code-chip">
            <span>Request code</span>
            <strong>{state.code}</strong>
          </div>
        ) : null}
        {state?.username ? <p className="muted">Username: @{state.username}</p> : null}
        <div className="auth-note">Keep this code. You cannot sign in until an admin approves.</div>
        {statusError ? <div className="error" role="alert">{statusError}</div> : null}
        <button className="btn" type="button" onClick={refresh} disabled={checking}>
          {checking ? 'Checking…' : 'Refresh status'}
        </button>
      </div>
    </AuthShell>
  )
}

export function SignupApprovedPage() {
  const { state } = useLocation()
  const req = state || {}
  const office = [req.office_name, req.office_code ? `(${req.office_code})` : ''].filter(Boolean).join(' ')
  return (
    <AuthShell
      layout="split"
      welcome="You're all set!"
      showPoints={false}
      body="Your account is now active. Sign in to start using SmartFlow."
      strap="Approved by Admin"
      title="Account approved"
      leading={<BackLink />}
    >
      <div className="form-card auth-split__form">
        <p className="register-kv"><span>Username</span><strong>{req.username || '—'}</strong></p>
        <p className="register-kv"><span>Role</span><strong>{roleLabel(req.requested_role || 'staff')}</strong></p>
        <p className="register-kv"><span>Office</span><strong>{office || '—'}</strong></p>
        {req.approved_by_name ? <p className="register-kv"><span>Approved by</span><strong>{req.approved_by_name}</strong></p> : null}
        {req.approved_at ? <p className="register-kv"><span>Approved at</span><strong>{req.approved_at}</strong></p> : null}
        <Link className="btn as-link" to="/">Sign in now</Link>
      </div>
    </AuthShell>
  )
}
