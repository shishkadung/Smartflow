import { useAuth } from '../auth.jsx'
import { useEffect, useState } from 'react'

import { connectionSnapshot, reportConnection } from '../connection.js'

export default function ConnectionBanner() {
  const { api } = useAuth()
  const [connection, setConnection] = useState(connectionSnapshot)
  const [checking, setChecking] = useState(false)
  useEffect(() => {
    const changed = () => setConnection(connectionSnapshot())
    const offline = () => reportConnection(true)
    window.addEventListener('sf-connection-change', changed)
    window.addEventListener('offline', offline)
    return () => { window.removeEventListener('sf-connection-change', changed); window.removeEventListener('offline', offline) }
  }, [])
  if (!connection.unavailable) return null
  async function retry() {
    setChecking(true)
    try { await api('auth-session.php'); window.dispatchEvent(new CustomEvent('sf-refresh-requested')) } catch { /* Banner remains until a successful connection. */ }
    finally { setChecking(false) }
  }
  return <div className="connection-banner" role="status"><div><strong>Portal connection unavailable</strong><p>Displayed information may be outdated.{connection.lastSuccess ? ` Last contact: ${new Date(connection.lastSuccess).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}.` : ''} Refresh before making a handoff.</p></div><button type="button" disabled={checking} onClick={retry}>{checking ? 'Checking…' : 'Retry connection'}</button></div>
}
