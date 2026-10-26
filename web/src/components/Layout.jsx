import ConnectionBanner from './ConnectionBanner.jsx'
import { useEffect, useRef, useState } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'

import { useLiveRefresh } from '../live-refresh.js'
import { useAuth } from '../auth.jsx'
import { homePath, parseTrackingId } from '../tracking.js'
import { SfIcon } from '../icons.jsx'
import { RoleTipHost, PageHelp } from './Help.jsx'
import { ProfileMenu } from './ProfileMenu.jsx'
import { MunicipalSeal, Wordmark } from './ui.jsx'
import '../clarity-pages.css'

function BrandLockup({ variant = 'header', officeTitle = 'SmartFlow' }) {
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
        <p className="brand-lockup__office">{officeTitle}</p>
      </div>
    </div>
  )
}

/** Shared destination list — identical icons for staff, head, and admin. */
const SHARED_NAV = [
  { to: null, end: true, icon: 'home', mobile: 'Home', desktop: 'Dashboard' },
  { to: '/admin/reports', icon: 'coa', desktop: 'Custody reports', adminOnly: true },
  { to: '/documents', icon: 'history', mobile: 'Docs', desktop: 'Documents' },
  { to: '/scan', icon: 'scan', mobile: 'Scan', desktop: 'Scan', clerkOnly: true },
  { to: '/register', icon: 'register', mobile: 'New', desktop: 'Register', clerkOnly: true },
  { to: '/requests', icon: 'requests', mobile: 'Req', desktop: 'Requests' },
  { to: '/checklists', icon: 'checklist', desktop: 'Office checklists', managerOnly: true },
  { to: '/history', icon: 'history', mobile: 'History', desktop: 'History' },
  { to: '/alerts', icon: 'alerts', mobile: 'Alerts', desktop: 'Alerts' },
]

const ADMIN_NAV = [
  { to: '/admin/users', icon: 'users', label: 'Users' },
  { to: '/admin/offices', icon: 'offices', label: 'Offices' },
  { to: '/admin/thresholds', icon: 'thresholds', label: 'Thresholds' },
  { to: '/admin/qr-monitor', icon: 'qrMonitor', label: 'QR monitor' },
  { to: '/admin/system', icon: 'system', label: 'System' },
]

/** Phone destinations (mirrors the Flutter shells: a few tabs + Menu sheet). */
const PHONE_ITEMS = {
  documents: { to: '/documents', icon: 'custodyLog', label: 'Documents', short: 'Docs' },
  scan: { to: '/scan', icon: 'scan', label: 'Scan' },
  register: { to: '/register', icon: 'register', label: 'Register', short: 'New' },
  requests: { to: '/requests', icon: 'requests', label: 'Requests', short: 'Req' },
  history: { to: '/history', icon: 'history', label: 'History' },
  checklists: { to: '/checklists', icon: 'checklist', label: 'Office checklists' },
  alerts: { to: '/alerts', icon: 'alerts', label: 'Alerts' },
  analytics: { to: '/head/analytics', icon: 'coa', label: 'Analytics', short: 'Stats' },
  users: { to: '/admin/users', icon: 'users', label: 'Users' },
  offices: { to: '/admin/offices', icon: 'offices', label: 'Offices' },
  thresholds: { to: '/admin/thresholds', icon: 'thresholds', label: 'Thresholds' },
  coa: { to: '/admin/reports', icon: 'coa', label: 'Custody reports', short: 'Reports' },
  qrMonitor: { to: '/admin/qr-monitor', icon: 'qrMonitor', label: 'QR monitor' },
  system: { to: '/admin/system', icon: 'system', label: 'System' },
  profile: { to: '/profile', icon: 'profile', label: 'Profile' },
}

/** Phone bar matches the Flutter shells. Profile stays in the header. */
const PHONE_TABS = {
  staff: [
    { key: 'home', icon: 'home', label: 'Home', end: true },
    { key: 'documents', to: '/documents', icon: 'custodyLog', label: 'Documents' },
    { key: 'scan', to: '/scan', icon: 'scan', label: 'Scan', elevated: true },
    { key: 'alerts', to: '/alerts', icon: 'alerts', label: 'Alerts' },
  ],
  head: [
    { key: 'home', icon: 'home', label: 'Home', end: true },
    { key: 'queue', icon: 'custodyLog', label: 'Queue', hash: 'office-queue' },
    { key: 'scan', to: '/scan', icon: 'scan', label: 'Scan', elevated: true },
    { key: 'alerts', to: '/alerts', icon: 'alerts', label: 'Alerts' },
  ],
  admin: [
    { key: 'home', icon: 'home', label: 'Home', end: true },
    { key: 'history', to: '/history', icon: 'history', label: 'History' },
    { key: 'coa', to: '/admin/reports', icon: 'coa', label: 'Reports', elevated: true },
    { key: 'alerts', to: '/alerts', icon: 'alerts', label: 'Alerts' },
  ],
}

const PHONE_MENU = {
  staff: ['register', 'history', 'requests'],
  head: ['analytics', 'history', 'documents', 'requests', 'checklists'],
  admin: ['documents', 'requests', 'checklists', 'users', 'offices', 'thresholds', 'qrMonitor', 'system'],
}

function PhoneNav({ home, role, pendingSignups, pendingRequests, menuOpen, setMenuOpen }) {
  const { pathname, hash } = useLocation()
  const tabs = (PHONE_TABS[role] || PHONE_TABS.staff).map((tab) => ({
    ...tab,
    to: tab.to || home,
  }))
  const menu = (PHONE_MENU[role] || PHONE_MENU.staff).map((key) => ({ key, ...PHONE_ITEMS[key] }))
  const menuActive = menuOpen || menu.some((item) => pathname === item.to || pathname.startsWith(`${item.to}/`))
  const pendingItems = (pendingRequests || 0) + (role === 'admin' ? pendingSignups : 0)

  useEffect(() => { setMenuOpen(false) }, [pathname, hash, setMenuOpen])

  useEffect(() => {
    if (!menuOpen) return undefined
    const onKey = (e) => { if (e.key === 'Escape') setMenuOpen(false) }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [menuOpen, setMenuOpen])

  function tabActive(tab) {
    if (tab.hash) return pathname === tab.to && hash === `#${tab.hash}`
    if (tab.end) return pathname === tab.to && hash !== '#office-queue'
    return pathname === tab.to || pathname.startsWith(`${tab.to}/`)
  }

  return (
    <>
      <nav className="nav nav--phone" aria-label="Primary">
        {tabs.map((tab) => (
          <NavLink
            key={tab.key}
            to={tab.hash ? `${tab.to}#${tab.hash}` : tab.to}
            end={tab.end}
            className={() => `nav-tab${tab.elevated ? ' nav-elevated' : ''}${tabActive(tab) ? ' active' : ''}`}
          >
            {tab.elevated ? (
              <span className="nav-elevated__btn">
                <SfIcon name={tab.icon} size={22} />
              </span>
            ) : (
              <SfIcon name={tab.icon} />
            )}
            <span>{tab.label}</span>
          </NavLink>
        ))}
        <button
          type="button"
          className={`nav-menu-btn${menuActive ? ' active' : ''}`}
          aria-label={`Menu${pendingItems > 0 ? ` · ${pendingItems} pending items` : ''}`}
          aria-expanded={menuOpen}
          aria-controls="phone-menu-sheet"
          onClick={() => setMenuOpen((open) => !open)}
        >
          <span className="nav-icon-wrap">
            <SfIcon name="menu" />
            {pendingItems > 0 ? <span className="nav-badge">{pendingItems}</span> : null}
          </span>
          <span>Menu</span>
        </button>
      </nav>
      {menuOpen ? (
        <div id="phone-menu-sheet" className="menu-sheet" role="dialog" aria-modal="true" aria-label="Menu">
          <button type="button" className="menu-sheet__backdrop" aria-label="Close menu" onClick={() => setMenuOpen(false)} />
          <div className="menu-sheet__panel">
            <div className="menu-sheet__handle" aria-hidden />
            <p className="menu-sheet__title">Menu</p>
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
                    {item.key === 'requests' && pendingRequests > 0 ? <span className="nav-badge">{pendingRequests}</span> : null}
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
  const shell = useRef(null)
  const revision = useLiveRefresh()
  const { user, smartflow } = useAuth()
  const navigate = useNavigate()
  const { pathname } = useLocation()
  const home = homePath(user?.role)
  const isAdmin = user?.role === 'admin'
  const isHead = user?.role === 'head'
  const [q, setQ] = useState('')
  const [pendingSignups, setPendingSignups] = useState(0)
  const [pendingRequests, setPendingRequests] = useState(null)
  const [overdueRequests, setOverdueRequests] = useState(0)
  const [requestError, setRequestError] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const onUsersPage = pathname === '/admin/users'

  useEffect(() => {
    const element = shell.current
    const nav = element?.querySelector('.nav--phone')
    if (!element || !nav) return undefined
    const phone = window.matchMedia('(max-width: 767px)')
    const viewport = window.visualViewport
    const properties = ['--sf-phone-nav-height', '--sf-phone-viewport-height', '--sf-phone-viewport-top']
    const clear = () => properties.forEach(property => element.style.removeProperty(property))
    const measure = () => {
      if (!phone.matches) { clear(); return }
      // Browser chrome and the keyboard can shrink the visible viewport without
      // changing the layout viewport. Keep sheets and dialogs inside that space.
      element.style.setProperty('--sf-phone-nav-height', `${nav.getBoundingClientRect().height}px`)
      element.style.setProperty('--sf-phone-viewport-height', `${viewport?.height || window.innerHeight}px`)
      element.style.setProperty('--sf-phone-viewport-top', `${viewport?.offsetTop || 0}px`)
    }
    const observer = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(measure)
    observer?.observe(nav)
    window.addEventListener('resize', measure)
    phone.addEventListener('change', measure)
    viewport?.addEventListener('resize', measure)
    viewport?.addEventListener('scroll', measure)
    measure()
    return () => {
      observer?.disconnect()
      window.removeEventListener('resize', measure)
      phone.removeEventListener('change', measure)
      viewport?.removeEventListener('resize', measure)
      viewport?.removeEventListener('scroll', measure)
      clear()
    }
  }, [])

  useEffect(() => {
    if (!isAdmin) return undefined
    let cancelled = false
    smartflow.accountantDashboard()
      .then((d) => { if (!cancelled) setPendingSignups(Number(d?.stats?.pending_signups || 0)) })
      .catch(() => {})
    return () => { cancelled = true }
  }, [isAdmin, onUsersPage, revision, smartflow])

  useEffect(() => {
    let cancelled = false
    smartflow.documentRequestsSummary()
      .then((d) => { if (!cancelled) { setPendingRequests(Number(d?.pending_inbox_count || 0)); setOverdueRequests(Number(d?.overdue_inbox_count || 0)); setRequestError(false) } })
      .catch(() => { if (!cancelled) setRequestError(true) })
    return () => { cancelled = true }
  }, [revision, pathname, smartflow])

  return (
    <div ref={shell} className={isAdmin ? 'app-shell app-shell--admin' : 'app-shell'}>
      <button type="button" className="skip-link" onClick={() => document.getElementById('main-content')?.focus()}>Skip to main content</button>
      <aside className="shell-brand desktop-only-flex" aria-label="SmartFlow brand">
        <BrandLockup variant="nav" />
      </aside>
      <header className="topbar">
        <div className="topbar__who">
          <div className="topbar__brand">
            <BrandLockup
              officeTitle={isAdmin ? 'Municipal Admin' : (user?.office_name || 'SmartFlow')}
            />
          </div>
          <h1 className="sr-only mobile-only">{isAdmin ? 'Municipal Admin' : user?.office_name}</h1>
          <div className="topbar__welcome desktop-only">
            <h1>{isAdmin ? 'Municipal Admin' : user?.office_name}</h1>
            {user?.name ? <p className="muted topbar__user">{user.name}</p> : null}
          </div>
        </div>
        <div className="topbar__actions">
          <PageHelp key={pathname} />
          <form
            className="desktop-only"
            onSubmit={(e) => {
              e.preventDefault()
              if (q.trim()) navigate(`/documents?id=${encodeURIComponent(parseTrackingId(q) || q.trim().toUpperCase())}`)
              else navigate('/documents')
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
          <div className="desktop-only">
            <ProfileMenu />
          </div>
          <NavLink
            to="/profile"
            className={({ isActive }) => `mobile-only profile-launch${isActive ? ' active' : ''}`}
            aria-label="Profile"
          >
            <SfIcon name="profile" />
          </NavLink>
        </div>
      </header>
      <nav className="nav nav--desktop" aria-label="Primary">
        {SHARED_NAV.filter((item) => (!item.adminOnly || isAdmin) && (!item.managerOnly || isAdmin || isHead) && (item.to === '/scan' ? !isAdmin : !item.clerkOnly || user?.role === 'staff')).map((item) => {
          const to = item.to ?? home
          return (
            <NavLink key={item.icon + to} to={to} end={item.end} className={({ isActive }) => (isActive ? 'active' : '')}>
              <SfIcon name={item.icon} />
              {item.desktop}
              {item.to === '/requests' && pendingRequests > 0 ? <span className="nav-count">{pendingRequests}</span> : null}
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
          <div className="nav-administration">
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
      </nav>
      <PhoneNav
        home={home}
        role={user?.role}
        pendingSignups={pendingSignups}
        pendingRequests={pendingRequests}
        menuOpen={menuOpen}
        setMenuOpen={setMenuOpen}
      />
      <main className="main" id="main-content" tabIndex={-1}>
        <ConnectionBanner />
        <Outlet context={{ pendingRequests, overdueRequests, requestError }} />
      </main>
      <RoleTipHost />
    </div>
  )
}
