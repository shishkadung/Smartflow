// The browser tab, history and screen readers name the page, not only the site.
export const siteTitle = 'SmartFlow · Municipality of Urbiztondo'

const pageNames = {
  '/': 'Sign in',
  '/login': 'Sign in',
  '/get-started': 'Get started',
  '/signup': 'Request access',
  '/signup/pending': 'Check access request',
  '/signup/approved': 'Access approved',
  '/forgot-password': 'Forgot password',
  '/reset-password': 'Reset password',
  '/home': 'Dashboard',
  '/head': 'Dashboard',
  '/admin': 'Dashboard',
  '/head/analytics': 'Analytics',
  '/scan': 'Scan',
  '/documents': 'Documents',
  '/register': 'Register folder',
  '/requests': 'Requests',
  '/history': 'History',
  '/alerts': 'Alerts',
  '/profile': 'Profile',
  '/admin/users': 'Users & access',
  '/admin/offices': 'Offices',
  '/admin/thresholds': 'Thresholds',
  '/admin/reports': 'Custody reports',
  '/admin/qr-monitor': 'QR scan monitor',
  '/admin/system': 'System',
}

export function pageTitle(pathname) {
  const key = String(pathname || '/').replace(/\/+$/, '') || '/'
  const name = Object.hasOwn(pageNames, key) ? pageNames[key] : null
  return name ? `${name} · SmartFlow` : siteTitle
}
