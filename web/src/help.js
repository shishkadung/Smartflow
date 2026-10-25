/** In-app help — aligned with Flutter help_guides.dart */

export const HELP_PAGES = {
  documents: {
    title: 'How to use Documents',
    purpose: 'Open a folder to see its current holder, deadline, next action, and full custody history.',
    steps: [
      'Use Incoming for folders sent to your office; receive only when the actual folder arrives.',
      'Use At your office to forward a folder or return it for correction with a reason.',
      'Administrators can filter municipal records by office and overdue status for oversight.',
      'Heads and administrators monitor folders; office staff record physical handoffs.',
      'Completed folders keep their QR and history. Filing is separate from payment release.',
    ],
  },
  home: {
    title: 'How to use Home',
    purpose:
      'Home shows today’s work for your office — what arrived, what you sent, and what is still on your desk.',
    steps: [
      'Tap an arriving folder to receive it, or a folder on your desk to send it.',
      'Scan is for the moment the label is in your hands.',
      'Register only when the paper folder is already here. Asking another office for a file? Use Requests.',
      'History is the audit trail. It is not where you receive or send.',
    ],
  },
  scan: {
    title: 'How to use Scan',
    purpose:
      'Scan or enter an ID to find a folder. Only a staff member’s confirmed Receive or Send records a physical handoff.',
    steps: [
      'Point the camera at the label, or paste the tracking ID.',
      'Staff see the action allowed by current custody: Receive or Send. Heads and administrators inspect the folder.',
      'Already here? Do not receive it again — send it when it leaves.',
      'Missing QR? Type the Document ID (DOC-…). The full record still has the label.',
    ],
  },
  register: {
    title: 'How to use Register',
    purpose:
      'Register only when the physical folder is already in your custody. This creates the tracking ID and QR label.',
    steps: [
      'Use Register only if the paper folder is on your desk now.',
      'Do not register just to “ask” another office — use Requests instead.',
      'Open Documents, then QR label to view or download the QR. Printing is optional.',
      'Forward (OUT) to the receiving office. They open Incoming and confirm actual receipt (IN).',
    ],
  },
  requests: {
    title: 'How to use Requests',
    purpose:
      'Requests are tickets (“please prepare / please send a file”). They are not the same as scanning a folder.',
    steps: [
      'Inbox = requests sent to your office (Accept or Decline).',
      'My requests = tickets you sent to other offices.',
      'Active includes pending and accepted work. Past requests keeps closed, declined and cancelled tickets.',
      'Accepting does not receive a folder. Link an existing folder; staff register only an unlabelled folder already at their office.',
      'Disbursement tickets: Accounting Accepts; Treasury marks payment released when done.',
    ],
  },
  history: {
    title: 'How to use History',
    purpose: 'Review who registered, received or sent a folder, or open the complete daily log of your office.',
    steps: [
      'Folder history: enter a tracking ID or open History from a folder.',
      'Read the timeline for the full path between offices.',
      'Office activity: choose a date and Received or Sent. Use the page controls to review the complete log.',
      'Use this for follow-ups and COA support checks.',
    ],
  },
  alerts: {
    title: 'How to use Alerts',
    purpose:
      'Alerts explain overdue folders and sends without a recorded receipt. Administrators see municipal alerts; office users see their office scope.',
    steps: [
      'Open an alert to see which document needs attention.',
      'Overdue means the folder passed its applicable deadline. Read the alert reason for the rule used.',
      'Receipt not recorded means the send is recorded but the receiving office has not recorded its receipt. It does not prove the folder never arrived.',
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
      'Open Custody reports from the main navigation for audit preparation. QR monitor, account management and Thresholds are also in the navigation.',
      'Do not use this account for everyday Mark IN/OUT — the Accounting clerk account does that.',
    ],
  },
  adminUsers: {
    title: 'How to use Users',
    purpose: 'Approve or manage municipal accounts so each office has the right clerks and heads.',
    steps: [
      'Review pending sign-up requests first.',
      'Approve only people who belong to that office.',
      'Keep the admin account for oversight — clerks scan folders.',
    ],
  },
  adminReports: {
    title: 'How to use Custody reports',
    purpose:
      'Monthly custody summary to support COA preparation — not financial approval of vouchers.',
    steps: [
      'Pick the month/period and generate the summary.',
      'Export or review exceptions before submitting support docs.',
      'Remind clerks that History + Scan logs are the source of truth.',
    ],
  },
  adminThresholds: {
    title: 'How to use Thresholds',
    purpose: 'Choose when to flag a folder that stays at an office or has no recorded receipt after being sent.',
    steps: [
      'Choose the office and document type. Edit a current rule or add a new one.',
      'Processing hours start from the recorded receipt at the office. Receipt hours start from that office’s recorded send.',
      'Calendar hours run continuously, including nights, weekends and holidays. 48 hours = 2 days.',
      'A deadline set on an individual folder takes priority over these limits.',
      'Thresholds flag delays; they do not record a handoff or release payment.',
    ],
  },
  adminOffices: {
    title: 'How to use Offices',
    purpose: 'Review municipal offices and their processing and receipt limits.',
    steps: [
      'Each office lists its current document-type rules.',
      'Open Manage thresholds to review or change those limits.',
      'When no custom rule exists, the default processing and receipt limits apply.',
    ],
  },
  adminSystem: {
    title: 'How to use System',
    purpose: 'Review API and database health and the latest verified system counts.',
    steps: [
      'Use Refresh status to check current health.',
      'After a failed refresh, retained information describes the last successful check.',
      'Retry an unavailable check before relying on its health or counts.',
    ],
  },
  headAnalytics: {
    title: 'How to use Analytics',
    purpose: 'Review the on-time rate and slow folders for your office.',
    steps: [
      'Choose the month to review its activity.',
      'Open a folder’s history to investigate a delay.',
      'Refresh or retry when current figures could not be verified.',
    ],
  },
  adminQrMonitor: {
    title: 'How to use QR scan monitor',
    purpose:
      'Audit accepted and rejected scans from the last 48 hours (duplicates, wrong office, tampered QR) for COA support.',
    steps: [
      'Filter Accepted / Rejected / All as needed.',
      'Use rejected rows to show that state rules are enforced.',
      'Export CSV when the panel asks for an audit sample.',
    ],
  },
}

/** Resolve the current page guide. */
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
    case '/documents':
      return 'documents'
    case '/history':
      return 'history'
    case '/alerts':
      return 'alerts'
    case '/profile':
      return 'profile'
    case '/admin/users':
      return 'adminUsers'
    case '/admin/offices':
      return 'adminOffices'
    case '/admin/thresholds':
      return 'adminThresholds'
    case '/admin/system':
      return 'adminSystem'
    case '/head/analytics':
      return 'headAnalytics'
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
        'You monitor folders across municipal offices and review custody reports. Office staff record physical receipts and sends.',
      bullets: [
        'Use Dashboard and Custody reports from the main navigation. QR monitor, account management and Thresholds are also directly available there.',
        'For Accounting handoffs, the Accounting clerk account does the scanning.',
        'Reopen tips anytime from Account & security.',
      ],
    }
  }
  if (user.role === 'head') {
    return {
      title: `Your account: Department Head · ${office}`,
      purpose:
        'You monitor your office queue and delays. Office staff register folders and record physical handoffs.',
      bullets: [
        'Open a folder from the queue to review its custody and history.',
        'Scan a QR label to look up a folder. Lookup does not record a handoff.',
        'Use Requests to ask another office for a folder or inter-office work.',
        'History is the audit trail, not the place you move a folder.',
      ],
    }
  }
  return {
    title: `Your account: Clerk · ${office}`,
    purpose: `You move the folders at ${office}. Home shows what to receive and what to send.`,
    bullets: [
      'Home: Receive what arrived. Send what is already on your desk.',
      'Scan when the label is in your hands. One button is ready: Receive or Send.',
      'Asking another office for a file? Use Requests. Do not register that folder.',
      'History is the audit trail, not the place you move a folder.',
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
