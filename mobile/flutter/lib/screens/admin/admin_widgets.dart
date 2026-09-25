import 'package:flutter/material.dart';
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
  });

  final SfAdminScreen screen;
  final int? pendingSignups;
  final int? pendingInbox;

  /// When null, ops/config screens default to compact; Home / Reports / Profile stay full.
  final bool? compact;

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
        title = 'Municipal dashboard';
        body = 'Active custody across municipal offices.';
      case SfAdminScreen.scan:
        title = 'Scan';
        body = 'Mark IN when a folder arrives at your office, or OUT when you send it.';
      case SfAdminScreen.register:
        title = 'Register';
        body = 'New folder for your office. Print the QR and attach it to the folder.';
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
        title = 'COA reports';
        body =
            'Monthly handoff metrics from scan logs — not a financial review.';
      case SfAdminScreen.thresholds:
        title = 'Thresholds';
        body = 'Max hours per office and document type.';
      case SfAdminScreen.qrMonitor:
        title = 'QR monitor';
        body = 'Accepted and rejected scans (last 48 hours).';
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
      body: body,
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
        Row(
          children: [
            Expanded(
              child: _tappable(
                onTap: onActiveDocsTap,
                child: SfStatCard(
                  value: '$activeDocs',
                  label: 'Active',
                  color: SfColors.countInk(activeDocs, live: SfColors.blue),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tappable(
                onTap: onOverdueTap,
                child: SfStatCard(
                  value: '$overdue',
                  label: 'Overdue',
                  color: SfColors.countInk(overdue, live: SfColors.red),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tappable(
                onTap: onPendingTap,
                child: SfStatCard(
                  value: pendingSignups > 0 ? '$pendingSignups' : '—',
                  label: 'Sign-ups',
                  color: SfColors.navy,
                ),
              ),
            ),
          ],
        ),
        if (hint != null && hint!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            style: const TextStyle(
              fontSize: 11,
              color: SfColors.muted,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _tappable({VoidCallback? onTap, required Widget child}) {
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
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
                      ? 'API online · municipal system reachable'
                      : 'API offline · check XAMPP / LAN before demos',
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
  const SfAdminStartHereCard({
    super.key,
    required this.pendingSignups,
  });

  final int pendingSignups;

  @override
  Widget build(BuildContext context) {
    if (pendingSignups <= 0) {
      return const SizedBox.shrink();
    }

    return Material(
      color: SfColors.paper,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.go('/admin/users'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: SfColors.gold.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: SfColors.ink.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SfColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: SfColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Review sign-up requests',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: SfColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$pendingSignups pending approval',
                      style: const TextStyle(
                        fontSize: 11,
                        color: SfColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: SfColors.muted,
              ),
            ],
          ),
        ),
      ),
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
    final dept = SfColors.dept(code);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SfFormCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border(
                left: BorderSide(color: dept, width: 4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: SfColors.ink,
                        ),
                      ),
                      Text(
                        code,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: dept,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$inOffice on desk · $overdue overdue',
                        style: const TextStyle(
                          fontSize: 11,
                          color: SfColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (overdue > 0)
                  const SfStatusPill(
                    label: 'Follow up',
                    tone: SfPillTone.warning,
                  )
                else if (inOffice == 0 && docsProcessed == 0)
                  const SfStatusPill(
                    label: 'No activity',
                    tone: SfPillTone.neutral,
                  )
                else
                  const SfStatusPill(label: 'On track', tone: SfPillTone.success),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
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
  });

  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

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
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: SfColors.ink,
                    ),
                  ),
                ),
                const SfStatusPill(label: 'Pending', tone: SfPillTone.warning),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Wants $role · $office${officeCode.isNotEmpty ? ' ($officeCode)' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: SfColors.muted,
                height: 1.35,
              ),
            ),
            if (code.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SfColors.navy,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SfSecondaryOutlineButton(
                    label: 'Reject',
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SfPrimaryButton(
                    label: 'Approve',
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Active / inactive municipal user row — job-first card (not a plain ListTile).
class SfAdminUserCard extends StatelessWidget {
  const SfAdminUserCard({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final username = user['username']?.toString() ?? '—';
    final role = user['role']?.toString() ?? '—';
    final office = user['office_name']?.toString() ?? '';
    final code = user['office_code']?.toString() ?? '';
    final active = user['is_active'] as bool? ?? true;
    final dept = SfColors.dept(code.isNotEmpty ? code : 'ENG');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SfFormCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dept.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                code.isNotEmpty ? code.substring(0, code.length.clamp(0, 3)) : '?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: dept,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: SfColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$role · $office',
                    style: const TextStyle(
                      fontSize: 12,
                      color: SfColors.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SfStatusPill(
              label: active ? 'Active' : 'Inactive',
              tone: active ? SfPillTone.success : SfPillTone.neutral,
            ),
          ],
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
              child: _link(context, SfIcons.adminUsers, 'Users', '/admin/users'),
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
                'COA summary',
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
                  fontSize: 11,
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
    required this.onTimePercent,
    required this.delayedPercent,
    required this.docsInPeriod,
    required this.onExport,
    this.submissionNote = '',
    this.onChangeMonth,
  });

  final String monthLabel;
  final bool exportAllowed;
  final int onTimePercent;
  final int delayedPercent;
  final int docsInPeriod;
  final VoidCallback onExport;
  final String submissionNote;
  final VoidCallback? onChangeMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A0B1F3A)),
        boxShadow: [
          BoxShadow(
            color: SfColors.ink.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF5F8FC),
                  Color(0xFFEEF3FA),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -28,
                  top: -36,
                  child: IgnorePointer(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            SfColors.blue.withValues(alpha: 0.10),
                            SfColors.blue.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -28,
                  child: IgnorePointer(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            SfColors.rule.withValues(alpha: 0.22),
                            SfColors.rule.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 12,
                  bottom: 12,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          SfColors.rule.withValues(alpha: 0.35),
                          SfColors.gold,
                          SfColors.rule.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COA SUPPORT SUMMARY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: SfColors.gold.withValues(alpha: 0.95),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              monthLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: SfColors.navy,
                                    height: 1.15,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 28,
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [SfColors.gold, Color(0x00B8860B)],
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '$docsInPeriod documents with activity · municipal system',
                              style: const TextStyle(
                                fontSize: 12,
                                color: SfColors.muted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onChangeMonth != null)
                        TextButton(
                          onPressed: onChangeMonth,
                          style: TextButton.styleFrom(
                            foregroundColor: SfColors.gold,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Month',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CoaStatChip(
                        label: 'On time',
                        value: '$onTimePercent%',
                        tone: SfColors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CoaStatChip(
                        label: 'Delayed',
                        value: '$delayedPercent%',
                        tone: SfColors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CoaStatChip(
                        label: 'Export',
                        value: exportAllowed ? 'Ready' : 'Locked',
                        tone: exportAllowed ? SfColors.blue : SfColors.muted,
                      ),
                    ),
                  ],
                ),
                if (submissionNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    submissionNote,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: SfColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (exportAllowed)
                  SfPrimaryButton(
                    label: 'Copy summary for COA',
                    onPressed: onExport,
                  )
                else
                  const Text(
                    'Only Accounting administrators can copy municipal COA summaries.',
                    style: TextStyle(fontSize: 12, color: SfColors.muted, height: 1.4),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoaStatChip extends StatelessWidget {
  const _CoaStatChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: tone,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: tone == SfColors.muted ? SfColors.ink : tone,
            ),
          ),
        ],
      ),
    );
  }
}
