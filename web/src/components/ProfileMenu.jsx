import { useEffect, useRef, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth.jsx'
import { SfIcon } from '../icons.jsx'
import { roleLabel } from './ui.jsx'
import { UserAvatar } from './UserAvatar.jsx'

/**
 * Account menu from the office badge.
 * See profile · Account & security · Log out
 */
export function ProfileMenu() {
  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const { pathname, search } = useLocation()
  const [open, setOpen] = useState(false)
  const rootRef = useRef(null)

  useEffect(() => {
    if (!open) return undefined
    const onDoc = (e) => {
      if (!rootRef.current?.contains(e.target)) setOpen(false)
    }
    const onKey = (e) => {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    window.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onDoc)
      window.removeEventListener('keydown', onKey)
    }
  }, [open])

  useEffect(() => {
    setOpen(false)
  }, [pathname, search])

  if (!user) return null

  return (
    <div className={`profile-menu ${open ? 'is-open' : ''}`} ref={rootRef}>
      <button
        type="button"
        className="office-seal profile-menu__trigger"
        aria-expanded={open}
        aria-haspopup="menu"
        title={`${user.office_name} · Account menu`}
        onClick={() => setOpen((v) => !v)}
      >
        {user.office_code}
      </button>

      {open ? (
        <div className="profile-menu__panel" role="menu" aria-label="Account menu">
          <div className="profile-menu__card">
            <button
              type="button"
              className="profile-menu__identity"
              role="menuitem"
              onClick={() => {
                setOpen(false)
                navigate('/profile')
              }}
            >
              <UserAvatar user={user} size="md" className="profile-menu__avatar-media" />
              <span className="profile-menu__who">
                <strong>{user.name}</strong>
                <span>{roleLabel(user.role)} · {user.office_code}</span>
              </span>
            </button>
            <button
              type="button"
              className="profile-menu__see-profile"
              role="menuitem"
              onClick={() => {
                setOpen(false)
                navigate('/profile')
              }}
            >
              <SfIcon name="profile" size={16} />
              See profile
            </button>
          </div>

          <div className="profile-menu__list">
            <button
              type="button"
              className="profile-menu__item"
              role="menuitem"
              onClick={() => {
                setOpen(false)
                navigate('/profile?view=security')
              }}
            >
              <span className="profile-menu__glyph"><SfIcon name="lock" size={18} /></span>
              <span className="profile-menu__label">Account &amp; security</span>
            </button>

            <button
              type="button"
              className="profile-menu__item profile-menu__item--logout"
              role="menuitem"
              onClick={() => {
                setOpen(false)
                logout()
                navigate('/')
              }}
            >
              <span className="profile-menu__glyph"><SfIcon name="logout" size={18} /></span>
              <span className="profile-menu__label">Log out</span>
            </button>
          </div>

          <p className="profile-menu__foot">
            Municipality of Urbiztondo · SmartFlow
          </p>
        </div>
      ) : null}
    </div>
  )
}
