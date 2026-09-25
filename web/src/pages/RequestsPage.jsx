import { useEffect, useMemo, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { LifeEmpty, LifeSkeleton, Modal, Overview, Segmented, StatusPill } from '../components/ui.jsx'
import { documentRequestCategoriesForOffice, statusLabel } from '../tracking.js'

function todayPlus(days) {
  const d = new Date()
  d.setDate(d.getDate() + days)
  return d.toISOString().slice(0, 10)
}

function toneForStatus(status) {
  if (status === 'approved' || status === 'fulfilled') return 'ok'
  if (status === 'pending') return 'warn'
  if (status === 'rejected' || status === 'cancelled') return 'bad'
  return 'info'
}

export default function RequestsPage() {
  const { user } = useAuth()
  const [tab, setTab] = useState('inbox')
  const [inboxFilter, setInboxFilter] = useState('all')
  const [inbox, setInbox] = useState([])
  const [outbox, setOutbox] = useState([])
  const [pending, setPending] = useState(0)
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const [loading, setLoading] = useState(true)
  const [showCreate, setShowCreate] = useState(false)
  const [dialog, setDialog] = useState(null)
  const [notes, setNotes] = useState('')
  const [relatedId, setRelatedId] = useState('')
  const [saving, setSaving] = useState(false)

  const categories = useMemo(
    () => documentRequestCategoriesForOffice(user.office_code),
    [user.office_code],
  )

  async function load() {
    setLoading(true)
    setError('')
    try {
      const [inData, outData] = await Promise.all([
        smartflow.documentRequestsList('inbox'),
        smartflow.documentRequestsList('outbox'),
      ])
      setInbox(inData.requests || [])
      setOutbox(outData.requests || [])
      setPending(inData.pending_inbox_count || 0)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not load requests')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  async function runUpdate(req, action, extra = {}) {
    setError('')
    setOk('')
    setSaving(true)
    try {
      const data = await smartflow.documentRequestUpdate({
        request_id: req.id,
        action,
        ...extra,
      })
      setOk(data.message || 'Updated')
      setDialog(null)
      setNotes('')
      setRelatedId('')
      await load()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not update request')
    } finally {
      setSaving(false)
    }
  }

  function openAction(req, action) {
    if (action === 'approve' || action === 'cancel') {
      runUpdate(req, action)
      return
    }
    setNotes('')
    setRelatedId('')
    setDialog({ req, action })
  }

  async function confirmDialog() {
    if (!dialog) return
    const { req, action } = dialog
    if (action === 'reject' && !notes.trim()) {
      setError('Decline notes are required for the office record.')
      return
    }
    await runUpdate(req, action, {
      ...(notes.trim() ? { review_notes: notes.trim() } : {}),
      ...(relatedId.trim() ? { related_document_id: relatedId.trim() } : {}),
    })
  }

  const inboxRows = inbox.filter((req) => {
    if (inboxFilter === 'pending') return req.status === 'pending'
    if (inboxFilter === 'overdue') return req.is_overdue === true
    return true
  })
  const rows = tab === 'inbox' ? inboxRows : outbox
  const overdueCount = inbox.filter((req) => req.is_overdue === true).length

  return (
    <div className="sf-life">
      <Overview
        title="Requests"
        body={
          user.role === 'head'
            ? 'Monitor tickets for your office — clerks fulfill handoffs.'
            : 'Accepting does not move the folder — register or scan when it arrives.'
        }
        actions={(
          <button type="button" className="btn sf-life__cta" onClick={() => setShowCreate((v) => !v)}>
            {showCreate ? 'Close form' : 'New request'}
          </button>
        )}
      />
      {error ? <div className="error">{error}</div> : null}
      {ok ? <div className="ok">{ok}</div> : null}

      <div className="toolbar">
        <Segmented
          value={tab}
          onChange={setTab}
          options={[
            { value: 'inbox', label: 'Inbox', badge: pending || undefined },
            { value: 'outbox', label: 'My requests' },
          ]}
        />
        {tab === 'inbox' ? (
          <Segmented
            value={inboxFilter}
            onChange={setInboxFilter}
            options={[
              { value: 'all', label: 'All' },
              { value: 'pending', label: 'Pending', badge: pending || undefined },
              { value: 'overdue', label: 'Overdue', badge: overdueCount || undefined },
            ]}
          />
        ) : null}
      </div>

      {showCreate ? (
        <CreateRequestForm
          categories={categories}
          onDone={async () => { setShowCreate(false); setOk('Request sent'); await load() }}
          onError={setError}
        />
      ) : null}

      <div className="card sf-life__panel">
        <h3 className="section-title">{tab === 'inbox' ? 'Inbox' : 'My requests'}</h3>
        {loading ? <LifeSkeleton rows={3} label="Loading requests" /> : null}
        {!loading && rows.length === 0 ? (
          <LifeEmpty icon="requests" tone="ok">
            {tab === 'outbox'
              ? 'No requests yet.'
              : inboxFilter === 'all'
                ? 'No open requests for this office.'
                : 'Nothing in this filter.'}
          </LifeEmpty>
        ) : null}
        {rows.map((req) => (
          <article key={req.id} className="request-card">
            <div className="request-card__top">
              <div className="request-card__code">{req.request_code}</div>
              <StatusPill tone={toneForStatus(req.status)}>{statusLabel(req.status)}</StatusPill>
            </div>
            <div className="request-card__meta">
              <span>{req.document_category}</span>
              <span>·</span>
              <span>{req.request_kind}</span>
              {req.required_by ? <><span>·</span><span>due {req.required_by}</span></> : null}
            </div>
            <p className="muted" style={{ margin: 0 }}>{req.purpose}</p>
            {tab === 'inbox' && req.status === 'pending' ? (
              <div className="request-card__actions">
                <button type="button" className="btn-danger" onClick={() => openAction(req, 'reject')}>Decline</button>
                <button type="button" className="btn" onClick={() => openAction(req, 'approve')}>Accept</button>
              </div>
            ) : null}
            {tab === 'inbox' && req.status === 'approved' ? (
              <div className="request-card__actions">
                {String(req.document_category || '').toLowerCase() === 'disbursement'
                  && String(user.office_code || '').toUpperCase() !== 'TRE' ? (
                  <p className="hint" style={{ margin: 0 }}>
                    Accepted — Treasury closes this after payment release.
                  </p>
                ) : (
                  <button
                    type="button"
                    className="btn-secondary"
                    onClick={() => openAction(req, 'fulfill')}
                  >
                    {String(req.document_category || '').toLowerCase() === 'disbursement'
                      ? 'Mark payment released'
                      : 'Close request'}
                  </button>
                )}
              </div>
            ) : null}
            {tab === 'outbox' && (req.status === 'pending' || req.status === 'approved') ? (
              <div className="request-card__actions">
                <button type="button" className="btn-ghost" onClick={() => openAction(req, 'cancel')}>Cancel request</button>
              </div>
            ) : null}
          </article>
        ))}
      </div>

      <Modal
        open={!!dialog}
        title={dialog?.action === 'reject' ? 'Decline request' : 'Mark complete'}
        onClose={() => setDialog(null)}
        footer={(
          <>
            <button type="button" className="btn-secondary" onClick={() => setDialog(null)}>Cancel</button>
            <button type="button" className={dialog?.action === 'reject' ? 'btn-danger' : 'btn'} disabled={saving} onClick={confirmDialog}>
              {saving
                ? 'Saving…'
                : dialog?.action === 'reject'
                  ? 'Decline'
                  : String(dialog?.req?.document_category || '').toLowerCase() === 'disbursement'
                    ? 'Mark payment released'
                    : 'Close request'}
            </button>
          </>
        )}
      >
        {dialog?.action === 'fulfill' ? (
          <div className="field">
            <label>Related document ID (optional)</label>
            <input value={relatedId} onChange={(e) => setRelatedId(e.target.value)} placeholder="DOC-2026-000001" />
          </div>
        ) : null}
        <div className="field">
          <label>{dialog?.action === 'reject' ? 'Decline notes (required)' : 'Closing notes (optional)'}</label>
          <textarea rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} required={dialog?.action === 'reject'} />
        </div>
      </Modal>
    </div>
  )
}

function CreateRequestForm({ categories, onDone, onError }) {
  const { user } = useAuth()
  const [kind, setKind] = useState('access')
  const [category, setCategory] = useState(categories[0]?.value || 'budget')
  const [purpose, setPurpose] = useState('')
  const [requiredBy, setRequiredBy] = useState(todayPlus(7))
  const [offices, setOffices] = useState([])
  const [targetOfficeId, setTargetOfficeId] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    smartflow.offices().then((d) => setOffices((d.offices || []).filter((o) => o.id !== user.office_id))).catch(() => {})
  }, [user.office_id])

  async function submit(e) {
    e.preventDefault()
    setLoading(true)
    onError('')
    try {
      await smartflow.documentRequestCreate({
        request_kind: kind,
        document_category: kind === 'access' ? category : 'general',
        purpose: purpose.trim(),
        required_by: requiredBy,
        ...(kind === 'pull' || category === 'other'
          ? { target_office_id: Number(targetOfficeId) }
          : {}),
      })
      onDone()
    } catch (err) {
      onError(err instanceof ApiError ? err.message : 'Could not create request')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form className="form-card" onSubmit={submit}>
      <h3 className="section-title">New document request</h3>
      <div className="form-grid">
        <div className="field">
          <label>Kind</label>
          <select value={kind} onChange={(e) => setKind(e.target.value)}>
            <option value="access">By type (Budget / DV / Others)</option>
            <option value="pull">From office (pull)</option>
          </select>
        </div>
        {kind === 'access' ? (
          <div className="field">
            <label>Document type</label>
            {categories.length === 0 ? (
              <p className="muted">No access types for your office — use From office instead.</p>
            ) : (
              <select value={category} onChange={(e) => setCategory(e.target.value)}>
                {categories.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            )}
          </div>
        ) : null}
        {kind === 'pull' || category === 'other' ? (
          <div className="field">
            <label>Target office</label>
            <select value={targetOfficeId} onChange={(e) => setTargetOfficeId(e.target.value)} required>
              <option value="">Select office</option>
              {offices.map((o) => <option key={o.id} value={o.id}>{o.name} ({o.code})</option>)}
            </select>
          </div>
        ) : null}
      </div>
      <div className="field">
        <label>Purpose</label>
        <textarea value={purpose} onChange={(e) => setPurpose(e.target.value)} required rows={3} />
      </div>
      <div className="field">
        <label>Required by</label>
        <input type="date" value={requiredBy} onChange={(e) => setRequiredBy(e.target.value)} required />
      </div>
      <button className="btn" type="submit" disabled={loading || (kind === 'access' && categories.length === 0) || ((kind === 'pull' || category === 'other') && !targetOfficeId)}>
        {loading ? 'Sending…' : 'Send request'}
      </button>
    </form>
  )
}
