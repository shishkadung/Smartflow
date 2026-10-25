// Keep one unfinished creation per account/office and kind. Reuse its ID on an
// explicit retry; transport failures only trigger a read of the saved outcome.
const running = new Set()
function storageKey(kind) {
  const user = JSON.parse(localStorage.getItem('sf_user') || 'null')
  if (!user?.id || !user?.office_id) throw new Error('Sign in before submitting.')
  return `sf_creation_v1_${user.id}_${user.office_id}_${kind}`
}
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical)
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().filter(key => value[key] !== undefined).map(key => [key, canonical(value[key])]))
  return value
}
export function pendingCreation(kind) {
  const raw = localStorage.getItem(storageKey(kind))
  if (!raw) return null
  const pending = JSON.parse(raw)
  if (!/^[a-f0-9]{32}$/.test(pending.id) || !pending.body || typeof pending.body !== 'object') throw new Error('Saved submission is unreadable. Keep this account signed in and ask for recovery assistance.')
  return pending
}
async function checkSavedCreation(kind, call, key) {
  call.assertSession?.()
  const pending = pendingCreation(kind)
  if (!pending) return null
  const result = await call(kind === 'correction' ? 'movement-requests.php' : 'creation-requests.php', { query: kind === 'correction' ? { request_id: pending.id } : { operation_id: pending.id, kind } })
  if (storageKey(kind) !== key) throw new Error('Account changed. Sign in to the original account to recover this submission.')
  if (result.state === 'recorded' || result.state === 'cancelled') {
    if (pendingCreation(kind)?.id !== pending.id) throw new Error('The saved submission changed. Check its current result before continuing.')
    localStorage.removeItem(key)
  }
  return result
}
export async function checkCreation(kind, call) {
  call.assertSession?.()
  const key = storageKey(kind)
  if (running.has(key)) throw new Error('A submission is still being checked. Wait for its result.')
  running.add(key)
  try { return navigator.locks ? await navigator.locks.request(key, () => checkSavedCreation(kind, call, key)) : await checkSavedCreation(kind, call, key) }
  finally { running.delete(key) }
}
export async function submitCreation(kind, body, call) {
  call.assertSession?.()
  const key = storageKey(kind)
  if (running.has(key)) throw new Error('A submission is still running. Wait for its result.')
  running.add(key)
  const submit = async () => {
    call.assertSession?.()
    let pending = pendingCreation(kind)
    const clean = canonical(body)
    if (pending && JSON.stringify(canonical(pending.body)) !== JSON.stringify(clean)) throw new Error('Check the previous submission before creating a different record.')
    if (!pending) {
      const bytes = crypto.getRandomValues(new Uint8Array(16))
      pending = { id: Array.from(bytes, n => n.toString(16).padStart(2, '0')).join(''), body: clean }
      localStorage.setItem(key, JSON.stringify(pending))
    }
    try {
      const endpoint = kind === 'correction' ? 'movements-correct-destination.php' : kind === 'document' ? 'documents-create.php' : 'document-requests-create.php'
      const result = await call(endpoint, { method: 'POST', body: { ...pending.body, [kind === 'correction' ? 'request_id' : 'operation_id']: pending.id } })
      if (storageKey(kind) !== key) throw new Error('Account changed while submitting. Recover the result in the original account.')
      if (pendingCreation(kind)?.id !== pending.id) throw new Error('The saved submission changed. Check its current result before continuing.')
      localStorage.removeItem(key)
      return result
    } catch (error) {
      if (error.data?.session_changed) throw new Error('Account changed. Recover this submission in the original account before creating another record.')
      if (error.status >= 400 && error.status < 500) { localStorage.removeItem(key); throw error }
      try {
        const outcome = await checkSavedCreation(kind, call, key)
        if (outcome?.state === 'recorded') return outcome.result
      } catch { /* Keep the saved operation until its outcome can be checked. */ }
      throw new Error('Submission outcome is pending. Use Check previous submission before starting another record.')
    }
  }
  try { return navigator.locks ? await navigator.locks.request(key, submit) : await submit() }
  finally { running.delete(key) }
}
