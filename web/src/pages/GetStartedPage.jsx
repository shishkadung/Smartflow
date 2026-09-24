import { Navigate } from 'react-router-dom'
import { useAuth } from '../auth.jsx'
import { homePath } from '../tracking.js'

/**
 * Former marketing landing — adviser: dialog was longer than login.
 * `/` now opens Sign in directly; this route only redirects.
 */
export default function GetStartedPage() {
  const { isAuthenticated, user } = useAuth()
  if (isAuthenticated) {
    return <Navigate to={homePath(user?.role)} replace />
  }
  return <Navigate to="/" replace />
}
