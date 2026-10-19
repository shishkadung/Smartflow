let snapshot = { unavailable: false, lastSuccess: null }
export function connectionSnapshot() { return snapshot }
export function reportConnection(unavailable, successful = false) {
  snapshot = { unavailable, lastSuccess: successful ? new Date().toISOString() : snapshot.lastSuccess }
  if (typeof window !== 'undefined' && typeof CustomEvent !== 'undefined') window.dispatchEvent(new CustomEvent('sf-connection-change'))
}

// Only the caller decides whether to repeat a request. Writes are never retried.
export async function portalFetch(url, options = {}) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 30000)
  try {
    const response = await fetch(url, { ...options, signal: controller.signal })
    reportConnection(response.status >= 500, response.ok)
    return response
  } catch {
    reportConnection(true)
    throw new Error(options.method && options.method !== 'GET'
      ? 'Connection interrupted. Refresh to check whether the action was recorded before submitting it again.'
      : 'Cannot reach SmartFlow. Displayed information may be out of date. Retry when the connection returns.')
  } finally { clearTimeout(timer) }
}
