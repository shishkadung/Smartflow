import { createContext, Fragment, useContext, useEffect, useMemo, useRef, useState } from 'react'
import { ApiError, createSessionClient, smartflow } from './api.js'
import { homePath } from './tracking.js'

const AuthContext = createContext(null)

function loadUser() {
  try {
    const raw = localStorage.getItem('sf_user')
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => localStorage.getItem('sf_token'))
  const [user, setUser] = useState(loadUser)
  const [sessionMessage, setSessionMessage] = useState('')
  const loginSequence = useRef(0)
  const client = useMemo(() => createSessionClient(token), [token])

  useEffect(() => {
    const invalid = (event) => {
      if (event.detail.token !== token || localStorage.getItem('sf_token') !== token) return
      localStorage.removeItem('sf_token')
      localStorage.removeItem('sf_user')
      setToken(null)
      setUser(null)
      // A 401 carries API wording such as "Missing or invalid token"; only a deactivation message is useful to show.
      setSessionMessage(event.detail.status === 403 && event.detail.message ? event.detail.message : 'Your session has ended. Please sign in again.')
    }
    window.addEventListener('sf-session-invalid', invalid)
    let checking = false
    let cancelled = false
    const sync = () => {
      const stored = localStorage.getItem('sf_token')
      if (stored === token) return false
      loginSequence.current++
      setUser(null)
      setToken(stored)
      setSessionMessage(stored ? 'Your account changed in another tab. Verifying the current sign-in…' : 'You signed out in another tab. Please sign in again.')
      return true
    }
    const check = async () => {
      if (sync()) return
      if (!token || checking || document.visibilityState === 'hidden') return
      checking = true
      try {
        const data = await client.api('auth-session.php')
        if (!cancelled && localStorage.getItem('sf_token') === token && data.user) {
          const savedUser = JSON.stringify(data.user)
          if (localStorage.getItem('sf_user') !== savedUser) localStorage.setItem('sf_user', savedUser)
          setUser(data.user)
          setSessionMessage('')
        }
      } catch { /* API invalidates only a matching authentication failure. */ }
      finally { checking = false }
    }
    const storage = (event) => {
      if (event.key !== null && !['sf_token', 'sf_user'].includes(event.key)) return
      if (!sync()) check()
    }
    check()
    const timer = window.setInterval(check, 15000)
    window.addEventListener('focus', check)
    document.addEventListener('visibilitychange', check)
    window.addEventListener('storage', storage)
    return () => {
      cancelled = true
      window.clearInterval(timer)
      window.removeEventListener('sf-session-invalid', invalid)
      window.removeEventListener('focus', check)
      document.removeEventListener('visibilitychange', check)
      window.removeEventListener('storage', storage)
    }
  }, [token, client])

  const value = useMemo(() => {
    const login = async (username, password) => {
      const sequence = ++loginSequence.current
      const previousToken = localStorage.getItem('sf_token')
      const data = await smartflow.login(username, password)
      if (sequence !== loginSequence.current || localStorage.getItem('sf_token') !== previousToken) {
        throw new ApiError('The sign-in changed while this request was running. Use the current account or sign in again.', 409)
      }
      localStorage.setItem('sf_token', data.token)
      localStorage.setItem('sf_user', JSON.stringify(data.user))
      setToken(data.token)
      setUser(data.user)
      setSessionMessage('')
      return homePath(data.user.role)
    }

    const endSession = (expectedToken, message = '') => {
      if (localStorage.getItem('sf_token') !== expectedToken) return
      localStorage.removeItem('sf_token')
      localStorage.removeItem('sf_user')
      setToken(null)
      setUser(null)
      setSessionMessage(message)
    }

    const logout = async () => {
      if (!token) return
      await smartflow.logout(token)
      endSession(token)
    }

    const updateUser = (next) => {
      if (localStorage.getItem('sf_token') !== token) return
      localStorage.setItem('sf_user', JSON.stringify(next))
      setUser(next)
    }

    return {
      token,
      user,
      sessionMessage,
      isAuthenticated: Boolean(token && user),
      login,
      logout,
      endSession,
      updateUser,
      ...client,
    }
  }, [token, user, sessionMessage, client])

  // Changing the login/office/role discards prior rows, drafts and confirmation
  // promises; a new account must review its own current records.
  const identity = JSON.stringify([token, user?.id, user?.office_id, user?.role])
  return <AuthContext.Provider value={value}><Fragment key={identity}>{children}</Fragment></AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}
