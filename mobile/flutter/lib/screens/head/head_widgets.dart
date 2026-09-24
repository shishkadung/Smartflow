import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/format_time.dart';
import '../../widgets/sf_widgets.dart';
import '../staff/clerk_widgets.dart';

/// Head (department supervisor) screens using the shared overview card layout.
enum SfHeadScreen {
  home,
  register,
  queue,
  alerts,
  analytics,
  profile,
  accountSecurity,
  history,
  registerSuccess,
  requests,
}

/// Overview card with page-specific copy for department heads.
class SfHeadPageOverviewCard extends StatelessWidget {
  const SfHeadPageOverviewCard({
    super.key,
    required this.screen,
    this.documentId,
    this.pendingInbox,
    this.compact,
  });

  final SfHeadScreen screen;
  final String? documentId;
  final int? pendingInbox;

  /// When null, Queue / Alerts / History / Requests / Register default to compact.
  final bool? compact;

  static bool _defaultCompact(SfHeadScreen screen) {
    switch (screen) {
      case SfHeadScreen.queue:
      case SfHeadScreen.alerts:
      case SfHeadScreen.history:
      case SfHeadScreen.requests:
      case SfHeadScreen.register:
        return true;
      case SfHeadScreen.home:
      case SfHeadScreen.analytics:
      case SfHeadScreen.profile:
      case SfHeadScreen.accountSecurity:
      case SfHeadScreen.registerSuccess:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final useCompact = compact ?? _defaultCompact(screen);

    late final String title;
    late final String body;

    switch (screen) {
      case SfHeadScreen.home:
        title = 'Office queue';
        body = headDashboardSubtitleForOffice(user.officeCode);
      case SfHeadScreen.register:
        title = 'Register a document folder';
        body = registerSubtitleForOffice(user.officeCode);
      case SfHeadScreen.queue:
        title = 'Office queue';
        body = headQueueSubtitleForOffice(user.officeCode);
      case SfHeadScreen.alerts:
        title = 'Alerts';
        body =
            'Overdue IN, or OUT from ${user.officeCode} with no receive yet.';
      case SfHeadScreen.analytics:
        title = 'Turnaround & compliance';
        body = 'Monthly on-time rate and slow documents for your office.';
      case SfHeadScreen.history:
        title = 'History';
        body = 'Look up every IN and OUT scan by tracking ID.';
      case SfHeadScreen.profile:
        title = 'Your profile';
        body =
            'Office account snapshot. Photo and edits are under Account & security.';
      case SfHeadScreen.accountSecurity:
        title = 'Account & security';
        body = 'Photo, name, email, password, or end this session.';
      case SfHeadScreen.registerSuccess:
        title = documentId ?? 'Document registered';
        body = 'Print the QR label and attach it to the folder.';
      case SfHeadScreen.requests:
        title = 'Document requests';
        body = headRequestsSubtitleForOffice(user.officeCode);
    }

    return SfPageOverviewCard(
      title: title,
      body: body,
      compact: useCompact,
    );
  }

}

/// Three stat tiles for head home dashboard (optional tap → filtered queue).
/// Head queue: OUT from this office awaiting receive scan at destination.
bool headQueueAwaitingReceive(Map<String, dynamic> item) {
  final meta = item['meta']?.toString().toLowerCase() ?? '';
  return item['last_status'] == 'OUT' && meta.contains('awaiting receive');
}

class SfHeadStatRow extends StatelessWidget {
  const SfHeadStatRow({
    super.key,
    required this.inOffice,
    required this.overdue,
    required this.avgHours,
    this.onInOfficeTap,
    this.onOverdueTap,
  });

  final int inOffice;
  final int overdue;
  final double avgHours;
  final VoidCallback? onInOfficeTap;
  final VoidCallback? onOverdueTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _tappableStat(
            onTap: onInOfficeTap,
            child: SfStatCard(
              value: '$inOffice',
              label: 'In office',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _tappableStat(
            onTap: onOverdueTap,
            child: SfStatCard(
              value: '$overdue',
              label: 'Overdue',
              color: overdue > 0 ? SfColors.red : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SfStatCard(
            value: '${avgHours}h',
            label: 'Avg time',
            color: SfColors.green,
          ),
        ),
      ],
    );
  }

  Widget _tappableStat({VoidCallback? onTap, required Widget child}) {
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

enum SfHeadQueueFilter { all, inOffice, overdue, forwarded }

class SfHeadQueueFilterChips extends StatelessWidget {
  const SfHeadQueueFilterChips({
    super.key,
    required this.total,
    required this.inOffice,
    required this.overdue,
    required this.forwarded,
    required this.selected,
    required this.onSelected,
  });

  final int total;
  final int inOffice;
  final int overdue;
  final int forwarded;
  final SfHeadQueueFilter selected;
  final ValueChanged<SfHeadQueueFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', SfHeadQueueFilter.all, total),
          const SizedBox(width: 8),
          _chip('In office', SfHeadQueueFilter.inOffice, inOffice),
          const SizedBox(width: 8),
          _chip('Overdue', SfHeadQueueFilter.overdue, overdue),
          const SizedBox(width: 8),
          _chip('Awaiting receive', SfHeadQueueFilter.forwarded, forwarded),
        ],
      ),
    );
  }

  Widget _chip(String label, SfHeadQueueFilter value, int count) {
    final isSelected = selected == value;
    final chipLabel = '$label${count > 0 ? ' ($count)' : ''}';
    return Material(
      color: isSelected ? SfColors.blue.withValues(alpha: 0.15) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? SfColors.blue.withValues(alpha: 0.35)
                  : const Color(0x220F172A),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check_rounded, size: 14, color: SfColors.blue),
                const SizedBox(width: 6),
              ],
              Text(
                chipLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? SfColors.blue : SfColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Staff scans today (head home).
class SfHeadStaffActivityList extends StatelessWidget {
  const SfHeadStaffActivityList({
    super.key,
    required this.scans,
    required this.onTapDoc,
  });

  final List<Map<String, dynamic>> scans;
  final ValueChanged<String> onTapDoc;

  @override
  Widget build(BuildContext context) {
    if (scans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SfClerkSectionHeader(title: 'Staff activity today'),
        const SizedBox(height: 8),
        ...scans.take(6).map((m) {
          final docId = m['document_id']?.toString() ?? '';
          final st = m['status']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SfFormCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: InkWell(
                onTap: docId.isEmpty ? null : () => onTapDoc(docId),
                child: Row(
                  children: [
                    SfStatusPill(
                      label: st == 'OUT' ? 'SENT' : 'IN',
                      tone: st == 'IN'
                          ? SfPillTone.success
                          : SfPillTone.danger,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            docId,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            movementScanSubtitle(m),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: SfColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: SfColors.muted),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Forwarded OUT awaiting receive scan (head home).
class SfHeadForwardedPreview extends StatelessWidget {
  const SfHeadForwardedPreview({
    super.key,
    required this.items,
    required this.onTapItem,
    required this.onViewAll,
  });

  final List<Map<String, dynamic>> items;
  final ValueChanged<String> onTapItem;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SfClerkSectionHeader(
          title: 'Forwarded · awaiting receive',
          link: 'View queue',
          onLinkTap: onViewAll,
        ),
        const SizedBox(height: 6),
        const Text(
          'OUT from your office with no IN scan at the next office yet.',
          style: TextStyle(fontSize: 11.5, color: SfColors.muted, height: 1.4),
        ),
        const SizedBox(height: 8),
        ...items.take(3).map((m) {
          final id = m['document_id']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SfFormCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: InkWell(
                onTap: () => onTapItem(id),
                child: Row(
                  children: [
                    const Icon(
                      Icons.outbound_rounded,
                      size: 18,
                      color: SfColors.gold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            id,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            m['meta']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              color: SfColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: SfColors.muted),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Queue row for head — tap opens audit trail.
class SfHeadQueueRow extends StatelessWidget {
  const SfHeadQueueRow({
    super.key,
    required this.documentId,
    required this.title,
    required this.type,
    required this.meta,
    required this.statusLabel,
    required this.statusPill,
    required this.hoursPending,
    required this.onTap,
    this.onCopyId,
  });

  final String documentId;
  final String title;
  final String type;
  final String meta;
  final String statusLabel;
  final String statusPill;
  final int hoursPending;
  final VoidCallback onTap;
  final VoidCallback? onCopyId;

  @override
  Widget build(BuildContext context) {
    final overdue = statusLabel == 'overdue';
    final forwarded = statusPill == 'On time' && meta.contains('Forwarded');
    final accent = overdue
        ? SfColors.red
        : (forwarded ? SfColors.gold : SfColors.green);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SfFormCard(
        padding: EdgeInsets.zero,
        flat: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: accent, width: 4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentId.isNotEmpty ? documentId : '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: SfColors.ink,
                        ),
                      ),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: SfColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: SfColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SfStatusPill(
                      label: statusPill.isNotEmpty ? statusPill : '—',
                      tone: overdue
                          ? SfPillTone.danger
                          : (forwarded
                              ? SfPillTone.warning
                              : SfPillTone.success),
                    ),
                    if (hoursPending > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${hoursPending}h',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                    if (onCopyId != null) ...[
                      IconButton(
                        onPressed: onCopyId,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        color: SfColors.muted,
                        tooltip: 'Copy ID',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: SfColors.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact overdue preview on head home.
class SfHeadOverduePreview extends StatelessWidget {
  const SfHeadOverduePreview({
    super.key,
    required this.items,
    required this.onTapItem,
    required this.onViewAll,
  });

  final List<Map<String, dynamic>> items;
  final ValueChanged<String> onTapItem;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SfClerkSectionHeader(
          title: 'Overdue in office',
          link: 'View queue',
          onLinkTap: onViewAll,
        ),
        const SizedBox(height: 8),
        ...items.take(3).map((m) {
          final id = m['document_id']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SfFormCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: InkWell(
                onTap: () => onTapItem(id),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: SfColors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            id,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            m['meta']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              color: SfColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: SfColors.muted),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
