import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { Modal, Overview, roleLabel } from '../components/ui.jsx'
import { RoleTipButton } from '../components/Help.jsx'
import { UserAvatar } from '../components/UserAvatar.jsx'
import { SfIcon } from '../icons.jsx'

export default function ProfilePage() {
  const { user, logout, updateUser } = useAuth()
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const isSecurity = params.get('view') === 'security'
  const fileRef = useRef(null)

  const [name, setName] = useState(user.name || '')
  const [username, setUsername] = useState(user.username || '')
  const [email, setEmail] = useState(user.email || '')
  const [profileError, setProfileError] = useState('')
  const [profileOk, setProfileOk] = useState('')
  const [profileSaving, setProfileSaving] = useState(false)
  const [avatarBusy, setAvatarBusy] = useState(false)
  const [avatarNote, setAvatarNote] = useState('')
  const [avatarError, setAvatarError] = useState('')

  const [currentPassword, setCurrent] = useState('')
  const [newPassword, setNew] = useState('')
  const [pwError, setPwError] = useState('')
  const [pwOk, setPwOk] = useState('')
  const [pwSaving, setPwSaving] = useState(false)
  const [pwOpen, setPwOpen] = useState(false)
  const [logoutOpen, setLogoutOpen] = useState(false)

  const [stats, setStats] = useState(null)
  const [statsLoading, setStatsLoading] = useState(true)

  useEffect(() => {
    setName(user.name || '')
    setUsername(user.username || '')
    setEmail(user.email || '')
  }, [user.name, user.username, user.email])

  useEffect(() => {
    let cancelled = false
    setStatsLoading(true)
    const load = user.role === 'admin'
      ? smartflow.accountantDashboard()
      : smartflow.dashboardStats(user.office_id)

    load
      .then((d) => {
        if (cancelled) return
        if (user.role === 'admin') {
          const s = d.stats || {}
          setStats({
            a: s.active_documents ?? '—',
            b: s.overdue ?? '—',
            c: s.pending_signups ?? '—',
            labels: ['Active', 'Overdue', 'Pending'],
            title: 'Municipal overview',
          })
        } else {
          const s = d.stats || {}
          setStats({
            a: s.in_flow ?? '—',
            b: s.out_flow ?? '—',
            c: s.active_tags ?? '—',
            labels: ['Received', 'Sent', 'On desk'],
            title: "Today's desk",
          })
        }
      })
      .catch(() => {
        if (!cancelled) setStats(null)
      })
      .finally(() => {
        if (!cancelled) setStatsLoading(false)
      })

    return () => { cancelled = true }
  }, [user.office_id, user.role])

  async function saveProfile(e) {
    e.preventDefault()
    setProfileError('')
    setProfileOk('')
    setProfileSaving(true)
    try {
      const data = await smartflow.updateProfile(name.trim(), username.trim(), email.trim())
      if (data.user) updateUser(data.user)
      setProfileOk(data.message || 'Profile updated')
    } catch (err) {
      setProfileError(err instanceof ApiError ? err.message : 'Could not update profile')
    } finally {
      setProfileSaving(false)
    }
  }

  async function onAvatarFile(e) {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return
    setAvatarBusy(true)
    setAvatarNote('')
    setAvatarError('')
    try {
      const data = await smartflow.uploadAvatar(file)
      if (data.user) updateUser(data.user)
      setAvatarNote(data.message || 'Photo updated')
    } catch (err) {
      setAvatarError(err instanceof ApiError ? err.message : 'Could not upload photo')
    } finally {
      setAvatarBusy(false)
    }
  }

  async function removeAvatar() {
    setAvatarBusy(true)
    setAvatarNote('')
    setAvatarError('')
    try {
      const data = await smartflow.removeAvatar()
      if (data.user) updateUser(data.user)
      setAvatarNote(data.message || 'Photo removed')
    } catch (err) {
      setAvatarError(err instanceof ApiError ? err.message : 'Could not remove photo')
    } finally {
      setAvatarBusy(false)
    }
  }

  async function savePassword(e) {
    e.preventDefault()
    setPwError('')
    setPwOk('')
    setPwSaving(true)
    try {
      const data = await smartflow.changePassword(currentPassword, newPassword)
      setPwOk(data.message || 'Password changed')
      setCurrent('')
      setNew('')
      setTimeout(() => {
        setPwOpen(false)
        setPwOk('')
      }, 700)
    } catch (err) {
      setPwError(err instanceof ApiError ? err.message : 'Could not change password')
    } finally {
      setPwSaving(false)
    }
  }

  function closePassword() {
    setPwOpen(false)
    setPwError('')
    setPwOk('')
    setCurrent('')
    setNew('')
  }

  const hasPhoto = Boolean(user.has_avatar || user.avatar_url)
  const isAdmin = user.role === 'admin'
  const overviewBody = isAdmin
    ? 'Municipal account snapshot. Photo and edits are under Account & security.'
    : 'Office account snapshot. Photo and edits are under Account & security.'
  const roleOfficeHint = isAdmin
    ? 'Role and home office are fixed for this municipal account.'
    : 'Assigned by admin — cannot change here.'

  if (!isSecurity) {
    return (
      <div className="sf-life">
        <Overview
          title="Your profile"
          body={overviewBody}
        />

        <div className="card profile-account sf-life__panel">
          <div className="profile-banner" aria-hidden />
          <div className="profile-hero profile-hero--rich">
            <div className="profile-hero__photo">
              <UserAvatar user={user} size="xl" />
            </div>
            <div className="profile-hero__copy">
              <h2>{user.name}</h2>
              <p className="profile-hero__role">
                {roleLabel(user.role)} · {user.office_name} ({user.office_code})
              </p>
              <p className="muted profile-hero__user">@{user.username}</p>
            </div>
          </div>

          {statsLoading ? (
            <p className="muted profile-stats-loading">Loading overview…</p>
          ) : stats ? (
            <div className="profile-overview">
              <h3 className="section-title">{stats.title}</h3>
              <div className="stats profile-stats sf-life__stats">
                <div className={`stat ${isAdmin ? 'stat--desk' : 'stat--in'}`}>
                  <b>{stats.a}</b><span>{stats.labels[0]}</span>
                </div>
                <div className={`stat ${isAdmin ? 'stat--overdue' : 'stat--out'}`}>
                  <b>{stats.b}</b><span>{stats.labels[1]}</span>
                </div>
                <div className={`stat ${isAdmin ? 'stat--pending' : 'stat--desk'}`}>
                  <b>{stats.c}</b><span>{stats.labels[2]}</span>
                </div>
              </div>
            </div>
          ) : null}
        </div>

        <Link className="btn btn--navy as-link profile-goto-security sf-life__cta" to="/profile?view=security">
          <SfIcon name="lock" size={18} />
          Account &amp; security
        </Link>
      </div>
    )
  }

  return (
    <div className="sf-life">
      <Overview
        title="Account & security"
        body="Photo, name, email, password, or end this session."
        actions={
          <Link className="btn-secondary as-link sf-life__cta" to="/profile">Back to profile</Link>
        }
      />

      <div className="profile-layout profile-layout--security">
        <div className="profile-security-stack">
          <div className="form-card profile-photo-card sf-life__panel">
            <h3 className="section-title">Profile photo</h3>
            <p className="muted profile-card-lead">
              JPEG, PNG, or WebP · max 2 MB. Shown on your account menu.
            </p>
            <input
              ref={fileRef}
              type="file"
              accept="image/jpeg,image/png,image/webp"
              className="sr-only"
              onChange={onAvatarFile}
            />
            <div className="profile-photo-edit">
              <UserAvatar
                user={user}
                size="xl"
                editable
                busy={avatarBusy}
                onPick={() => fileRef.current?.click()}
              />
              <div className="profile-photo-actions">
                <button
                  type="button"
                  className="btn-secondary"
                  disabled={avatarBusy}
                  onClick={() => fileRef.current?.click()}
                >
                  {avatarBusy ? 'Uploading…' : hasPhoto ? 'Change photo' : 'Upload photo'}
                </button>
                {hasPhoto ? (
                  <button type="button" className="btn-ghost" disabled={avatarBusy} onClick={removeAvatar}>
                    Remove
                  </button>
                ) : null}
              </div>
            </div>
            {avatarNote ? <p className="ok profile-avatar-note">{avatarNote}</p> : null}
            {avatarError ? <div className="error">{avatarError}</div> : null}
          </div>

          <div className="profile-session-col">
            <div className="card profile-session sf-life__panel">
              <h3 className="section-title">Session & security</h3>
              <div className="profile-kv">
                <div className="profile-kv__row"><span>Status</span><strong>Signed in · official session</strong></div>
                <div className="profile-kv__row"><span>User</span><strong>@{user.username}</strong></div>
                <div className="profile-kv__row"><span>App</span><strong>SmartFlow · Urbiztondo</strong></div>
              </div>
              <div className="profile-actions">
                <button type="button" className="profile-action" onClick={() => setPwOpen(true)}>
                  <span className="profile-action__icon" aria-hidden>
                    <SfIcon name="lock" size={18} />
                  </span>
                  <span className="profile-action__copy">
                    <strong>Change password</strong>
                    <span>Update your sign-in password.</span>
                  </span>
                </button>
                <RoleTipButton className="profile-action" />
              </div>
            </div>

            <button type="button" className="profile-logout" onClick={() => setLogoutOpen(true)}>
              <SfIcon name="logout" size={18} />
              Log out
            </button>
          </div>
        </div>

        <form className="form-card profile-edit-card sf-life__panel" onSubmit={saveProfile}>
          <h3 className="section-title">Edit profile</h3>
          <p className="muted profile-card-lead">
            Name, username, and email appear on custody records. Email is used for password reset.
          </p>
          {profileOk ? <div className="ok">{profileOk}</div> : null}
          <div className="field">
            <label>Full name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} required autoComplete="name" />
          </div>
          <div className="field">
            <label>Username</label>
            <input value={username} onChange={(e) => setUsername(e.target.value)} required minLength={3} autoComplete="username" />
          </div>
          <div className="field">
            <label>Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
              placeholder="you@urbiztondo.gov.ph"
            />
          </div>
          <div className="profile-readonly">
            <div className="profile-readonly__row">
              <span>Role</span>
              <strong>{roleLabel(user.role)}</strong>
            </div>
            <div className="profile-readonly__row">
              <span>{isAdmin ? 'Home office' : 'Office'}</span>
              <strong>{user.office_name} ({user.office_code})</strong>
            </div>
            <p className="muted profile-readonly__hint">{roleOfficeHint}</p>
          </div>
          {profileError ? <div className="error">{profileError}</div> : null}
          <button className="btn" type="submit" disabled={profileSaving}>
            {profileSaving ? 'Saving…' : 'Save profile'}
          </button>
        </form>
      </div>

      <Modal
        open={pwOpen}
        title="Change password"
        onClose={closePassword}
        footer={
          <div className="row-btns">
            <button type="button" className="btn-secondary" onClick={closePassword}>Cancel</button>
            <button className="btn" type="submit" form="profile-pw-form" disabled={pwSaving}>
              {pwSaving ? 'Saving…' : 'Update password'}
            </button>
          </div>
        }
      >
        <form id="profile-pw-form" onSubmit={savePassword}>
          {pwError ? <div className="error">{pwError}</div> : null}
          {pwOk ? <div className="ok">{pwOk}</div> : null}
          <div className="field">
            <label>Current password</label>
            <input type="password" value={currentPassword} onChange={(e) => setCurrent(e.target.value)} required autoComplete="current-password" />
          </div>
          <div className="field">
            <label>New password (8+)</label>
            <input type="password" value={newPassword} onChange={(e) => setNew(e.target.value)} required minLength={8} autoComplete="new-password" />
          </div>
        </form>
      </Modal>

      <Modal
        open={logoutOpen}
        title="Log out?"
        onClose={() => setLogoutOpen(false)}
        footer={
          <div className="row-btns">
            <button type="button" className="btn-secondary" onClick={() => setLogoutOpen(false)}>Cancel</button>
            <button
              type="button"
              className="btn-danger"
              onClick={() => {
                logout()
                navigate('/')
              }}
            >
              Log out
            </button>
          </div>
        }
      >
        <p className="muted" style={{ margin: 0 }}>
          You will need to sign in again to use SmartFlow in this browser.
        </p>
      </Modal>
    </div>
  )
}
