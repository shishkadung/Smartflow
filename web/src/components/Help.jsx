import { useEffect, useState } from 'react'
import { hasSeenRoleTip, markRoleTipSeen, resetRoleTip, roleTipFor, HELP_PAGES, helpPageForPath } from '../help.js'
import { useLocation } from 'react-router-dom'
import { useAuth } from '../auth.jsx'
import { SfIcon } from '../icons.jsx'
import { Modal as HelpModal } from './ui.jsx'

export function PageHelp() {
  const { pathname } = useLocation()
  const { user } = useAuth()
  const [open, setOpen] = useState(false)
  const page = helpPageForPath(pathname)
  const guide = user?.role !== 'staff' && ['home', 'scan'].includes(page)
    ? { title: page === 'scan' ? 'How to use Scan' : 'How to use Dashboard',
        purpose: 'Review folder custody and office activity. Office staff register folders and record physical handoffs.',
        steps: ['Open a folder to review its current location and history.', 'Use a QR label or tracking ID to look up a folder. Lookup does not record a handoff.', 'Use Requests to ask another office for a folder or inter-office work.'] }
    : HELP_PAGES[page]
  if (!guide) return null
  return <>
    <button className="btn-ghost page-help" type="button" aria-label="Help for this page" onClick={() => setOpen(true)}>?</button>
    <HelpModal open={open} title={guide.title} onClose={() => setOpen(false)}>
      <p className="help-purpose">{guide.purpose}</p>
      <ol className="help-bullets">{guide.steps.map(step => <li key={step}>{step}</li>)}</ol>
    </HelpModal>
  </>
}

/** First-login role tip (once per username). */
export function RoleTipHost() {
  const { user } = useAuth()
  const [open, setOpen] = useState(false)
  const [tip, setTip] = useState(null)

  useEffect(() => {
    if (!user?.username) return
    if (hasSeenRoleTip(user.username)) return
    // oxlint-disable-next-line react/set-state-in-effect -- The persisted first-login preference determines whether this role guide opens.
    setTip(roleTipFor(user))
    setOpen(true)
  }, [user])

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
