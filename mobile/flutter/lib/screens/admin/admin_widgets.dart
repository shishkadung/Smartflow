import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/sf_icons.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/format_time.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';
import '../staff/clerk_widgets.dart';

/// Admin (LGU IT / Municipal Accountant) screens — shared overview layout.
enum SfAdminScreen {
  home,
  scan,
  register,
  users,
  offices,
  system,
  profile,
  accountSecurity,
  reports,
  thresholds,
  requests,
  qrMonitor,
  alerts,
}

class SfAdminPageOverviewCard extends StatelessWidget {
  const SfAdminPageOverviewCard({
    super.key,
    required this.screen,
    this.pendingSignups,
    this.pendingInbox,
    this.compact,
    this.bodyOverride,
  });

  final SfAdminScreen screen;
  final int? pendingSignups;
  final int? pendingInbox;

  /// When null, ops/config screens default to compact; Home / Reports / Profile stay full.
  final bool? compact;

  /// A screen may describe its active filters using the shared overview style.
  final String? bodyOverride;

  static bool _defaultCompact(SfAdminScreen screen) {
    switch (screen) {
      case SfAdminScreen.scan:
      case SfAdminScreen.register:
      case SfAdminScreen.users:
      case SfAdminScreen.offices:
      case SfAdminScreen.system:
      case SfAdminScreen.thresholds:
      case SfAdminScreen.qrMonitor:
      case SfAdminScreen.requests:
      case SfAdminScreen.alerts:
        return true;
      case SfAdminScreen.home:
      case SfAdminScreen.reports:
      case SfAdminScreen.profile:
      case SfAdminScreen.accountSecurity:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final useCompact = compact ?? _defaultCompact(screen);

    late final String title;
    late final String body;

    switch (screen) {
      case SfAdminScreen.home:
        title = 'Dashboard';
        body = 'Active custody across municipal offices.';
      case SfAdminScreen.scan:
        title = 'Scan';
        body =
            'Receive (IN) when a folder arrives at your office, or Send (OUT) when you send it.';
      case SfAdminScreen.register:
        title = 'Register';
        body =
            'New folder for your office. Your QR stays available in SmartFlow.';
      case SfAdminScreen.users:
        title = 'Users';
        body = 'Approve sign-ups and activate or deactivate accounts.';
      case SfAdminScreen.offices:
        title = 'Offices';
        body = 'Municipal offices in the SmartFlow deployment.';
      case SfAdminScreen.system:
        title = 'System';
        body = 'API and database health.';
      case SfAdminScreen.profile:
        title = 'Profile';
        body = 'Your municipal account.';
      case SfAdminScreen.accountSecurity:
        title = 'Account & security';
        body = 'Photo, name, email, password, or sign out.';
      case SfAdminScreen.reports:
        title = 'Custody reports';
        body = 'Handoff metrics by month, quarter, or year.';
      case SfAdminScreen.thresholds:
        title = 'Alert time limits';
        body = 'When processing or a missing receipt should be flagged.';
      case SfAdminScreen.qrMonitor:
        title = 'QR monitor';
        body = 'Accepted and rejected scans in the selected time window.';
      case SfAdminScreen.requests:
        title = 'Requests';
        body =
            'Accepting does not move the folder — register or scan when it arrives.';
      case SfAdminScreen.alerts:
        title = 'Alerts';
        body = 'Delays and unconfirmed handoffs across municipal offices.';
    }

    return SfPageOverviewCard(
      title: title,
      body: bodyOverride ?? body,
      compact: useCompact,
    );
  }
}

/// Municipal stat row for admin home — tap tiles for related screens.
class SfAdminStatRow extends StatelessWidget {
  const SfAdminStatRow({
    super.key,
    required this.activeDocs,
    required this.overdue,
    required this.pendingSignups,
    this.onActiveDocsTap,
    this.onOverdueTap,
    this.onPendingTap,
    this.hint,
  });

  final int activeDocs;
  final int overdue;
  final int pendingSignups;
  final VoidCallback? onActiveDocsTap;
  final VoidCallback? onOverdueTap;
  final VoidCallback? onPendingTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SfStatStrip(
          children: [
            SfDashboardStatCell(
              value: '$activeDocs',
              label: 'Active',
              sublabel: 'Across offices',
              color: SfColors.navy,
              onTap: onActiveDocsTap,
            ),
            SfDashboardStatCell(
              value: '$overdue',
              label: 'Overdue',
              sublabel: 'Follow up',
              color: SfColors.countInk(overdue, live: SfColors.red),
              onTap: onOverdueTap,
            ),
            SfDashboardStatCell(
              value: '$pendingSignups',
              label: 'Sign-ups',
              sublabel: 'Awaiting review',
              color: SfColors.navy,
              onTap: onPendingTap,
            ),
          ],
        ),
        if (hint != null && hint!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            style: const TextStyle(
              fontSize: 12,
              color: SfColors.muted,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

/// API / stack health strip on admin home.
class SfAdminSystemStatusBanner extends StatelessWidget {
  const SfAdminSystemStatusBanner({
    super.key,
    required this.apiOnline,
    this.onTap,
  });

  final bool apiOnline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = apiOnline ? const Color(0xFF15803D) : SfColors.red;
    final bg = apiOnline
        ? SfColors.green.withValues(alpha: 0.1)
        : SfColors.red.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: fg.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(
                apiOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                size: 20,
                color: fg,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  apiOnline
                      ? 'System online · municipal services available'
                      : 'Services unavailable · contact your administrator',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.35,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 18, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Attention CTA when sign-ups are waiting — Users / COA / tools live in tabs + Menu.
class SfAdminStartHereCard extends StatelessWidget {
  const SfAdminStartHereCard({super.key, required this.pendingSignups});

  final int pendingSignups;

  @override
  Widget build(BuildContext context) {
    if (pendingSignups <= 0) return const SizedBox.shrink();
    return SfNavigationRow(
      icon: Icons.person_add_alt_1_outlined,
      title: 'Sign-up requests',
      subtitle: '$pendingSignups pending approval',
      subtitleColor: SfColors.gold,
      onTap: () => context.go('/admin/users'),
    );
  }
}

class SfAdminOfficeHealthTile extends StatelessWidget {
  const SfAdminOfficeHealthTile({
    super.key,
    required this.name,
    required this.code,
    required this.docsProcessed,
    required this.inOffice,
    required this.overdue,
    this.onTap,
  });

  final String name;
  final String code;
  final int docsProcessed;
  final int inOffice;
  final int overdue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SfFormCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            // The status sits beside the name instead of on its own row, so each office takes about a third less height.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: SfColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$code · $inOffice on desk · $overdue overdue',
                        style: const TextStyle(
                          fontSize: 13,
                          color: SfColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SfStatusPill(
                  label: overdue > 0
                      ? 'Follow up'
                      : inOffice == 0 && docsProcessed == 0
                      ? 'No activity'
                      : 'On track',
                  tone: overdue > 0
                      ? SfPillTone.warning
                      : inOffice == 0 && docsProcessed == 0
                      ? SfPillTone.neutral
                      : SfPillTone.success,
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: SfColors.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SfAdminPendingSignupCard extends StatelessWidget {
  const SfAdminPendingSignupCard({
    super.key,
    required this.request,
    required this.onApprove,
    required this.onReject,
    this.enabled = true,
    this.pendingAction,
  });

  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool enabled;
  final String? pendingAction;

  @override
  Widget build(BuildContext context) {
    final username = request['username']?.toString() ?? '—';
    final code = request['request_code']?.toString() ?? '';
    final role = request['requested_role']?.toString() ?? '—';
    final office = request['office_name']?.toString() ?? '';
    final officeCode = request['office_code']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SfFormCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: SfColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const SfStatusPill(label: 'Pending', tone: SfPillTone.warning),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Requested role: $role\n$office${officeCode.isNotEmpty ? ' ($officeCode)' : ''}',
              style: const TextStyle(
                fontSize: 13,
                color: SfColors.muted,
                height: 1.35,
              ),
            ),
            if (code.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SfColors.navy,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (pendingAction != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  pendingAction == 'approve'
                      ? 'Approving sign-up…'
                      : 'Rejecting sign-up…',
                  style: const TextStyle(color: SfColors.muted, fontSize: 13),
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final width = stacked
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: width,
                      child: SfSecondaryOutlineButton(
                        label: pendingAction == 'reject'
                            ? 'Rejecting…'
                            : 'Reject',
                        onPressed: enabled ? onReject : null,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: SfPrimaryButton(
                        label: pendingAction == 'approve'
                            ? 'Approving…'
                            : 'Approve',
                        loading: pendingAction == 'approve',
                        onPressed: enabled ? onApprove : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Municipal account row with actions kept below the account details.
const _generatedEmailDomain = '@urbiztondo.gov.ph';

/// Addresses generated from the username were never confirmed by their owner, so they are flagged.
bool sfEmailNeedsCheck(Map<String, dynamic> user) {
  final email = (user['email']?.toString() ?? '').trim().toLowerCase();
  final username = (user['username']?.toString() ?? '').toLowerCase();
  return email.isEmpty || email == '$username$_generatedEmailDomain';
}

/// Same scope as the web Manage action: staff and head accounts only (administrators use Profile).
bool sfAdminCanManageUser(Map<String, dynamic> user) {
  final role = user['role']?.toString();
  return role == 'staff' || role == 'head';
}

/// Temporary passwords are for active staff or head accounts other than the signed-in administrator.
bool sfAdminCanResetPassword(Map<String, dynamic> user, int? selfId) =>
    sfAdminCanManageUser(user) &&
    user['is_active'] == true &&
    user['id'] != selfId;

final RegExp sfEmailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

/// Shows an administrator-issued temporary password once, in groups of four so it is easy to read aloud.
class SfTemporaryPasswordDialog extends StatefulWidget {
  const SfTemporaryPasswordDialog({
    super.key,
    required this.name,
    required this.username,
    required this.password,
    this.expires,
  });

  final String name;
  final String username;
  final String password;
  final String? expires;

  static String grouped(String value) =>
      RegExp('.{1,4}').allMatches(value).map((m) => m.group(0)).join(' ');

  @override
  State<SfTemporaryPasswordDialog> createState() =>
      _SfTemporaryPasswordDialogState();
}

class _SfTemporaryPasswordDialogState extends State<SfTemporaryPasswordDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.password));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The password cannot be shown again, so it is closed only by the explicit button.
      canPop: false,
      child: AlertDialog(
        title: const Text('Temporary password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('For ${widget.name} (@${widget.username}):'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: SfColors.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SfColors.border),
                ),
                child: SelectableText(
                  SfTemporaryPasswordDialog.grouped(widget.password),
                  key: const Key('temporary-password'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(_copied ? 'Copied' : 'Copy password'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Share it privately (in person or by phone), never by chat or email. '
                'It is shown only once, expires in 24 hours, and the user must choose a new password at their next sign-in.',
                style: TextStyle(
                  fontSize: 13,
                  color: SfColors.muted,
                  height: 1.4,
                ),
              ),
              if (widget.expires != null && widget.expires!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Expires ${widget.expires}.',
                  style: const TextStyle(fontSize: 13, color: SfColors.muted),
                ),
              ],
              const SizedBox(height: 6),
              const Text(
                'Their other sessions were signed out and the old password no longer works.',
                style: TextStyle(
                  fontSize: 13,
                  color: SfColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I have shared it'),
          ),
        ],
      ),
    );
  }
}

class SfAdminUserCard extends StatelessWidget {
  const SfAdminUserCard({
    super.key,
    required this.user,
    this.onToggleActive,
    this.busy = false,
    this.isSelf = false,
    this.onManage,
  });

  final Map<String, dynamic> user;
  final VoidCallback? onToggleActive;
  final bool busy;
  final bool isSelf;

  /// Opens the Manage sheet (edit reset email, temporary password) for staff and head accounts.
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final username = user['username']?.toString() ?? '—';
    final role = user['role']?.toString() ?? '—';
    final office = user['office_name']?.toString() ?? '';
    final code = user['office_code']?.toString() ?? '';
    final active = user['is_active'] as bool? ?? true;
    final dept = SfColors.dept(code.isNotEmpty ? code : 'ENG');

    final avatar = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dept.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        code.isNotEmpty ? code.substring(0, code.length.clamp(0, 3)) : '?',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: dept,
        ),
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          username,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: SfColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$role · $office',
          style: const TextStyle(
            fontSize: 13,
            color: SfColors.muted,
            height: 1.4,
          ),
        ),
      ],
    );
    final pill = SfStatusPill(
      label: active ? 'Active' : 'Inactive',
      tone: active ? SfPillTone.success : SfPillTone.neutral,
    );
    final action = isSelf
        ? const Text(
            'Your account',
            style: TextStyle(fontSize: 12, color: SfColors.muted),
          )
        : TextButton.icon(
            onPressed: busy ? null : onToggleActive,
            icon: Icon(
              active ? Icons.person_off_outlined : Icons.person_add_alt_1,
              size: 17,
            ),
            label: Text(
              busy
                  ? 'Updating…'
                  : active
                  ? 'Deactivate'
                  : 'Activate',
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SfFormCard(
        child: InkWell(
          onTap: onManage,
          borderRadius: BorderRadius.circular(12),
          child: Semantics(
            button: onManage != null,
            hint: onManage != null ? 'Opens account management' : null,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Wide enough and normal text size: identity on the left, status and action stacked on the right.
                // Narrow screens or enlarged text keep the stacked layout so nothing overflows.
                final roomy =
                    constraints.maxWidth >= 330 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 16;
                if (roomy) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      avatar,
                      const SizedBox(width: 12),
                      Expanded(child: identity),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          pill,
                          if (isSelf)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: action,
                            )
                          else
                            action,
                        ],
                      ),
                      if (onManage != null)
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: SfColors.muted,
                        ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        avatar,
                        const SizedBox(width: 12),
                        Expanded(child: identity),
                        if (onManage != null)
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: SfColors.muted,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [pill, action],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SfAdminProfileQuickLinks extends StatelessWidget {
  const SfAdminProfileQuickLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Quick links',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _link(context, SfIcons.adminHome, 'Home', '/admin'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _link(
                context,
                SfIcons.adminUsers,
                'Users',
                '/admin/users',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _link(
                context,
                SfIcons.adminCoaSummary,
                'Custody summary',
                '/admin/reports',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _link(
                context,
                SfIcons.adminSystem,
                'System status',
                '/admin/system',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _link(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, size: 22, color: SfColors.blue),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String sfAdminLastSyncLabel(DateTime? at) {
  if (at == null) return 'Pull to refresh for latest municipal totals';
  return 'Updated ${formatSmartflowTime(at.toIso8601String())} · pull to refresh';
}

/// Hero card for COA monthly export — defense / accountant wow moment.
class SfCoaExportHero extends StatelessWidget {
  const SfCoaExportHero({
    super.key,
    required this.monthLabel,
    required this.exportAllowed,
    required this.docsInPeriod,
    required this.onExport,
    this.onPrint,
    this.submissionNote = '',
    this.onChangeMonth,
    this.pickerLabel = 'Month',
  });

  final String monthLabel;
  final bool exportAllowed;

  /// Null when the report did not provide the count; it is shown as not verified, never as 0.
  final int? docsInPeriod;
  final VoidCallback? onExport;
  final VoidCallback? onPrint;
  final String submissionNote;
  final VoidCallback? onChangeMonth;
  final String pickerLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onChangeMonth != null) ...[
          SfNavigationRow(
            icon: Icons.calendar_month_outlined,
            title: monthLabel,
            subtitle: 'Change ${pickerLabel.toLowerCase()}',
            onTap: onChangeMonth!,
          ),
          const SizedBox(height: 12),
        ],
        SfFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Report export',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  SfStatusPill(
                    label: exportAllowed ? 'Ready' : 'Restricted',
                    tone: exportAllowed
                        ? SfPillTone.success
                        : SfPillTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                docsInPeriod == null
                    ? 'Activity count not verified'
                    : '$docsInPeriod documents with activity · municipal system',
                style: const TextStyle(fontSize: 13, color: SfColors.muted),
              ),
              if (submissionNote.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  submissionNote,
                  style: const TextStyle(
                    fontSize: 13,
                    color: SfColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (exportAllowed) ...[
                SfPrimaryButton(label: 'Download CSV', onPressed: onExport),
                const SizedBox(height: 8),
                SfSecondaryOutlineButton(
                  label: 'Print / Save PDF',
                  icon: Icons.print_outlined,
                  onPressed: onPrint,
                ),
              ] else
                const Text(
                  'Accounting administrators can export municipal COA summaries.',
                  style: TextStyle(
                    fontSize: 13,
                    color: SfColors.muted,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
