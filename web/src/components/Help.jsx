import { useEffect, useState } from 'react'
import { hasSeenRoleTip, markRoleTipSeen, resetRoleTip, roleTipFor } from '../help.js'
import { useAuth } from '../auth.jsx'
import { SfIcon } from '../icons.jsx'

function HelpModal({ open, title, onClose, children, footer }) {
  useEffect(() => {
    if (!open) return undefined
    const onKey = (e) => { if (e.key === 'Escape') onClose?.() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null
  return (
    <div className="modal-root" role="presentation">
      <button type="button" className="modal-backdrop" aria-label="Close" onClick={onClose} />
      <div className="modal-panel" role="dialog" aria-modal="true" aria-label={title}>
        <div className="modal-panel__head">
          <h3>{title}</h3>
          <button type="button" className="btn-ghost" onClick={onClose}>Close</button>
        </div>
        <div className="modal-panel__body">{children}</div>
        {footer ? <div className="modal-panel__foot">{footer}</div> : null}
      </div>
    </div>
  )
}

/** First-login role tip (once per username). */
export function RoleTipHost() {
  const { user } = useAuth()
  const [open, setOpen] = useState(false)
  const [tip, setTip] = useState(null)

  useEffect(() => {
    if (!user?.username) return
    if (hasSeenRoleTip(user.username)) return
    setTip(roleTipFor(user))
    setOpen(true)
  }, [user?.username, user?.role, user?.office_code, user?.office_name])

  function close() {
    if (user?.username) markRoleTipSeen(user.username)
    setOpen(false)
  }

  if (!tip) return null

  return (
    <HelpModal
      open={open}
      title={tip.title}
      onClose={close}
      footer={
        <button type="button" className="btn" onClick={close}>
          Got it
        </button>
      }
    >
      <p className="help-purpose">{tip.purpose}</p>
      <ul className="help-bullets">
        {tip.bullets.map((b) => (
          <li key={b}>{b}</li>
        ))}
      </ul>
      <p className="muted help-footnote">You can reopen this from Account &amp; security.</p>
    </HelpModal>
  )
}

/** Manual reopen from Account & security. */
export function RoleTipButton({ className = 'btn-secondary' }) {
  const { user } = useAuth()
  const [open, setOpen] = useState(false)
  const tip = roleTipFor(user)

  function openTips() {
    resetRoleTip(user.username)
    setOpen(true)
    markRoleTipSeen(user.username)
  }

  return (
    <>
      <button type="button" className={className} onClick={openTips}>
        {className.includes('profile-action') ? (
          <>
            <span className="profile-action__icon" aria-hidden>
              <SfIcon name="custodyLog" size={18} />
            </span>
            <span className="profile-action__copy">
              <strong>Show getting-started tips</strong>
              <span>Short role guide for this office account.</span>
            </span>
          </>
        ) : (
          'Show getting-started tips'
        )}
      </button>
      <HelpModal
        open={open}
        title={tip.title}
        onClose={() => setOpen(false)}
        footer={
          <button type="button" className="btn" onClick={() => setOpen(false)}>
            Got it
          </button>
        }
      >
        <p className="help-purpose">{tip.purpose}</p>
        <ul className="help-bullets">
          {tip.bullets.map((b) => (
            <li key={b}>{b}</li>
          ))}
        </ul>
      </HelpModal>
    </>
  )
}
