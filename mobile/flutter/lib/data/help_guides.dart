/// In-app help for clerks who are less familiar with phones/apps.
enum SfHelpPage {
  home,
  scan,
  register,
  requests,
  history,
  alerts,
  profile,
  adminHome,
  adminUsers,
  adminOffices,
  adminSystem,
  adminReports,
  adminThresholds,
  adminQrMonitor,
}

class SfHelpGuide {
  const SfHelpGuide({
    required this.title,
    required this.purpose,
    required this.steps,
  });

  final String title;
  final String purpose;
  final List<String> steps;
}

class SfRoleTip {
  const SfRoleTip({
    required this.title,
    required this.purpose,
    required this.bullets,
  });

  final String title;
  final String purpose;
  final List<String> bullets;
}

SfHelpGuide sfHelpGuide(SfHelpPage page) {
  switch (page) {
    case SfHelpPage.home:
      return const SfHelpGuide(
        title: 'How to use Home',
        purpose:
            'Home shows today’s work for your office — what arrived, what you sent, and what is still on your desk.',
        steps: [
          'Received = folders you scanned IN today.',
          'Sent = folders you scanned OUT today.',
          'On desk = folders physically here right now.',
          'Folder already here? Use New to register. Asking another office for a file? Use Requests.',
        ],
      );
    case SfHelpPage.scan:
      return const SfHelpGuide(
        title: 'How to use Scan',
        purpose:
            'Scan records when a physical folder arrives or leaves your office. This is the official handoff log.',
        steps: [
          'Point the camera at the QR on the folder (or type/paste the Document ID).',
          'Mark IN when the folder arrives · Mark OUT when you send it — pick the receiving office.',
          'Already IN here? Do not Mark IN again — Mark OUT when you forward.',
          'Missing QR? Type the Document ID (DOC-…) or reopen/reprint the QR from History.',
        ],
      );
    case SfHelpPage.register:
      return const SfHelpGuide(
        title: 'How to use New / Register',
        purpose:
            'Register only when the physical folder is already in your custody. This creates the tracking ID and QR label.',
        steps: [
          'Use New only if the paper folder is on your desk now.',
          'Do not register just to “ask” another office — use Requests instead.',
          'Save the QR on your phone if needed; also write the Document ID on the folder.',
          'Then use Scan → Mark OUT when you forward the folder.',
        ],
      );
    case SfHelpPage.requests:
      return const SfHelpGuide(
        title: 'How to use Requests',
        purpose:
            'Requests are tickets (“please prepare / please send a file”). They are not the same as scanning a folder.',
        steps: [
          'Inbox = requests sent to your office (you Accept or Decline).',
          'My requests = tickets you sent to other offices.',
          'After Accept: the holder office registers + scans — not the person who asked.',
          'Disbursement tickets: Accounting Accepts; Treasury marks payment released when done.',
        ],
      );
    case SfHelpPage.history:
      return const SfHelpGuide(
        title: 'How to use History',
        purpose:
            'History is the audit trail — who scanned the folder, where, and when (IN / OUT).',
        steps: [
          'Open a document or enter its tracking ID.',
          'Read the timeline from top to bottom for the full path.',
          'Use this for follow-ups and COA support checks.',
        ],
      );
    case SfHelpPage.alerts:
      return const SfHelpGuide(
        title: 'How to use Alerts',
        purpose:
            'Alerts show folders that need attention in YOUR office only — overdue on your desk, or sent out with no receive scan yet.',
        steps: [
          'Open an alert to see which document needs attention.',
          'IN overdue = still sitting at your office past the time limit.',
          'Unconfirmed OUT = you forwarded it, but the next office has not Marked IN yet.',
          'Other offices’ delays appear on their Alerts (or Admin municipal view).',
        ],
      );
    case SfHelpPage.profile:
      return const SfHelpGuide(
        title: 'How to use Profile',
        purpose:
            'See profile is your identity card. Account & security is where you change photo, edit details, and password.',
        steps: [
          'Open See profile for name, office, and desk stats.',
          'Open Account & security to update your photo, name/username/email, change password, or log out.',
          'Use the top-bar ? for how-to steps on the page you are on.',
        ],
      );
    case SfHelpPage.adminHome:
      return const SfHelpGuide(
        title: 'How to use Admin Home',
        purpose:
            'Municipal overview across pilot offices. You monitor custody and COA support — clerks do the scanning.',
        steps: [
          'Check active documents, overdue items, and pending sign-ups.',
          'Open office tiles to see health per department.',
          'Use COA reports and QR scan monitor for compliance views.',
          'Do not use this account for everyday Mark IN/OUT — use accounting.staff.',
        ],
      );
    case SfHelpPage.adminUsers:
      return const SfHelpGuide(
        title: 'How to use Users',
        purpose:
            'Approve or manage municipal accounts so each office has the right clerks and heads.',
        steps: [
          'Review pending sign-up requests first.',
          'Approve only people who belong to that office.',
          'Keep accountant.main for oversight — clerks scan folders.',
        ],
      );
    case SfHelpPage.adminOffices:
      return const SfHelpGuide(
        title: 'How to use Offices',
        purpose: 'View pilot offices included in SmartFlow (ENG, HR, BUD, ACC, TRE, MAY).',
        steps: [
          'Confirm each office code matches municipal structure.',
          'Clerks and heads are tied to these offices when they log in.',
        ],
      );
    case SfHelpPage.adminSystem:
      return const SfHelpGuide(
        title: 'How to use System status',
        purpose: 'Quick health check that the API and database are reachable for the pilot.',
        steps: [
          'Green / OK means offices can scan and register.',
          'If something fails, restart XAMPP Apache + MySQL and sync the backend.',
        ],
      );
    case SfHelpPage.adminReports:
      return const SfHelpGuide(
        title: 'How to use COA reports',
        purpose:
            'Monthly custody summary to support COA preparation — not financial approval of vouchers.',
        steps: [
          'Pick the month/period and generate the summary.',
          'Export or review exceptions (custody gaps) before submitting support docs.',
          'Remind clerks that History + Scan logs are the source of truth.',
        ],
      );
    case SfHelpPage.adminThresholds:
      return const SfHelpGuide(
        title: 'How to use Thresholds',
        purpose:
            'Set max processing hours so Alerts flag folders that stay too long in an office.',
        steps: [
          'Adjust hours per office if the pilot needs stricter or looser timing.',
          'Save changes so Alerts use the new rules.',
        ],
      );
    case SfHelpPage.adminQrMonitor:
      return const SfHelpGuide(
        title: 'How to use QR scan monitor',
        purpose:
            'Audit accepted and rejected scans (duplicates, wrong office, tampered QR) for COA support.',
        steps: [
          'Filter Accepted / Rejected / All as needed.',
          'Use rejected rows to show that state rules are enforced.',
          'Export CSV when the panel asks for an audit sample.',
        ],
      );
  }
}

SfRoleTip sfRoleTip({
  required String role,
  required String officeCode,
  required String officeName,
}) {
  final office = officeName.isNotEmpty ? officeName : officeCode;
  switch (role) {
    case 'admin':
      return const SfRoleTip(
        title: 'Your account: Municipal Accountant (Admin)',
        purpose:
            'You see municipal-wide status and COA reports. Clerks scan the folders — this account is not for everyday Mark IN/OUT.',
        bullets: [
          'Use dashboards, QR scan monitor, and COA reports.',
          'For ACC handoffs, use accounting.staff (clerk) to scan.',
          'Tap the top-bar ? anytime for page help.',
        ],
      );
    case 'head':
      return SfRoleTip(
        title: 'Your account: Department Head · $office',
        purpose:
            'You monitor your office queue and delays. You may also scan if you personally handle a folder.',
        bullets: [
          'Check Queue and Alerts for overdue or waiting folders.',
          'If the folder is in your hands: Scan → Mark IN or OUT.',
          'Folder not here yet? Use Requests — do not register for someone else’s file.',
          'Tap the top-bar ? anytime for page help.',
        ],
      );
    default:
      return SfRoleTip(
        title: 'Your account: Clerk · $office',
        purpose:
            'You are the frontline scanner for folders at $office. Keep the paper trail in sync with Scan IN/OUT.',
        bullets: [
          'Folder on your desk? New (register) + save/attach QR, then Scan when it moves.',
          'Asking another office for a file? Requests → wait for Inbox Accept there.',
          'Scan: Mark IN when it arrives · Mark OUT when you send it.',
          'Tap the top-bar ? anytime for page help.',
        ],
      );
  }
}

/// Resolve page help from the current GoRouter path (fixed header ?).
SfHelpPage? sfHelpPageForPath(String path) {
  switch (path) {
    case '/staff':
    case '/head':
      return SfHelpPage.home;
    case '/admin':
      return SfHelpPage.adminHome;
    case '/staff/scan':
      return SfHelpPage.scan;
    case '/staff/register':
    case '/head/register':
      return SfHelpPage.register;
    case '/staff/requests':
    case '/head/requests':
    case '/admin/requests':
      return SfHelpPage.requests;
    case '/staff/history':
    case '/head/history':
      return SfHelpPage.history;
    case '/staff/alerts':
    case '/head/alerts':
      return SfHelpPage.alerts;
    case '/staff/profile':
    case '/head/profile':
    case '/admin/profile':
      return SfHelpPage.profile;
    case '/head/queue':
    case '/head/analytics':
      return SfHelpPage.home;
    case '/admin/users':
      return SfHelpPage.adminUsers;
    case '/admin/offices':
      return SfHelpPage.adminOffices;
    case '/admin/system':
      return SfHelpPage.adminSystem;
    case '/admin/reports':
      return SfHelpPage.adminReports;
    case '/admin/thresholds':
      return SfHelpPage.adminThresholds;
    case '/admin/qr-monitor':
      return SfHelpPage.adminQrMonitor;
    default:
      if (path.startsWith('/admin')) return SfHelpPage.adminHome;
      if (path.startsWith('/head') || path.startsWith('/staff')) {
        return SfHelpPage.home;
      }
      return null;
  }
}

/// Map clerk overview screens to help pages.
SfHelpPage? sfHelpPageForClerkScreen(String screenName) {
  switch (screenName) {
    case 'home':
      return SfHelpPage.home;
    case 'scan':
      return SfHelpPage.scan;
    case 'register':
    case 'registerSuccess':
      return SfHelpPage.register;
    case 'history':
      return SfHelpPage.history;
    case 'alerts':
      return SfHelpPage.alerts;
    case 'profile':
      return SfHelpPage.profile;
    case 'requests':
      return SfHelpPage.requests;
    default:
      return null;
  }
}
