import { useAuth } from '../auth.jsx'
import { useCallback, useEffect, useState } from 'react'
import { ApiError } from '../api.js'
import { LifeEmpty, Overview, StatusPill, statTone } from '../components/ui.jsx'

const EMAIL_MODES = { gmail: 'Gmail (SMTP)', smtp: 'SMTP mail server', live: 'Live sending', sandbox: 'Sandbox (test inbox only)', custom: 'Custom provider address', not_configured: 'Not configured' }

function emailHealth(email) {
  if (!email?.configured) return { tone: 'bad', label: 'Not configured' }
  if (email.last_attempt && !email.last_attempt.accepted) return { tone: 'bad', label: 'Last attempt failed' }
  return email.ready_for_real_delivery ? { tone: 'ok', label: 'Ready' } : { tone: 'warn', label: 'Needs attention' }
}

// Secret-free health of the password-reset email channel, so a broken setup is found before a user is locked out.
export function EmailChannelCard({ email, testing = false, result = null, testError = '', onTest = () => {}, stale = false }) {
  if (!email) return null
  const health = emailHealth(email)
  const last = email.last_attempt
  return <div className="card sf-life__panel admin-email-channel">
    <div className="admin-system-row">
      <div>
        <strong>Password reset email</strong>
        <p className="muted">{EMAIL_MODES[email.mode] || 'Unknown'}{email.sender_domain ? ` · sender domain ${email.sender_domain}` : ''}</p>
      </div>
      <StatusPill tone={stale ? 'warn' : health.tone}>{stale ? 'Unverified' : health.label}</StatusPill>
    </div>
    {email.problems?.length ? <ul className="admin-email-channel__problems">{email.problems.map((problem) => <li key={problem}>{problem}</li>)}</ul> : null}
    <p className="muted admin-email-channel__last">
      {last
        ? `Last attempt (${last.purpose === 'test' ? 'test email' : 'password reset'}): ${last.not_configured ? 'not sent, no token configured' : last.accepted ? 'accepted by the provider' : `rejected${last.http ? ` (HTTP ${last.http})` : last.code ? ` (code ${last.code})` : ''}`} · ${last.at}`
        : 'No email has been sent since this check was added.'}
    </p>
    {testError ? <div className="error" role="alert">{testError}</div> : null}
    {result ? <div className={result.accepted ? 'ok' : 'error'} role="status">{result.message}</div> : null}
    <button type="button" className="btn-secondary" disabled={testing} onClick={onTest}>{testing ? 'Sending test…' : 'Send test email to my address'}</button>
    <p className="hint">The test goes to your own email address on file. A provider that accepts a message does not guarantee it reaches the inbox, so confirm it arrived.</p>
  </div>
}

export default function AdminSystemPage() {
  const { smartflow } = useAuth()
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [loadedAt, setLoadedAt] = useState(null)
  const [testing, setTesting] = useState(false)
  const [testResult, setTestResult] = useState(null)
  const [testError, setTestError] = useState('')

  async function sendTestEmail() {
    if (testing) return
    setTesting(true)
    setTestResult(null)
    setTestError('')
    try {
      const result = await smartflow.systemEmailTest()
      setTestResult(result)
      if (result.email) setData((current) => (current ? { ...current, email: result.email } : current))
    } catch (e) {
      setTestError(e instanceof ApiError ? e.message : 'Could not send the test email. Check the connection and try again.')
    } finally {
      setTesting(false)
    }
  }

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const d = await smartflow.systemStatus()
      setData(d)
      setLoadedAt(new Date())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not load system status')
    } finally {
      setLoading(false)
    }
  }, [smartflow])

  // oxlint-disable-next-line react/set-state-in-effect -- Fetch the current server status before presenting it.
  useEffect(() => { load() }, [load])

  const st = data?.status || {}
  const ops = data?.operations || {}
  const users = data?.users || {}
  const roles = data?.role_counts || {}
  const apiOk = String(st.api || '').startsWith('On')
  const stale = Boolean(data) && (loading || Boolean(error))

  return (
    <div className="sf-life system-page">
      <Overview
        title="System"
        actions={<button type="button" className="btn-secondary" onClick={load} disabled={loading}>{loading ? 'Refreshing…' : 'Refresh status'}</button>}
      />
      {error ? <div className="error" role="alert">
        <strong>{data ? 'Status refresh failed' : 'System status unavailable'}</strong>
        <p>{error}</p>
        <p>{data ? 'Showing the last successful check; current health and counts are unverified.' : 'API and database health could not be checked. Retry with Refresh status.'}</p>
      </div> : null}
      {loading && data && !error ? <p className="hint" role="status">Checking current health. Showing the last successful check; health and counts are unverified.</p> : null}
      {loadedAt ? (
        <p className="muted admin-home__sync">
          {stale ? 'Last successful check' : 'Updated'} {loadedAt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
        </p>
      ) : null}

      {loading && !data ? <p className="muted">Loading…</p> : null}
      {!loading && !data ? (
        <LifeEmpty icon="system">Status unavailable.</LifeEmpty>
      ) : null}

      {data ? (
        <>
          <div className="admin-system-grid">
            <div className="card sf-life__panel admin-system-row">
              <div>
                <strong>API / PHP</strong>
                <p className="muted">{stale ? 'Last reported: ' : ''}{st.api || '—'}</p>
                <p className="muted">{st.php_version || ''}</p>
              </div>
              <StatusPill tone={stale ? 'warn' : apiOk ? 'ok' : 'bad'}>{stale ? 'Unverified' : apiOk ? 'online' : 'offline'}</StatusPill>
            </div>
            <div className="card sf-life__panel">
              <strong>MySQL</strong>
              <p className="muted">
                {st.mysql_version || '—'} · {st.documents ?? 0} documents in DB
              </p>
            </div>
            {users ? (
              <div className="card sf-life__panel">
                <strong>Accounts by role</strong>
                <p className="muted">
                  {roles.staff ?? 0} clerks · {roles.head ?? 0} heads · {roles.admin ?? 0} admin
                </p>
              </div>
            ) : null}
            <div className="stats sf-life__stats">
              <div className={statTone(users.active ?? ops.pending_signups ?? 0, 'stat--desk')}>
                <b>{users.active ?? ops.pending_signups ?? 0}</b>
                <span>Active users</span>
              </div>
              <div className={statTone(ops.movements_today ?? 0, 'stat--in')}>
                <b>{ops.movements_today ?? 0}</b>
                <span>Movements today</span>
              </div>
            </div>
            <div className="card sf-life__panel">
              <strong>Flagged documents</strong>
              <p className="muted">{ops.flagged_total ?? 0} total in system</p>
            </div>
          </div>
          <EmailChannelCard email={data.email} testing={testing} result={testResult} testError={testError} onTest={sendTestEmail} stale={stale} />
        </>
      ) : null}
    </div>
  )
}
