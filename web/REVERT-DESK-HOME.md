# Revert desk-home polish

Experimental staff dashboard look (colored stats + Open Scanner empty state).

## Quick revert

1. Delete `web/src/desk-home.css`
2. Remove `import './desk-home.css'` from `web/src/main.jsx`
3. Restore the previous `web/src/pages/StaffHomePage.jsx` (copy below, or from git)
4. Optional: in `web/src/components/ui.jsx`, remove the `chips` block inside `page-head` if you added it only for this polish
5. Remove `.main > .desk-home { ... }` from `web/src/index.css` if present

## Flat StaffHomePage (pre-polish)

```jsx
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { DocTable, Empty, Overview, roleLabel } from '../components/ui.jsx'

export default function StaffHomePage() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    smartflow.dashboardStats(user.office_id)
      .then((d) => { if (!cancelled) setData(d) })
      .catch((e) => { if (!cancelled) setError(e instanceof ApiError ? e.message : 'Could not load dashboard') })
    return () => { cancelled = true }
  }, [user.office_id])

  const stats = data?.stats || {}
  const onDesk = data?.active_documents || []
  const incoming = data?.in_transit || []

  return (
    <>
      <Overview
        strap={`${user.office_code} · ${roleLabel(user.role)}`}
        title="Today at your desk"
        body="Received, sent, and folders currently on desk."
        hint="Use Scan to Mark IN when a folder arrives or Mark OUT when you forward it."
      />
      {error ? <div className="error">{error}</div> : null}
      <div className="stats">
        <div className="stat"><b>{stats.in_flow ?? '—'}</b><span>Received</span></div>
        <div className="stat"><b>{stats.out_flow ?? '—'}</b><span>Sent</span></div>
        <div className="stat"><b>{stats.active_tags ?? '—'}</b><span>On desk</span></div>
      </div>
      <div className="desk-grid">
        <div className="card">
          <h3 className="section-title">Folders on desk</h3>
          {onDesk.length === 0 ? (
            <Empty mark="0">No folders IN here right now.</Empty>
          ) : (
            <DocTable
              columns={[
                { key: 'document_id', label: 'ID' },
                { key: 'type', label: 'Type' },
                { key: 'title', label: 'Title' },
              ]}
              rows={onDesk}
              onRowClick={(doc) => navigate(`/scan?id=${doc.document_id}`)}
            />
          )}
        </div>
        <div className="card">
          <h3 className="section-title">Incoming (in transit)</h3>
          {incoming.length === 0 ? (
            <Empty mark="·">Nothing forwarded to this office in the last 48 hours.</Empty>
          ) : (
            <ul className="timeline">
              {incoming.map((doc) => (
                <li key={doc.document_id}>
                  <button className="list-item" type="button" onClick={() => navigate(`/scan?id=${doc.document_id}`)}>
                    <strong>{doc.document_id}</strong>
                    <span className="muted">From {doc.last_office_name}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </>
  )
}
```
