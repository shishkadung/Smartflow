import { useEffect, useState } from 'react'

// Refresh visible data after deadlines pass and when returning to the portal.
export function useLiveRefresh() {
  const [revision, setRevision] = useState(0)
  useEffect(() => {
    const refresh = () => {
      if (document.visibilityState !== 'hidden') setRevision((value) => value + 1)
    }
    const timer = window.setInterval(refresh, 15000)
    window.addEventListener('focus', refresh)
    window.addEventListener('online', refresh)
    window.addEventListener('sf-refresh-requested', refresh)
    document.addEventListener('visibilitychange', refresh)
    return () => {
      window.clearInterval(timer)
      window.removeEventListener('focus', refresh)
      window.removeEventListener('online', refresh)
      window.removeEventListener('sf-refresh-requested', refresh)
      document.removeEventListener('visibilitychange', refresh)
    }
  }, [])
  return revision
}
