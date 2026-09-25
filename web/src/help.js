/** In-app help — aligned with Flutter help_guides.dart */

export const HELP_PAGES = {
  home: {
    title: 'How to use Home',
    purpose:
      'Home shows today’s work for your office — what arrived, what you sent, and what is still on your desk.',
    steps: [
      'Received = folders you scanned IN today.',
      'Sent = folders you scanned OUT today.',
      'On desk = folders physically here right now.',
      'Folder already here? Use Register. Asking another office for a file? Use Requests.',
    ],
  },
  scan: {
    title: 'How to use Scan',
    purpose:
      'Scan records when a physical folder arrives or leaves your office. This is the official handoff log.',
    steps: [
      'Scan the QR on the folder (or type/paste the Document ID).',
      'Mark IN when the folder arrives · Mark OUT when you send it — pick the receiving office.',
      'Already IN here? Do not Mark IN again — Mark OUT when you forward.',
      'Missing QR? Type the Document ID (DOC-…) or reopen the QR from History.',
    ],
  },
  register: {
    title: 'How to use Register',
    purpose:
      'Register only when the physical folder is already in your custody. This creates the tracking ID and QR label.',
    steps: [
      'Use Register only if the paper folder is on your desk now.',
      'Do not register just to “ask” another office — use Requests instead.',
      'Save the QR on your phone if needed; also write the Document ID on the folder.',
      'Then use Scan → Mark OUT when you forward the folder.',
    ],
  },
  requests: {
    title: 'How to use Requests',
    purpose:
      'Requests are tickets (“please prepare / please send a file”). They are not the same as scanning a folder.',
    steps: [
      'Inbox = requests sent to your office (Accept or Decline).',
      'My requests = tickets you sent to other offices.',
      'After Accept: the holder office registers + scans — not the person who asked.',
      'Disbursement tickets: Accounting Accepts; Treasury marks payment released when done.',
    ],
  },
  history: {
    title: 'How to use History',
    purpose: 'History is the audit trail — who scanned the folder, where, and when.',
    steps: [
      'Open a document or enter its tracking ID.',
      'Read the timeline for the full path between offices.',
      'Use this for follow-ups and COA support checks.',
    ],
  },
  alerts: {
    title: 'How to use Alerts',
    purpose:
      'Alerts show folders that need attention in YOUR office only — overdue on your desk, or sent out with no receive scan yet.',
    steps: [
      'Open an alert to see which document needs attention.',
      'IN overdue = still sitting at your office past the time limit.',
      'Unconfirmed OUT = you forwarded it, but the next office has not Marked IN yet.',
      'Other offices’ delays appear on their Alerts (or Admin municipal view).',
    ],
  },
  profile: {
    title: 'How to use Profile',
    purpose: 'See profile is your identity card. Account & security is where you change photo, edit details, and password.',
    steps: [
      'Open See profile for name, office, and desk stats.',
      'Open Account & security to update your photo, name/username/email, change password, or log out.',
      'Use Show getting-started tips under Account & security for a short role guide.',
    ],
  },
  adminHome: {
    title: 'How to use Admin Home',
    purpose:
      'Municipal overview across offices. You monitor custody and COA support — clerks do the scanning.',
    steps: [
      'Check active documents, overdue items, and pending sign-ups.',
      'Open office tiles to see health per department.',
      'Use COA reports and QR scan monitor for compliance views.',
      'Do not use this account for everyday Mark IN/OUT — use accounting.staff.',
    ],
  },
  adminUsers: {
    title: 'How to use Users',
    purpose: 'Approve or manage municipal accounts so each office has the right clerks and heads.',
    steps: [
      'Review pending sign-up requests first.',
      'Approve only people who belong to that office.',
      'Keep accountant.main for oversight — clerks scan folders.',
    ],
  },
  adminReports: {
    title: 'How to use COA reports',
    purpose:
      'Monthly custody summary to support COA preparation — not financial approval of vouchers.',
    steps: [
      'Pick the month/period and generate the summary.',
      'Export or review exceptions before submitting support docs.',
      'Remind clerks that History + Scan logs are the source of truth.',
    ],
  },
  adminQrMonitor: {
    title: 'How to use QR scan monitor',
    purpose:
      'Audit accepted and rejected scans (duplicates, wrong office, tampered QR) for COA support.',
    steps: [
      'Filter Accepted / Rejected / All as needed.',
      'Use rejected rows to show that state rules are enforced.',
      'Export CSV when the panel asks for an audit sample.',
    ],
  },
}

/** Resolve page help key from the current path (guides kept for docs / future use). */
export function helpPageForPath(pathname) {
  const path = String(pathname || '').replace(/\/$/, '') || '/'
  switch (path) {
    case '/home':
    case '/head':
      return 'home'
    case '/admin':
      return 'adminHome'
    case '/scan':
      return 'scan'
    case '/register':
      return 'register'
    case '/requests':
      return 'requests'
    case '/history':
      return 'history'
    case '/alerts':
      return 'alerts'
    case '/profile':
      return 'profile'
    case '/admin/users':
      return 'adminUsers'
    case '/admin/reports':
      return 'adminReports'
    case '/admin/qr-monitor':
      return 'adminQrMonitor'
    default:
      if (path.startsWith('/admin')) return 'adminHome'
      if (path.startsWith('/head') || path.startsWith('/home')) return 'home'
      return null
  }
}

export function roleTipFor(user) {
  const office = user.office_name || user.office_code || 'your office'
  if (user.role === 'admin') {
    return {
      title: 'Your account: Municipal Accountant (Admin)',
      purpose:
        'You see municipal-wide status and COA reports. Clerks scan the folders — this account is not for everyday Mark IN/OUT.',
      bullets: [
        'Use dashboards, QR scan monitor, and COA reports.',
        'For ACC handoffs, use accounting.staff (clerk) to scan.',
        'Reopen tips anytime from Account & security.',
      ],
    }
  }
  if (user.role === 'head') {
    return {
      title: `Your account: Department Head · ${office}`,
      purpose:
        'You monitor your office queue and delays. You may also scan if you personally handle a folder.',
      bullets: [
        'Check the queue and Alerts for overdue or waiting folders.',
        'If the folder is in your hands: Scan → Mark IN or OUT.',
        'Folder not here yet? Use Requests — do not register for someone else’s file.',
        'Reopen tips anytime from Account & security.',
      ],
    }
  }
  return {
    title: `Your account: Clerk · ${office}`,
    purpose: `You are the frontline scanner for folders at ${office}. Keep the paper trail in sync with Scan IN/OUT.`,
    bullets: [
      'Folder on your desk? Register + save/attach QR, then Scan when it moves.',
      'Asking another office for a file? Requests → wait for Inbox Accept there.',
      'Scan: Mark IN when it arrives · Mark OUT when you send it.',
      'Reopen tips anytime from Account & security.',
    ],
  }
}

function tipKey(username) {
  return `sf_role_tip_seen_v2_${String(username || '').trim().toLowerCase()}`
}

export function hasSeenRoleTip(username) {
  try {
    return localStorage.getItem(tipKey(username)) === '1'
  } catch {
    return true
  }
}

export function markRoleTipSeen(username) {
  try {
    localStorage.setItem(tipKey(username), '1')
  } catch {
    /* ignore */
  }
}

export function resetRoleTip(username) {
  try {
    localStorage.removeItem(tipKey(username))
  } catch {
    /* ignore */
  }
}
