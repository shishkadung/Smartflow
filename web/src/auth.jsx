import { createContext, useContext, useMemo, useState } from 'react'
import { smartflow } from './api.js'
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

  const value = useMemo(() => {
    const login = async (username, password) => {
      const data = await smartflow.login(username, password)
      localStorage.setItem('sf_token', data.token)
      localStorage.setItem('sf_user', JSON.stringify(data.user))
      setToken(data.token)
      setUser(data.user)
      return homePath(data.user.role)
    }

    const logout = () => {
      localStorage.removeItem('sf_token')
      localStorage.removeItem('sf_user')
      setToken(null)
      setUser(null)
    }

    const updateUser = (next) => {
      localStorage.setItem('sf_user', JSON.stringify(next))
      setUser(next)
    }

    return {
      token,
      user,
      isAuthenticated: Boolean(token && user),
      login,
      logout,
      updateUser,
    }
  }, [token, user])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}
