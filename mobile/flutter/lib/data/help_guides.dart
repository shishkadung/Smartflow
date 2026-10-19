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

SfHelpGuide sfHelpGuide(SfHelpPage page, {String role = 'staff'}) {
  if (role != 'staff' && (page == SfHelpPage.home || page == SfHelpPage.scan)) {
    return SfHelpGuide(
      title: page == SfHelpPage.scan
          ? 'How to use Scan'
          : 'How to use Dashboard',
      purpose:
          'Review folder custody and office activity. Office staff register folders and record physical handoffs.',
      steps: const [
        'Open a folder to review its current location and history.',
        'Use a QR label or tracking ID to look up a folder. Lookup does not record a handoff.',
        'Use Requests to ask another office for a folder or inter-office work.',
      ],
    );
  }
  switch (page) {
    case SfHelpPage.home:
      return const SfHelpGuide(
        title: 'How to use Dashboard',
        purpose:
            'Dashboard shows today’s work for your office — what arrived, what you sent, and what is still on your desk.',
        steps: [
          'Tap an arriving folder to receive it, or a folder on your desk to send it.',
          'Scan is for the moment the label is in your hands.',
          'Register only when the paper folder is already here. Asking another office for a file? Use Requests.',
          'History is the audit trail. It is not where you receive or send.',
        ],
      );
    case SfHelpPage.scan:
      return const SfHelpGuide(
        title: 'How to use Scan',
        purpose:
            'Scan finds a folder from its QR label or tracking ID. Lookup alone records no handoff.',
        steps: [
          'Point the camera at the label, or paste the tracking ID.',
          'Review its location first. Only an explicit confirmed Receive or Send by office staff records a physical handoff.',
          'Already here? Do not receive it again — send it when it leaves.',
          'Missing QR? Type the Document ID (DOC-…). The full record still has the label.',
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
          'Open Documents to view or download the QR. Printing is optional.',
          'Forward (OUT) to the receiving office. They open Incoming and confirm actual receipt (IN).',
        ],
      );
    case SfHelpPage.requests:
      return const SfHelpGuide(
        title: 'How to use Requests',
        purpose:
            'Requests are tickets (“please prepare / please send a file”). They are not the same as scanning a folder.',
        steps: [
          'Inbox = requests sent to your office (you Accept or Decline).',
          'My requests = tickets you created. Active includes pending and accepted tickets; Past includes closed, declined and cancelled tickets.',
          'Accepting or linking a request does not receive or move a folder. Register only an unlabelled folder already held by your office.',
          'Disbursement tickets: Accounting Accepts; Treasury marks payment released when done.',
        ],
      );
    case SfHelpPage.history:
      return const SfHelpGuide(
        title: 'How to use History',
        purpose:
            'Choose Folder history for one folder, or Office activity for a dated office log.',
        steps: [
          'In Folder history, enter a tracking ID to see who registered, received and sent the folder.',
          'Read the full timeline from top to bottom. Office activity has date, Received/Sent filters and pages for the complete daily log.',
          'Use this for follow-ups and COA support checks.',
        ],
      );
    case SfHelpPage.alerts:
      return const SfHelpGuide(
        title: 'How to use Alerts',
        purpose:
            'Alerts flag late processing, deadlines and receipts not yet recorded. Municipal admins see alerts across offices.',
        steps: [
          'Open an alert to see which document needs attention.',
          'Overdue at office means the recorded folder deadline or processing limit has passed.',
          'Receipt not recorded means sending was recorded but the receiving office has not confirmed receipt. It does not prove the folder arrived.',
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
          'Open Menu (the grid at the top right) for how-to steps on the page you are on.',
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
          'Use Custody reports and QR scan monitor for compliance views.',
          'Do not use this account for everyday Receive (IN) / Send (OUT) — the Accounting clerk account does that.',
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
          'Keep the admin account for oversight — clerks scan folders.',
        ],
      );
    case SfHelpPage.adminOffices:
      return const SfHelpGuide(
        title: 'How to use Offices',
        purpose:
            'View pilot offices included in SmartFlow (ENG, HR, BUD, ACC, TRE, MAY).',
        steps: [
          'Confirm each office code matches municipal structure.',
          'Clerks and heads are tied to these offices when they log in.',
        ],
      );
    case SfHelpPage.adminSystem:
      return const SfHelpGuide(
        title: 'How to use System status',
        purpose:
            'Quick health check that the API and database are reachable for the pilot.',
        steps: [
          'Green / OK means offices can scan and register.',
          'If a connection fails, retry and ask the administrator to check the service. A failure is not proof of zero activity.',
        ],
      );
    case SfHelpPage.adminReports:
      return const SfHelpGuide(
        title: 'How to use Custody reports',
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
        title: 'How to use Alert time limits',
        purpose:
            'Set processing and receipt time limits so Alerts flag delays. Hours include nights and weekends; 48 hours means 2 calendar days.',
        steps: [
          'Select an office and tap a saved rule to prefill both limits. Use Add a rule for another document type.',
          'Processing starts after receipt; the receipt limit starts after sending. A folder’s own deadline takes priority.',
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
            'You see municipal-wide status and Custody reports. Clerks scan the folders — this account is not for everyday Receive (IN) / Send (OUT).',
        bullets: [
          'Use dashboards and Custody reports. Open Menu → Administration for Users, Offices, Alert time limits, QR monitor and System.',
          'For Accounting handoffs, the Accounting clerk account does the scanning.',
          'Open Menu (the grid at the top right) anytime for page help.',
        ],
      );
    case 'head':
      return SfRoleTip(
        title: 'Your account: Department Head · $office',
        purpose:
            'You monitor your office queue and delays. Office staff register folders and record physical handoffs.',
        bullets: [
          'Open a folder from the queue to review its custody and history.',
          'Scan a QR label to look up a folder. Lookup does not record a handoff.',
          'Use Requests to ask another office for a folder or inter-office work.',
          'History is the audit trail, not the place you move a folder.',
        ],
      );
    default:
      return SfRoleTip(
        title: 'Your account: Clerk · $office',
        purpose:
            'You move the folders at $office. Home shows what to receive and what to send.',
        bullets: [
          'Home: Receive what arrived. Send what is already on your desk.',
          'Scan when the label is in your hands. One button is ready: Receive or Send.',
          'Asking another office for a file? Use Requests. Do not register that folder.',
          'History is the audit trail, not the place you move a folder.',
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
    case '/head/scan':
    case '/admin/scan':
      return SfHelpPage.scan;
    case '/staff/register':
    case '/head/register':
    case '/admin/register':
      return SfHelpPage.register;
    case '/staff/requests':
    case '/head/requests':
    case '/admin/requests':
      return SfHelpPage.requests;
    case '/staff/history':
    case '/head/history':
    case '/admin/history':
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
