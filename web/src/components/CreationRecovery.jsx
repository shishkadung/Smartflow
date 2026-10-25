import { useAuth } from '../auth.jsx'
import { useState } from 'react'

import { checkCreation, pendingCreation, submitCreation } from '../creation-recovery.js'

export default function CreationRecovery({ kind, onRecovered }) {
  const { api } = useAuth()
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  let pending, readError
  try { pending = pendingCreation(kind) } catch (error) { readError = error.message }
  if (!pending && !readError && !message) return null
  async function run(retry) {
    setBusy(true)
    setMessage('')
    try {
      const outcome = await checkCreation(kind, api)
      if (outcome?.state === 'recorded') onRecovered(outcome.result)
      else if (outcome?.state === 'cancelled') setMessage('This submission was cancelled. Refresh the folder before another action.')
      else if (retry && pending) onRecovered(await submitCreation(kind, pending.body, api))
      else setMessage('No completed result found yet. Retry saved submission uses the same operation ID, so it cannot create it twice.')
    } catch (error) { setMessage(error.message) }
    finally { setBusy(false) }
  }
  return <div className="creation-recovery" role="status">
    <p>{readError || message || 'A previous submission is still being checked. Recover it before creating another record.'}</p>
    {pending ? <p>{pending.body.title || pending.body.purpose || pending.body.document_id}</p> : null}
    {pending ? <div className="row-btns"><button type="button" className="btn-secondary" disabled={busy} onClick={() => run(false)}>Check previous submission</button><button type="button" className="btn-ghost" disabled={busy} onClick={() => run(true)}>Retry saved submission</button></div> : null}
  </div>
}
