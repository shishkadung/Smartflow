import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../data/help_guides.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/sf_icons.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/format_time.dart';
import '../../widgets/sf_help.dart';
import '../../widgets/sf_page.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';

export '../../widgets/sf_account_menu.dart'
    show
        showSfAccountMenu,
        sfProfileRouteForRole,
        sfIsProfileSecurityView,
        sfIsOnProfilePage;

/// Resolve API-relative avatar path to absolute URL.
String? sfAvatarAbsoluteUrl(String? relative) {
  final rel = relative?.trim();
  if (rel == null || rel.isEmpty) return null;
  if (rel.startsWith('http://') || rel.startsWith('https://')) return rel;
  final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
  return '$base/${rel.replaceFirst(RegExp(r'^/+'), '')}';
}

/// PDF clerk header — municipality · SMARTFLOW · page help · document requests · account menu.
/// Office badge opens See profile · Account & security · Log out (web ENG parity).
/// Legacy inline header — shell chrome now lives in [SfShellTopBar].
/// Kept as a no-op so older call sites stay compile-safe.
class SfClerkAppHeader extends StatelessWidget {
  const SfClerkAppHeader({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Alert counts for bottom Alerts tab (provided by each role shell).
class SfNavBadgeScope extends InheritedWidget {
  const SfNavBadgeScope({
    super.key,
    required this.alertCount,
    required super.child,
  });

  final int alertCount;

  static int alertCountOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<SfNavBadgeScope>()
            ?.alertCount ??
        0;
  }

  @override
  bool updateShouldNotify(SfNavBadgeScope oldWidget) =>
      alertCount != oldWidget.alertCount;
}

/// Role Menu sheet — opened from the bottom **Menu** tab (tools, not profile).
Future<void> showSfRoleMoreSheet(BuildContext context) {
  final role = context.read<AuthProvider>().user?.role ?? 'staff';
  final helpPage = sfHelpPageForPath(GoRouterState.of(context).uri.path);
  final requestsRoute = switch (role) {
    'head' => '/head/requests',
    'admin' => '/admin/requests',
    _ => '/staff/requests',
  };

  final shared = <SfMoreDestination>[
    SfMoreDestination(
      icon: Icons.swap_horiz_rounded,
      title: 'Document requests',
      subtitle: 'Inbox and outgoing requests',
      route: requestsRoute,
    ),
    if (helpPage != null)
      SfMoreDestination(
        icon: Icons.help_outline_rounded,
        title: 'How to use this page',
        subtitle: 'Tips for the screen you are on',
        onTap: () => showSfHelpSheet(context, helpPage),
      ),
  ];

  late final List<SfMoreDestination> roleItems;
  late final String subtitle;
  switch (role) {
    case 'head':
      subtitle = 'Scan, register, analytics, and history.';
      roleItems = const [
        SfMoreDestination(
          icon: SfIcons.clerkScan,
          title: 'Scan',
          subtitle: 'Mark IN or OUT when a folder is at your desk',
          route: '/head/scan',
        ),
        SfMoreDestination(
          icon: SfIcons.headRegister,
          title: 'Register document',
          subtitle: 'New folder for your office',
          route: '/head/register',
        ),
        SfMoreDestination(
          icon: SfIcons.headAnalytics,
          title: 'Analytics',
          subtitle: 'Office throughput · delays',
          route: '/head/analytics',
        ),
        SfMoreDestination(
          icon: SfIcons.clerkHistory,
          title: 'History',
          subtitle: 'Browse movements · audit trail',
          route: '/head/history',
        ),
      ];
    case 'admin':
      subtitle = 'Users, register, history, and system tools.';
      roleItems = const [
        SfMoreDestination(
          icon: SfIcons.adminUsers,
          title: 'Users',
          subtitle: 'Approve sign-ups and manage accounts',
          route: '/admin/users',
        ),
        SfMoreDestination(
          icon: SfIcons.clerkRegister,
          title: 'Register document',
          subtitle: 'New folder · get QR ID',
          route: '/admin/register',
        ),
        SfMoreDestination(
          icon: SfIcons.clerkAlerts,
          title: 'Alerts',
          subtitle: 'Late folders across municipal offices',
          route: '/admin/alerts',
        ),
        SfMoreDestination(
          icon: SfIcons.clerkHistory,
          title: 'History',
          subtitle: 'Browse movements · audit trail',
          route: '/admin/history',
        ),
        SfMoreDestination(
          icon: SfIcons.adminOffices,
          title: 'Offices',
          subtitle: 'Municipal offices · health',
          route: '/admin/offices',
        ),
        SfMoreDestination(
          icon: Icons.tune_rounded,
          title: 'Thresholds',
          subtitle: 'Processing time limits',
          route: '/admin/thresholds',
        ),
        SfMoreDestination(
          icon: SfIcons.clerkScan,
          title: 'QR scan monitor',
          subtitle: 'Accepted vs rejected scans',
          route: '/admin/qr-monitor',
        ),
        SfMoreDestination(
          icon: SfIcons.adminSystem,
          title: 'System',
          subtitle: 'API · health · reset tools',
          route: '/admin/system',
        ),
      ];
    default:
      subtitle = 'Register and history.';
      roleItems = const [
        SfMoreDestination(
          icon: SfIcons.clerkRegister,
          title: 'Register document',
          subtitle: 'New folder · get QR ID',
          route: '/staff/register',
        ),
        SfMoreDestination(
          icon: SfIcons.clerkHistory,
          title: 'History',
          subtitle: 'Browse movements · open audit trail',
          route: '/staff/history',
        ),
      ];
  }

  final destinations = [...shared, ...roleItems]..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

  return showSfMoreSheet(
    context,
    title: 'Menu',
    subtitle: subtitle,
    destinations: destinations,
  );
}

/// Role dashboard route (bottom-nav home).
String sfRoleHomeRoute(String? role) {
  switch (role) {
    case 'head':
      return '/head';
    case 'admin':
      return '/admin';
    default:
      return '/staff';
  }
}

/// Primary bottom-nav destinations (not Menu sheet / header-only routes).
bool sfIsPrimaryNavRoute(String path, String? role) {
  switch (role) {
    case 'head':
      return path == '/head' ||
          path == '/head/queue' ||
          path == '/head/alerts';
    case 'admin':
      return path == '/admin' ||
          path == '/admin/scan' ||
          path == '/admin/reports';
    default:
      return path == '/staff' ||
          path == '/staff/scan' ||
          path == '/staff/alerts';
  }
}

/// Where [SfPageBackButton] goes when the stack cannot pop.
String sfPageBackFallback(String path, String? role) {
  final home = sfRoleHomeRoute(role);

  if (path.startsWith('/admin')) {
    if (path == '/admin/thresholds' ||
        path == '/admin/system' ||
        path == '/admin/qr-monitor') {
      return home;
    }
    if (path == '/admin/profile') return home;
    return home;
  }

  if (path.startsWith('/head')) {
    if (path == '/head/profile' || path == '/head/history') return home;
    return home;
  }

  if (path.startsWith('/staff')) {
    if (path == '/staff/profile') return home;
    return home;
  }

  if (path.startsWith('/signup')) return '/login';
  if (path == '/login') return '/';

  return home;
}

/// Consistent back control: pop when possible, otherwise go to role home (or [fallbackRoute]).
class SfPageBackButton extends StatelessWidget {
  const SfPageBackButton({
    super.key,
    this.fallbackRoute,
    this.label,
    this.hideOnRoleHome = true,
  });

  final String? fallbackRoute;
  final String? label;
  /// When true, hides back on primary bottom-nav tabs if nothing to pop.
  final bool hideOnRoleHome;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final role = context.read<AuthProvider>().user?.role;
    final fallback = fallbackRoute ?? sfPageBackFallback(path, role);
    final canPop = context.canPop();
    final onPrimaryTab = sfIsPrimaryNavRoute(path, role);

    if (hideOnRoleHome && onPrimaryTab && !canPop) {
      return const SizedBox.shrink();
    }

    if (!canPop && path == fallback) {
      return const SizedBox.shrink();
    }

    final canGoBack = canPop || path != fallback;

    return Align(
      alignment: Alignment.centerLeft,
      heightFactor: 1,
      child: TextButton.icon(
        onPressed: canGoBack
            ? () {
                if (canPop) {
                  context.pop();
                } else {
                  context.go(fallback);
                }
              }
            : null,
        icon: const Icon(Icons.arrow_back_ios_new, size: 14),
        label: Text(label ?? 'Back'),
        style: TextButton.styleFrom(
          foregroundColor: SfColors.muted,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// Bottom-nav tab top: municipality header + compact ops overview.
class SfClerkTabTitle extends StatelessWidget {
  const SfClerkTabTitle({
    super.key,
    this.title = '',
    this.subtitle,
    this.screen,
  });

  /// Used only when [screen] is null (legacy title row).
  final String title;
  final String? subtitle;

  /// When set, uses the shared compact overview card for that screen.
  final SfClerkScreen? screen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (screen != null)
          SfClerkPageOverviewCard(screen: screen!, compact: true)
        else
          _LegacyTabTitle(
            title: title,
            subtitle: subtitle,
          ),
      ],
    );
  }
}

class _LegacyTabTitle extends StatelessWidget {
  const _LegacyTabTitle({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: SfColors.navy,
              ) ??
              const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: SfColors.navy,
              ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
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

/// Back button + municipality header (most in-app screens).
class SfAuthenticatedPageHeader extends StatelessWidget {
  const SfAuthenticatedPageHeader({
    super.key,
    this.fallbackRoute,
    this.hideBackOnRoleHome = true,
    this.backLabel,
  });

  final String? fallbackRoute;
  final bool hideBackOnRoleHome;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    // Brand / office chrome is [SfShellTopBar] in SfAppScaffold.
    return SfPageBackButton(
      fallbackRoute: fallbackRoute,
      label: backLabel,
      hideOnRoleHome: hideBackOnRoleHome,
    );
  }
}

/// Clerk screens that use the shared overview card (PDF / mockup style).
enum SfClerkScreen {
  home,
  scan,
  register,
  history,
  alerts,
  profile,
  accountSecurity,
  registerSuccess,
  requests,
}

/// Overview card with page-specific copy — same layout on every clerk tab.
class SfClerkPageOverviewCard extends StatelessWidget {
  const SfClerkPageOverviewCard({
    super.key,
    required this.screen,
    this.documentId,
    this.pendingInbox,
    this.compact,
  });

  final SfClerkScreen screen;
  final String? documentId;
  final int? pendingInbox;

  /// When null, ops tabs (Scan / History / Alerts / Requests) default to compact.
  final bool? compact;

  static bool _defaultCompact(SfClerkScreen screen) {
    switch (screen) {
      case SfClerkScreen.scan:
      case SfClerkScreen.history:
      case SfClerkScreen.alerts:
      case SfClerkScreen.requests:
      case SfClerkScreen.register:
        return true;
      case SfClerkScreen.home:
      case SfClerkScreen.profile:
      case SfClerkScreen.accountSecurity:
      case SfClerkScreen.registerSuccess:
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
      case SfClerkScreen.home:
        title = 'Desk';
        body = dashboardSubtitleForOffice(user.officeCode);
      case SfClerkScreen.scan:
        title = 'Scan';
        body = 'Mark IN when a folder arrives · OUT when you send it.';
      case SfClerkScreen.register:
        title = 'Register';
        body = registerSubtitleForOffice(user.officeCode);
      case SfClerkScreen.history:
        title = 'History';
        body = 'Search a tracking ID or open a folder trail.';
      case SfClerkScreen.alerts:
        title = 'Alerts';
        body =
            'Overdue folders, or OUT from ${user.officeCode} with no receive yet.';
      case SfClerkScreen.profile:
        title = 'Profile';
        body = 'Your office account and desk stats.';
      case SfClerkScreen.accountSecurity:
        title = 'Account & security';
        body = 'Photo, name, email, password, or sign out.';
      case SfClerkScreen.registerSuccess:
        title = documentId ?? 'Document registered';
        body = 'Print the QR label and attach it to the folder.';
      case SfClerkScreen.requests:
        title = 'Requests';
        body = requestsSubtitleForOffice(user.officeCode);
    }

    return SfPageOverviewCard(
      title: title,
      body: body,
      compact: useCompact,
    );
  }
}

/// @deprecated Use [SfClerkPageOverviewCard] with [SfClerkScreen.home].
class SfDashboardOverviewCard extends StatelessWidget {
  const SfDashboardOverviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SfClerkPageOverviewCard(screen: SfClerkScreen.home);
  }
}

/// Soft page intro card — same shell on every role screen.
///
/// Soft paper card under the navy shell chrome (avoids double-navy stack).
/// Title + caption always sit inside the card (ops copy stays short).
class SfPageOverviewCard extends StatelessWidget {
  const SfPageOverviewCard({
    super.key,
    this.strap = '',
    required this.title,
    required this.body,
    this.chips = const [],
    this.navHint,
    this.compact = false,
  });

  /// Unused on role screens (kept for call-site compatibility).
  final String strap;
  final String title;
  final String body;
  final List<SfOverviewChipData> chips;
  final String? navHint;

  /// Ops screens: shorter padding; body still shown (one line).
  final bool compact;

  String get _caption {
    final t = body.trim();
    if (t.isEmpty) return t;
    if (!compact) return t;
    final cut = t.indexOf(RegExp(r'[.…]'));
    if (cut > 12 && cut < 96) return t.substring(0, cut + 1);
    if (t.length <= 96) return t;
    return '${t.substring(0, 93).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    final caption = _caption;
    final showCaption = caption.isNotEmpty;
    final highlight = chips.where((c) => c.highlight != null).toList();
    final chip = highlight.isNotEmpty
        ? highlight.first
        : (chips.isNotEmpty ? chips.first : null);
    final padV = compact ? 12.0 : 14.0;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SfColors.navy.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: SfColors.ink.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Navy + gold top rule
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SfColors.navy,
                    SfColors.blue,
                    Color(0xFFC9B896),
                  ],
                ),
              ),
            ),
          ),
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
                      const Color(0xFF1D4ED8).withValues(alpha: 0.10),
                      const Color(0xFF1D4ED8).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, padV + 2, 14, padV),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: compact ? 17 : 18,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: -0.2,
                        color: SfColors.navy,
                      ) ??
                      TextStyle(
                        fontSize: compact ? 17 : 18,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: -0.2,
                        color: SfColors.navy,
                      ),
                ),
                if (showCaption) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 28,
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          SfColors.gold.withValues(alpha: 0.95),
                          SfColors.gold.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    caption,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 12.5 : 13,
                      color: SfColors.muted.withValues(alpha: 0.95),
                      height: 1.4,
                      letterSpacing: 0.05,
                    ),
                  ),
                ],
                if (chip != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: SfColors.navy.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: SfColors.navy.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      chip.trailing == null
                          ? chip.label
                          : '${chip.label} ${chip.trailing}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: chip.highlight ?? SfColors.navy,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SfOverviewChipData {
  const SfOverviewChipData({
    required this.label,
    this.highlight,
    this.trailing,
  });

  final String label;
  final Color? highlight;
  final String? trailing;
}

/// Blue footer hint inside the overview card.
class SfOverviewNavHint extends StatelessWidget {
  const SfOverviewNavHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SfColors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SfColors.blue.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          height: 1.4,
          color: SfColors.blue,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// @deprecated Use [SfOverviewNavHint].
class SfClerkNavHint extends StatelessWidget {
  const SfClerkNavHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const SfOverviewNavHint(
      text:
          'Use the menu below: Scan handoffs · New to register · History · Alerts',
    );
  }
}

class SfOverviewChip extends StatelessWidget {
  const SfOverviewChip({
    super.key,
    required this.label,
    this.highlight,
    this.trailing,
  });

  final String label;
  final Color? highlight;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final hi = highlight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hi == null
            ? SfColors.blue.withValues(alpha: 0.06)
            : hi.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hi == null
              ? SfColors.blue.withValues(alpha: 0.15)
              : hi.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        trailing == null ? label : '$label $trailing',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: hi ?? SfColors.ink,
        ),
      ),
    );
  }
}

class SfClerkSectionHeader extends StatelessWidget {
  const SfClerkSectionHeader({
    super.key,
    required this.title,
    this.link,
    this.onLinkTap,
  });

  final String title;
  final String? link;
  final VoidCallback? onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: SfColors.ink,
          ),
        ),
        const Spacer(),
        if (link != null)
          onLinkTap != null
              ? TextButton(
                  onPressed: onLinkTap,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(link!),
                )
              : Text(
                  link!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SfColors.muted.withValues(alpha: 0.9),
                  ),
                ),
      ],
    );
  }
}

/// PDF 2×2 module grid — QR · HS · AL · Profile.
class SfClerkModuleGrid extends StatelessWidget {
  const SfClerkModuleGrid({
    super.key,
    required this.onScan,
    required this.onRegister,
    required this.onHistory,
    required this.onAlerts,
    required this.onProfile,
  });

  final VoidCallback onScan;
  final VoidCallback onRegister;
  final VoidCallback onHistory;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SfClerkModuleTile(
                code: 'RG',
                icon: SfIcons.moduleRegister,
                iconColor: SfColors.green,
                title: 'Register Document',
                subtitle:
                    'Create a tracking ID and QR for a new folder at your office.',
                onTap: onRegister,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SfClerkModuleTile(
                code: 'QR',
                icon: SfIcons.moduleScan,
                iconColor: const Color(0xFF7C3AED),
                title: 'Scan & Forward',
                subtitle:
                    'Record IN and OUT movements using the in-app scanner.',
                onTap: onScan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SfClerkModuleTile(
                code: 'HS',
                icon: SfIcons.moduleHistory,
                iconColor: SfColors.ink,
                title: 'Document History',
                subtitle:
                    'Review the audit trail of each tracked financial document.',
                onTap: onHistory,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SfClerkModuleTile(
                code: 'AL',
                icon: SfIcons.moduleAlerts,
                iconColor: SfColors.gold,
                title: 'Alerts',
                subtitle: 'See delayed or unconfirmed document movements.',
                onTap: onAlerts,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SfClerkModuleRow(
          code: 'PR',
          title: 'Profile',
          subtitle: 'Account details and sign out.',
          color: SfColors.green,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class SfClerkModuleTile extends StatelessWidget {
  const SfClerkModuleTile({
    super.key,
    required this.code,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
  });

  final String code;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SfColors.paper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: SfColors.blue.withValues(alpha: 0.12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x140F172A)),
            boxShadow: [
              BoxShadow(
                color: SfColors.ink.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: icon != null
                    ? Icon(icon, size: 22, color: iconColor)
                    : Text(
                        code,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: code.length > 2 ? 16 : 14,
                          color: iconColor,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.25,
                  color: SfColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: SfColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three stat pills — received / sent / on desk (clerk home).
class SfDashboardStatRow extends StatelessWidget {
  const SfDashboardStatRow({
    super.key,
    required this.inFlow,
    required this.outFlow,
    required this.activeTags,
    this.onInFlowTap,
    this.onOutFlowTap,
    this.onActiveTap,
    this.hint,
  });

  final String inFlow;
  final String outFlow;
  final String activeTags;
  final VoidCallback? onInFlowTap;
  final VoidCallback? onOutFlowTap;
  final VoidCallback? onActiveTap;
  /// Optional one-line explanation under the row (reduces "why is on desk 0?" confusion).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SfDashboardStatCell(
              value: inFlow,
              label: 'Received',
              sublabel: 'today',
              color: SfColors.countInk(inFlow, live: SfColors.green),
              onTap: onInFlowTap,
            ),
            const SizedBox(width: 8),
            SfDashboardStatCell(
              value: outFlow,
              label: 'Sent',
              sublabel: 'today',
              color: SfColors.countInk(outFlow),
              onTap: onOutFlowTap,
            ),
            const SizedBox(width: 8),
            SfDashboardStatCell(
              value: activeTags,
              label: 'On desk',
              sublabel: 'now',
              color: SfColors.countInk(activeTags, live: SfColors.blue),
              onTap: onActiveTap,
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
}

class SfDashboardStatSkeleton extends StatelessWidget {
  const SfDashboardStatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (_) => Expanded(
          child: Container(
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: SfColors.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x120F172A)),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SfDashboardStatCell extends StatelessWidget {
  const SfDashboardStatCell({
    super.key,
    required this.value,
    required this.label,
    required this.sublabel,
    required this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A0B1F3A)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: SfColors.ink,
            ),
          ),
          Text(
            sublabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: SfColors.muted,
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: onTap == null
          ? cell
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: cell,
              ),
            ),
    );
  }
}

/// Document IN at this office — tap row for history, quick Mark OUT.
class SfClerkActiveDocumentRow extends StatelessWidget {
  const SfClerkActiveDocumentRow({
    super.key,
    required this.documentId,
    required this.title,
    required this.lastScannedAt,
    required this.onTap,
    required this.onMarkOut,
    this.markingOut = false,
  });

  final String documentId;
  final String title;
  final String? lastScannedAt;
  final VoidCallback onTap;
  final VoidCallback onMarkOut;
  final bool markingOut;

  @override
  Widget build(BuildContext context) {
    return SfFormCard(
      padding: const EdgeInsets.all(12),
      flat: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SfColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    SfIcons.moduleScan,
                    size: 20,
                    color: SfColors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: SfColors.muted,
                          height: 1.35,
                        ),
                      ),
                      if (lastScannedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          formatMovementListTime(lastScannedAt),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: SfColors.blue,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: SfColors.muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: markingOut ? null : onMarkOut,
              icon: markingOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.outbound_rounded, size: 18),
              label: Text(markingOut ? 'Forwarding…' : 'Mark OUT (forward)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SfColors.blue,
                side: BorderSide(color: SfColors.blue.withValues(alpha: 0.35)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// In-transit folder — last scan was OUT from another office. Quick Mark IN.
class SfClerkIncomingDocRow extends StatelessWidget {
  const SfClerkIncomingDocRow({
    super.key,
    required this.documentId,
    required this.title,
    required this.fromOfficeCode,
    required this.fromOfficeName,
    required this.outAt,
    required this.onTap,
    required this.onMarkIn,
    this.receiving = false,
    this.sentToOfficeCode,
  });

  final String documentId;
  final String title;
  final String fromOfficeCode;
  final String fromOfficeName;
  final String? outAt;
  final String? sentToOfficeCode;
  final VoidCallback onTap;
  final VoidCallback onMarkIn;
  final bool receiving;

  @override
  Widget build(BuildContext context) {
    final fromColor = SfColors.dept(fromOfficeCode);
    return SfFormCard(
      padding: const EdgeInsets.all(12),
      flat: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SfColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 20,
                    color: SfColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: SfColors.muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: fromColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: fromColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              sentToOfficeCode != null &&
                                      sentToOfficeCode!.isNotEmpty
                                  ? 'OUT · $fromOfficeCode → $sentToOfficeCode'
                                  : 'OUT · $fromOfficeCode',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: fromColor,
                              ),
                            ),
                          ),
                          if (outAt != null)
                            Text(
                              formatMovementListTime(outAt),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: SfColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: SfColors.muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: FilledButton.icon(
              onPressed: receiving ? null : onMarkIn,
              icon: receiving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.call_received_rounded, size: 18),
              label: Text(
                receiving ? 'Receiving…' : 'Mark IN',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: SfColors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty desk state when no documents are IN at the office.
class SfClerkEmptyDeskCard extends StatelessWidget {
  const SfClerkEmptyDeskCard({super.key, this.message});

  /// Optional override; CTA remains Open Scanner.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return SfFormCard(
      flat: true,
      padding: EdgeInsets.zero,
      child: SfEmptyState(
        icon: Icons.inventory_2_outlined,
        title: message ?? 'No folders IN here right now',
        actionLabel: 'Open Scanner',
        onAction: () => context.go('/staff/scan'),
      ),
    );
  }
}

/// Tall quick-action tile — QR / HS in 2-column grid (Figma).
class SfQuickActionTile extends StatelessWidget {
  const SfQuickActionTile({
    super.key,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  final String code;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SfColors.paper,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x140F172A)),
            boxShadow: [
              BoxShadow(
                color: SfColors.ink.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    code,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: SfColors.ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: SfColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact clerk module row — Alerts / Profile (Figma "Clerk modules").
class SfClerkModuleRow extends StatelessWidget {
  const SfClerkModuleRow({
    super.key,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
    this.badge,
  });

  final String code;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SfColors.blue;
    return Material(
      color: SfColors.paper,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x140F172A)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: c,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: SfColors.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: SfColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                SfStatusPill(label: badge!, tone: SfPillTone.warning),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right,
                size: 20,
                color: SfColors.muted.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma clerk header: avatar + office dashboard title (pages 7–10).
class SfClerkPageHeader extends StatelessWidget {
  const SfClerkPageHeader({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final pageTitle = title ?? '${user.officeName} Dashboard';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SfUserAvatar(
              initials: SfUserAvatar.fromName(user.name),
              size: 44,
              color: SfColors.dept(user.officeCode),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMARTFLOW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: SfColors.muted.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pageTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: SfColors.ink,
                      height: 1.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SfColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 10),
        SfDeptBadge(label: user.officeName, officeCode: user.officeCode),
      ],
    );
  }
}

/// Large-letter module tile (QR / HS / AL) from Figma dashboard.
class SfModuleCard extends StatelessWidget {
  const SfModuleCard({
    super.key,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
    this.badge,
  });

  final String code;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SfColors.blue;
    return Material(
      color: SfColors.paper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x140F172A)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    code,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: c,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: SfColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: SfColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                SfStatusPill(
                  label: badge!,
                  tone: SfPillTone.warning,
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.chevron_right,
                color: SfColors.muted.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Request attention only — Scan / Alerts / Requests live in bottom nav + header ⇄.
class SfClerkStartHereCard extends StatelessWidget {
  const SfClerkStartHereCard({
    super.key,
    this.requestStatusHint,
  });

  /// Short update line for My requests (declined / approved / pending).
  final String? requestStatusHint;

  @override
  Widget build(BuildContext context) {
    final hint = requestStatusHint?.trim();
    if (hint == null || hint.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: SfColors.gold.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => context.go('/staff/requests'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 18,
                color: SfColors.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SfColors.ink,
                    height: 1.3,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
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

/// Alert counts row (Alerts tab).
class SfAlertsSummaryRow extends StatelessWidget {
  const SfAlertsSummaryRow({
    super.key,
    required this.delayed,
    required this.dueSoon,
    required this.unconfirmed,
  });

  final int delayed;
  final int dueSoon;
  final int unconfirmed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _countTile(
            label: 'Overdue',
            count: delayed,
            color: SfColors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _countTile(
            label: 'Due soon',
            count: dueSoon,
            color: SfColors.gold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _countTile(
            label: 'No IN scan',
            count: unconfirmed,
            color: SfColors.blue,
          ),
        ),
      ],
    );
  }

  Widget _countTile({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: SfColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alert list filter (Alerts tab).
enum SfAlertFilter { all, delayed, dueSoon, unconfirmed }

/// Filter chips for alert kinds.
class SfAlertFilterChips extends StatelessWidget {
  const SfAlertFilterChips({
    super.key,
    required this.delayed,
    required this.dueSoon,
    required this.unconfirmed,
    required this.selected,
    required this.onSelected,
  });

  final int delayed;
  final int dueSoon;
  final int unconfirmed;
  final SfAlertFilter selected;
  final ValueChanged<SfAlertFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', SfAlertFilter.all, delayed + dueSoon + unconfirmed),
          _chip('Overdue', SfAlertFilter.delayed, delayed),
          _chip('Due soon', SfAlertFilter.dueSoon, dueSoon),
          _chip('No IN scan', SfAlertFilter.unconfirmed, unconfirmed),
        ],
      ),
    );
  }

  Widget _chip(String label, SfAlertFilter value, int count) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label${count > 0 ? ' ($count)' : ''}'),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        selectedColor: SfColors.blue.withValues(alpha: 0.15),
        checkmarkColor: SfColors.blue,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

/// Profile overview — identity + desk stats (photo upload lives on Account & security).
class SfProfileAccountCard extends StatelessWidget {
  const SfProfileAccountCard({
    super.key,
    required this.user,
    this.inFlow,
    this.outFlow,
    this.activeTags,
    this.roleLabel,
    this.deskSectionTitle,
    this.stat1Label,
    this.stat2Label,
    this.stat3Label,
  });

  final AppUser user;
  final String? inFlow;
  final String? outFlow;
  final String? activeTags;
  final String? roleLabel;
  final String? deskSectionTitle;
  final String? stat1Label;
  final String? stat2Label;
  final String? stat3Label;

  @override
  Widget build(BuildContext context) {
    final photo = sfAvatarAbsoluteUrl(user.avatarUrl);
    final roleLine = roleLabel ??
        '${_profileRoleShort(user)} · ${user.officeName} (${user.officeCode})';

    return SfFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SfSquareGradientAvatar(
                initials: SfUserAvatar.fromName(user.name),
                size: 72,
                imageUrl: photo,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: SfColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleLine,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: SfColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SfColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              SfDeptBadge(
                label: user.officeCode,
                officeCode: user.officeCode,
              ),
            ],
          ),
          if (inFlow != null && outFlow != null && activeTags != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              deskSectionTitle ?? "Today's desk (your office)",
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: SfColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statMini(
                    stat1Label ?? 'Received',
                    inFlow!,
                    SfColors.countInk(inFlow, live: SfColors.green),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statMini(
                    stat2Label ?? 'Sent',
                    outFlow!,
                    SfColors.countInk(outFlow),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statMini(
                    stat3Label ?? 'On desk',
                    activeTags!,
                    SfColors.countInk(activeTags, live: SfColors.blue),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statMini(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1A0B1F3A)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: SfColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Shortcuts to main app tabs from Profile (clerk or head).
class SfProfileQuickLinks extends StatelessWidget {
  const SfProfileQuickLinks({super.key, this.forHead = false});

  const SfProfileQuickLinks.head({super.key}) : forHead = true;

  final bool forHead;

  @override
  Widget build(BuildContext context) {
    if (forHead) {
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
                child: _link(
                  context,
                  icon: SfIcons.headHome,
                  label: 'Home',
                  route: '/head',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _link(
                  context,
                  icon: SfIcons.headQueue,
                  label: 'Queue',
                  route: '/head/queue',
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
                  icon: SfIcons.headAlerts,
                  label: 'Alerts',
                  route: '/head/alerts',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _link(
                  context,
                  icon: SfIcons.headAnalytics,
                  label: 'Analytics',
                  route: '/head/analytics',
                ),
              ),
            ],
          ),
        ],
      );
    }

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
              child: _link(
                context,
                icon: SfIcons.clerkHome,
                label: 'Home',
                route: '/staff',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _link(
                context,
                icon: SfIcons.clerkScan,
                label: 'Scan',
                route: '/staff/scan',
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
                icon: SfIcons.clerkHistory,
                label: 'History',
                route: '/staff/history',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _link(
                context,
                icon: SfIcons.clerkAlerts,
                label: 'Alerts',
                route: '/staff/alerts',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _link(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    return Material(
      color: SfColors.paper,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x140F172A)),
          ),
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

/// Full-width logout control for Profile (clerk + head).
class SfProfileLogoutButton extends StatelessWidget {
  const SfProfileLogoutButton({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  Future<void> _confirmAndLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to use SmartFlow on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SfColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true) await onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SfColors.red.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _confirmAndLogout(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SfColors.red.withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 20, color: SfColors.red),
              SizedBox(width: 8),
              Text(
                'Log out',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: SfColors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile photo controls — Account & security only.
class SfProfilePhotoCard extends StatelessWidget {
  const SfProfilePhotoCard({
    super.key,
    required this.user,
    required this.onChangePhoto,
    this.onRemovePhoto,
    this.photoBusy = false,
  });

  final AppUser user;
  final VoidCallback onChangePhoto;
  final VoidCallback? onRemovePhoto;
  final bool photoBusy;

  @override
  Widget build(BuildContext context) {
    final photo = sfAvatarAbsoluteUrl(user.avatarUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Profile photo',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: SfColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        SfFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'JPEG, PNG, or WebP · max 2 MB. Shown on your account menu.',
                style: TextStyle(fontSize: 12, color: SfColors.muted, height: 1.35),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  GestureDetector(
                    onTap: photoBusy ? null : onChangePhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SfSquareGradientAvatar(
                          initials: SfUserAvatar.fromName(user.name),
                          size: 72,
                          imageUrl: photo,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: SfColors.navy,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              photoBusy
                                  ? Icons.hourglass_top_rounded
                                  : Icons.photo_camera_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: photoBusy ? null : onChangePhoto,
                          child: Text(
                            photoBusy
                                ? 'Uploading…'
                                : (user.hasAvatar ? 'Change photo' : 'Upload photo'),
                          ),
                        ),
                        if (user.hasAvatar && onRemovePhoto != null)
                          TextButton(
                            onPressed: photoBusy ? null : onRemovePhoto,
                            child: const Text('Remove'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Session block with logout (Account & security).
class SfProfileSessionCard extends StatelessWidget {
  const SfProfileSessionCard({
    super.key,
    required this.user,
    required this.onLogout,
    this.onChangePassword,
    this.onEditProfile,
    this.onShowTips,
  });

  final AppUser user;
  final Future<void> Function() onLogout;
  final VoidCallback? onChangePassword;
  final VoidCallback? onEditProfile;
  final VoidCallback? onShowTips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Session & security',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: SfColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        SfFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Status', 'Signed in · official session'),
              _row('User', '@${user.username}'),
              _row('App', 'SmartFlow · Municipality of Urbiztondo'),
              if (onEditProfile != null) ...[
                const SizedBox(height: 10),
                _ProfileActionRow(
                  icon: Icons.badge_outlined,
                  iconColor: SfColors.navy,
                  label: 'Edit profile',
                  subtitle: 'Update name, username, and email on office records.',
                  onTap: onEditProfile!,
                ),
              ],
              if (onChangePassword != null) ...[
                const SizedBox(height: 4),
                _ProfileActionRow(
                  icon: Icons.lock_reset_rounded,
                  iconColor: SfColors.blue,
                  label: 'Change password',
                  subtitle: 'Update your sign-in password.',
                  onTap: onChangePassword!,
                ),
              ],
              if (onShowTips != null) ...[
                const SizedBox(height: 4),
                _ProfileActionRow(
                  icon: Icons.menu_book_outlined,
                  iconColor: SfColors.navy,
                  label: 'Show getting-started tips',
                  subtitle:
                      'Role guide (once). Page help is always the top-bar ?.',
                  onTap: onShowTips!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SfProfileLogoutButton(onLogout: onLogout),
      ],
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                k,
                style: const TextStyle(fontSize: 11, color: SfColors.muted),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
                size: 18,
                color: SfColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alert card — open the folder, or remind later (no acknowledge/restore).
///
/// Must use [MainAxisSize.min] — these cards sit inside a [ListView] and a
/// max-height Column expands to a blank white slab (see layout rule).
class SfAlertCardWithActions extends StatelessWidget {
  const SfAlertCardWithActions({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.pill1,
    required this.pill2,
    this.rule,
    this.onOpen,
    this.onRemindLater,
    this.openLabel = 'Open Scan',
  });

  final String title;
  final String subtitle;
  final Color accent;
  final String pill1;
  final String pill2;
  final String? rule;
  final VoidCallback? onOpen;
  final VoidCallback? onRemindLater;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty ? 'Document alert' : title.trim();
    final safeSubtitle = subtitle.trim().isEmpty
        ? 'Open this folder to follow up'
        : subtitle.trim();
    final safeRule = rule?.trim() ?? '';
    final safePill1 = pill1.trim().isEmpty ? 'Needs follow-up' : pill1.trim();
    final safePill2 = pill2.trim().isEmpty ? 'Pending' : pill2.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SfFormCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: SfColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        safeSubtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SfColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SfStatusPill(
                  label: safePill1,
                  tone: SfPillTone.danger,
                ),
                SfStatusPill(
                  label: safePill2,
                  tone: SfPillTone.warning,
                ),
              ],
            ),
            if (safeRule.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                safeRule,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: SfColors.muted.withValues(alpha: 0.9),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (onOpen != null)
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: Text(openLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: SfColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size(0, 40),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (onOpen != null && onRemindLater != null)
                  const SizedBox(width: 8),
                if (onRemindLater != null)
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: onRemindLater,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SfColors.muted,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size(0, 40),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Later'),
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

/// Empty alerts — healthy state.
class SfAlertsHealthyEmptyPanel extends StatelessWidget {
  const SfAlertsHealthyEmptyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const SfEmptyState(
      icon: SfIcons.clerkAlerts,
      title: 'No alerts right now',
    );
  }
}

/// Loaded document context above movement timeline (History tab).
class SfHistoryDocumentSummary extends StatelessWidget {
  const SfHistoryDocumentSummary({
    super.key,
    required this.doc,
    required this.movementCount,
    this.onCopyId,
    this.onOpenScan,
  });

  final Map<String, dynamic> doc;
  final int movementCount;
  final VoidCallback? onCopyId;
  final VoidCallback? onOpenScan;

  @override
  Widget build(BuildContext context) {
    final id = doc['id']?.toString() ?? '';
    final isOverdue = doc['is_overdue'] == true;
    final status = doc['current_status']?.toString() ?? '—';
    final office = doc['current_office_name']?.toString() ?? '—';
    final isIn = status.toUpperCase() == 'IN';

    return SfFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doc['title']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SfColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOverdue)
                const SfStatusPill(label: 'Overdue', tone: SfPillTone.danger),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SfStatusPill(
                label: status.toUpperCase(),
                tone: isIn ? SfPillTone.success : SfPillTone.neutral,
              ),
              SfStatusPill(
                label: office,
                tone: SfPillTone.neutral,
              ),
              SfStatusPill(
                label: '$movementCount scan${movementCount == 1 ? '' : 's'}',
                tone: SfPillTone.neutral,
              ),
            ],
          ),
          if (onCopyId != null || onOpenScan != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onCopyId != null)
                  Expanded(
                    child: SfSecondaryOutlineButton(
                      label: 'Copy ID',
                      onPressed: onCopyId,
                    ),
                  ),
                if (onCopyId != null && onOpenScan != null)
                  const SizedBox(width: 8),
                if (onOpenScan != null)
                  Expanded(
                    child: SfPrimaryButton(
                      label: 'Scanner',
                      onPressed: onOpenScan,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Timeline row for audit trail (page 8).
class SfMovementTimelineTile extends StatelessWidget {
  const SfMovementTimelineTile({
    super.key,
    required this.status,
    required this.officeName,
    required this.officeCode,
    required this.scannedAt,
    required this.username,
    required this.remarks,
    required this.isLast,
    this.destinationOfficeCode,
    this.destinationOfficeName,
  });

  final String status;
  final String officeName;
  final String officeCode;
  final String scannedAt;
  final String username;
  final String remarks;
  final bool isLast;
  final String? destinationOfficeCode;
  final String? destinationOfficeName;

  @override
  Widget build(BuildContext context) {
    final isIn = status.toUpperCase() == 'IN';
    final dotColor = isIn ? SfColors.green : SfColors.blue;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0x1A1D4ED8),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: SfFormCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SfStatusPill(
                          label: status.toUpperCase(),
                          tone: isIn ? SfPillTone.success : SfPillTone.neutral,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$officeName ($officeCode)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!isIn &&
                        destinationOfficeCode != null &&
                        destinationOfficeCode!.isNotEmpty)
                      _line(
                        'To',
                        '${destinationOfficeName ?? destinationOfficeCode} ($destinationOfficeCode)',
                      ),
                    _line('Time', formatMovementListTime(scannedAt)),
                    _line('User', username),
                    _line('Remarks', remarks.isEmpty ? '—' : remarks),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              child: Text(
                k,
                style: const TextStyle(fontSize: 11, color: SfColors.muted),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class SfErrorBanner extends StatelessWidget {
  const SfErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SfColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SfColors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(SfIcons.warning, size: 16, color: SfColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: SfColors.red, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class SfLoadingCard extends StatelessWidget {
  const SfLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SfFormCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBar(widthFactor: 0.55, height: 16),
            const SizedBox(height: 12),
            _ShimmerBar(widthFactor: 0.92),
            const SizedBox(height: 10),
            _ShimmerBar(widthFactor: 0.78),
            const SizedBox(height: 10),
            _ShimmerBar(widthFactor: 0.64),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatefulWidget {
  const _ShimmerBar({this.widthFactor = 1, this.height = 12});

  final double widthFactor;
  final double height;

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return FractionallySizedBox(
          widthFactor: widget.widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment(-1 + 2 * _c.value, 0),
                end: Alignment(1 + 2 * _c.value, 0),
                colors: const [
                  Color(0xFFE8EEF6),
                  Color(0xFFF4F7FB),
                  Color(0xFFE8EEF6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String clerkRoleLabel(AppUser user) =>
    'Employee (Clerk) · ${user.officeCode}';

String headRoleLabel(AppUser user) =>
    'Department Head · ${user.officeCode}';

String _profileRoleShort(AppUser user) {
  switch (user.role) {
    case 'head':
      return 'Department Head';
    case 'admin':
      return 'Administrator';
    default:
      return 'Clerk';
  }
}