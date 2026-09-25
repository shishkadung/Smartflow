import { useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
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
  { to: '/scan', icon: 'scan', mobile: 'Scan', desktop: 'Scan' },
  { to: '/register', icon: 'register', mobile: 'New', desktop: 'Register' },
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

export default function Layout() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const home = homePath(user?.role)
  const isAdmin = user?.role === 'admin'
  const isHead = user?.role === 'head'
  const [q, setQ] = useState('')

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
            <h1>{user?.office_name}</h1>
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
      <nav className="nav" aria-label="Primary">
        {SHARED_NAV.map((item) => {
          const to = item.to ?? home
          return (
            <NavLink key={item.icon + to} to={to} end={item.end} className={({ isActive }) => (isActive ? 'active' : '')}>
              <SfIcon name={item.icon} />
              <span className="mobile-only">{item.mobile}</span>
              <span className="desktop-only">{item.desktop}</span>
            </NavLink>
          )
        })}
        {isHead ? (
          <NavLink to="/head/analytics" className={({ isActive }) => (isActive ? 'active' : '')}>
            <SfIcon name="coa" />
            <span className="mobile-only">Stats</span>
            <span className="desktop-only">Analytics</span>
          </NavLink>
        ) : null}
        {isAdmin ? (
          <div className="nav-municipal">
            <p className="nav-section desktop-only">Municipal</p>
            {ADMIN_NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) => (isActive ? 'active' : '')}
              >
                <SfIcon name={item.icon} />
                {item.label}
              </NavLink>
            ))}
          </div>
        ) : null}
        <NavLink to="/profile" className={({ isActive }) => `desktop-only ${isActive ? 'active' : ''}`}>
          <SfIcon name="profile" />
          Profile
        </NavLink>
      </nav>
      <main className="main">
        <Outlet />
      </main>
      <RoleTipHost />
    </div>
  )
}
