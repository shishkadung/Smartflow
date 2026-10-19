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
  const { state } = useLocation()
  const [offices, setOffices] = useState([])
  const [fullName, setFullName] = useState('')
  const [username, setUsername] = useState(state?.username || '')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [officeId, setOfficeId] = useState('')
  const [role, setRole] = useState('staff')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [officesFailed, setOfficesFailed] = useState(false)

  // No office is preselected: an applicant must choose their own office rather than submit under the first listed one.
  useEffect(() => {
    smartflow.offices()
      .then((d) => setOffices(d.offices || []))
      .catch(() => { setOfficesFailed(true); setError('Could not load offices') })
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
          statusKey: data.status_key || '',
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
      grow
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
            <option value="">{offices.length > 0 ? 'Select your office' : officesFailed ? 'Offices unavailable' : 'Loading offices…'}</option>
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
        <button className="btn btn--navy" type="submit" disabled={loading}>
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
  const [rejected, setRejected] = useState(false)
  const [code, setCode] = useState(state?.code || '')
  const [username, setUsername] = useState(state?.username || '')
  const [statusKey, setStatusKey] = useState(state?.statusKey || '')
  const [password, setPassword] = useState('')
  const [notice, setNotice] = useState('')
  // Arriving from the Request access form carries the new code; arriving from the sign-in link is only a status check.
  const justSubmitted = Boolean(state?.code)

  async function refresh() {
    if ((!code || !statusKey) && (!username || !password)) {
      setStatusError('Enter your request code and status key. Older requests can use their username and password.')
      return
    }
    setChecking(true)
    setStatusError('')
    setNotice('')
    setRejected(false)
    try {
      const data = await smartflow.signupStatus({ code, username, statusKey, password })
      const req = data.request || {}
      if (req.status === 'approved') {
        navigate('/signup/approved', { replace: true, state: req })
        return
      }
      if (req.status === 'rejected') {
        setRejected(true)
        setStatusError(req.review_notes || 'This request was declined. Review your account details with the Municipal Accountant, then submit a new request.')
      }
    } catch (err) {
      setStatusError(err instanceof ApiError ? err.message : 'Could not check status')
    } finally {
      setPassword('')
      setChecking(false)
    }
  }

  useEffect(() => { if (state?.code && state?.statusKey) refresh() }, [])

  return (
    <AuthShell
      layout="split"
      welcome={rejected ? 'Request declined' : justSubmitted ? 'Request sent' : 'Check your request'}
      showPoints={false}
      body={rejected ? 'You can correct your details and reapply with the same username.' : justSubmitted ? (state?.message || 'Your access request is awaiting review by the Municipal Accountant.') : 'Enter the request code and private status key you received to see whether your access was approved.'}
      strap={rejected ? 'Review your details' : justSubmitted ? 'Pending approval' : 'Access request'}
      title={rejected ? 'Request declined' : justSubmitted ? 'Request received' : 'Check access request'}
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
        <div className="auth-note">Keep your request code and private status key to check approval. The request code alone does not grant access.</div>
        <div className="field"><label htmlFor="status-code">Request code</label><input id="status-code" value={code} onChange={(e) => setCode(e.target.value)} autoComplete="off" /></div>
        <div className="field"><label htmlFor="status-key">Private status key</label><input id="status-key" type="password" value={statusKey} onChange={(e) => setStatusKey(e.target.value)} autoComplete="off" /></div>
        {justSubmitted && statusKey ? <button type="button" className="btn-ghost" onClick={async () => {
          try { await navigator.clipboard.writeText(statusKey); setStatusError(''); setNotice('Status key copied. Keep it private.') }
          catch { setNotice(''); setStatusError('Could not copy the status key. Select and copy it from the field.') }
        }}>Copy private status key</button> : null}
        {notice ? <div className="hint" role="status">{notice}</div> : null}
        <details><summary>Check an older request without a status key</summary>
          <div className="field"><label htmlFor="status-user">Username</label><input id="status-user" value={username} onChange={(e) => setUsername(e.target.value)} autoComplete="username" /></div>
          <div className="field"><label htmlFor="status-password">Account password</label><input id="status-password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" /></div>
          <p className="muted">Use your submitted password before approval, or your current password after approval. It is cleared after each check.</p>
        </details>
        {statusError ? <div className="error" role="alert">{statusError}</div> : null}
        {rejected ? <Link className="btn as-link" to="/signup" state={{ username: state?.username }}>Review details and reapply</Link> : null}
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
