import { useEffect, useState } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { smartflow } from '../api.js'
import { useAuth } from '../auth.jsx'
import { homePath } from '../tracking.js'
import { SfIcon } from '../icons.jsx'
import { RoleTipHost } from './Help.jsx'
import { ProfileMenu } from './ProfileMenu.jsx'
import { MunicipalSeal, Wordmark } from './ui.jsx'

function BrandLockup({ variant = 'header' }) {
  if (variant === 'nav') {
    return (
      <div className="brand-lockup brand-lockup--nav">
        <MunicipalSeal size={44} />
        <div className="brand-lockup__text">
          <p className="brand-lockup__muni">Municipality of Urbiztondo</p>
          <Wordmark />
          <p className="muted brand-lockup__tag">Inter-office document tracking</p>
        </div>
      </div>
    )
  }
  return (
    <div className="brand-lockup brand-lockup--header">
      <MunicipalSeal size={34} />
      <div className="brand-lockup__text">
        <p className="brand-lockup__muni">Municipality of Urbiztondo</p>
        <Wordmark />
      </div>
    </div>
  )
}

/** Shared destination list — identical icons for staff, head, and admin. */
const SHARED_NAV = [
  { to: null, end: true, icon: 'home', mobile: 'Home', desktop: 'Dashboard' },
  { to: '/scan', icon: 'scan', mobile: 'Scan', desktop: 'Scan', clerkOnly: true },
  { to: '/register', icon: 'register', mobile: 'New', desktop: 'Register', clerkOnly: true },
  { to: '/requests', icon: 'requests', mobile: 'Req', desktop: 'Requests' },
  { to: '/history', icon: 'history', mobile: 'History', desktop: 'History' },
  { to: '/alerts', icon: 'alerts', mobile: 'Alerts', desktop: 'Alerts' },
]

const ADMIN_NAV = [
  { to: '/admin/users', icon: 'users', label: 'Users' },
  { to: '/admin/offices', icon: 'offices', label: 'Offices' },
  { to: '/admin/thresholds', icon: 'thresholds', label: 'Thresholds' },
  { to: '/admin/reports', icon: 'coa', label: 'COA' },
  { to: '/admin/qr-monitor', icon: 'qrMonitor', label: 'QR monitor' },
  { to: '/admin/system', icon: 'system', label: 'System' },
]

/** Phone destinations (mirrors the Flutter shells: a few tabs + Menu sheet). */
const PHONE_ITEMS = {
  scan: { to: '/scan', icon: 'scan', label: 'Scan' },
  register: { to: '/register', icon: 'register', label: 'Register', short: 'New' },
  requests: { to: '/requests', icon: 'requests', label: 'Requests', short: 'Req' },
  history: { to: '/history', icon: 'history', label: 'History' },
  alerts: { to: '/alerts', icon: 'alerts', label: 'Alerts' },
  analytics: { to: '/head/analytics', icon: 'coa', label: 'Analytics', short: 'Stats' },
  users: { to: '/admin/users', icon: 'users', label: 'Users' },
  offices: { to: '/admin/offices', icon: 'offices', label: 'Offices' },
  thresholds: { to: '/admin/thresholds', icon: 'thresholds', label: 'Thresholds' },
  coa: { to: '/admin/reports', icon: 'coa', label: 'COA reports', short: 'COA' },
  qrMonitor: { to: '/admin/qr-monitor', icon: 'qrMonitor', label: 'QR monitor' },
  system: { to: '/admin/system', icon: 'system', label: 'System' },
  profile: { to: '/profile', icon: 'profile', label: 'Profile' },
}

const PHONE_LAYOUT = {
  staff: { tabs: ['scan', 'register', 'requests', 'history', 'alerts'], menu: [] },
  head: { tabs: ['scan', 'requests', 'alerts'], menu: ['register', 'history', 'analytics', 'profile'] },
  admin: {
    tabs: ['history', 'coa'],
    menu: ['users', 'requests', 'alerts', 'offices', 'thresholds', 'qrMonitor', 'system', 'profile'],
  },
}

function PhoneNav({ home, role, pendingSignups }) {
  const { pathname } = useLocation()
  const [menuOpen, setMenuOpen] = useState(false)
  const layout = PHONE_LAYOUT[role] || PHONE_LAYOUT.staff
  const tabs = layout.tabs.map((key) => PHONE_ITEMS[key])
  const menu = layout.menu.map((key) => ({ key, ...PHONE_ITEMS[key] }))
  const menuActive = menu.some((item) => pathname === item.to || pathname.startsWith(`${item.to}/`))
  const columns = 1 + tabs.length + (menu.length ? 1 : 0)

  useEffect(() => { setMenuOpen(false) }, [pathname])

  useEffect(() => {
    if (!menuOpen) return undefined
    const onKey = (e) => { if (e.key === 'Escape') setMenuOpen(false) }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [menuOpen])

  const tabClass = ({ isActive }) => (isActive ? 'active' : '')

  return (
    <>
      <nav className="nav nav--phone" aria-label="Primary" style={{ gridTemplateColumns: `repeat(${columns}, 1fr)` }}>
        <NavLink to={home} end className={tabClass}>
          <SfIcon name="home" />
          <span>Home</span>
        </NavLink>
        {tabs.map((item) => (
          <NavLink key={item.to} to={item.to} className={tabClass}>
            <SfIcon name={item.icon} />
            <span>{item.short || item.label}</span>
          </NavLink>
        ))}
        {menu.length ? (
          <button
            type="button"
            className={`nav-menu-btn${menuActive || menuOpen ? ' active' : ''}`}
            aria-haspopup="dialog"
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen((v) => !v)}
          >
            <span className="nav-icon-wrap">
              <SfIcon name="menu" />
              {pendingSignups > 0 ? <span className="nav-badge">{pendingSignups}</span> : null}
            </span>
            <span>Menu</span>
          </button>
        ) : null}
      </nav>
      {menuOpen ? (
        <div className="menu-sheet" role="dialog" aria-modal="true" aria-label="Menu">
          <button type="button" className="menu-sheet__backdrop" aria-label="Close menu" onClick={() => setMenuOpen(false)} />
          <div className="menu-sheet__panel">
            <div className="menu-sheet__handle" aria-hidden />
            <p className="menu-sheet__title">{role === 'admin' ? 'Municipal tools' : 'More'}</p>
            <div className="menu-sheet__grid">
              {menu.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  className={({ isActive }) => `menu-sheet__item${isActive ? ' active' : ''}`}
                >
                  <span className="nav-icon-wrap">
                    <SfIcon name={item.icon} size={22} />
                    {item.key === 'users' && pendingSignups > 0 ? <span className="nav-badge">{pendingSignups}</span> : null}
                  </span>
                  <span>{item.label}</span>
                </NavLink>
              ))}
            </div>
          </div>
        </div>
      ) : null}
    </>
  )
}

export default function Layout() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const { pathname } = useLocation()
  const home = homePath(user?.role)
  const isAdmin = user?.role === 'admin'
  const isHead = user?.role === 'head'
  const [q, setQ] = useState('')
  const [pendingSignups, setPendingSignups] = useState(0)
  const onUsersPage = pathname === '/admin/users'

  useEffect(() => {
    if (!isAdmin) return undefined
    let cancelled = false
    smartflow.accountantDashboard()
      .then((d) => { if (!cancelled) setPendingSignups(Number(d?.stats?.pending_signups || 0)) })
      .catch(() => {})
    return () => { cancelled = true }
  }, [isAdmin, onUsersPage])

  return (
    <div className={isAdmin ? 'app-shell app-shell--admin' : 'app-shell'}>
      <aside className="shell-brand desktop-only-flex" aria-label="SmartFlow brand">
        <BrandLockup variant="nav" />
      </aside>
      <header className="topbar">
        <div className="topbar__who">
          <div className="topbar__brand">
            <BrandLockup variant="header" />
          </div>
          <div className="topbar__welcome desktop-only">
            <h1>{isAdmin ? 'Municipal Administration' : user?.office_name}</h1>
            {user?.name ? <p className="muted topbar__user">{user.name}</p> : null}
          </div>
        </div>
        <div className="topbar__actions">
          <form
            className="desktop-only"
            onSubmit={(e) => {
              e.preventDefault()
              if (q.trim()) navigate(`/history?id=${encodeURIComponent(q.trim())}`)
              else navigate('/history')
            }}
          >
            <input
              className="top-search"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Search tracking ID"
              aria-label="Search tracking ID"
            />
          </form>
          <ProfileMenu />
        </div>
      </header>
      <nav className="nav nav--desktop" aria-label="Primary">
        {SHARED_NAV.filter((item) => !(isAdmin && item.clerkOnly)).map((item) => {
          const to = item.to ?? home
          return (
            <NavLink key={item.icon + to} to={to} end={item.end} className={({ isActive }) => (isActive ? 'active' : '')}>
              <SfIcon name={item.icon} />
              {item.desktop}
            </NavLink>
          )
        })}
        {isHead ? (
          <NavLink to="/head/analytics" className={({ isActive }) => (isActive ? 'active' : '')}>
            <SfIcon name="coa" />
            Analytics
          </NavLink>
        ) : null}
        {isAdmin ? (
          <div className="nav-municipal">
            <p className="nav-section">Municipal</p>
            {ADMIN_NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) => (isActive ? 'active' : '')}
              >
                <SfIcon name={item.icon} />
                {item.label}
                {item.to === '/admin/users' && pendingSignups > 0 ? (
                  <span className="nav-count">{pendingSignups}</span>
                ) : null}
              </NavLink>
            ))}
          </div>
        ) : null}
        <NavLink to="/profile" className={({ isActive }) => (isActive ? 'active' : '')}>
          <SfIcon name="profile" />
          Profile
        </NavLink>
      </nav>
      <PhoneNav home={home} role={user?.role} pendingSignups={pendingSignups} />
      <main className="main">
        <Outlet />
      </main>
      <RoleTipHost />
    </div>
  )
}
