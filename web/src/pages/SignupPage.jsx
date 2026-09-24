import { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { AuthShell } from '../components/ui.jsx'
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
          code: data.request_code || data.code || '',
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
      chips={[{ label: 'Admin approval required', gold: true }]}
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
          <input id="signup-pass" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required minLength={8} autoComplete="new-password" />
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
        <Link className="btn btn--navy as-link" to="/" style={{ marginTop: 16 }}>
          Back to sign in
        </Link>
      </div>
    </AuthShell>
  )
}
