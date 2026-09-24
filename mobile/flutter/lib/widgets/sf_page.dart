import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/smartflow_theme.dart';

/// Auth-style page chrome: gradient sky + Material/Scaffold (so TextField works)
/// + scrollable content. Real device status bar is preserved by SafeArea.
class SfPage extends StatelessWidget {
  const SfPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    @Deprecated('Real device status bar is used; this flag is ignored.')
    this.showStatusBar = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool showStatusBar;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: SfColors.bg,
      ),
      child: Scaffold(
        // Match gradient bottom so nothing shows black if layout shifts.
        backgroundColor: SfColors.bg,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: double.infinity,
              height: constraints.maxHeight,
              decoration: const BoxDecoration(gradient: SfGradients.pageSky),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: padding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight -
                          MediaQuery.paddingOf(context).top -
                          MediaQuery.paddingOf(context).bottom -
                          padding.vertical,
                    ),
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Backwards-compatible no-op so existing `SfStatusBar()` calls compile.
/// The real device already draws the status bar; we don't need a fake one.
class SfStatusBar extends StatelessWidget {
  const SfStatusBar({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SfAppScaffold extends StatelessWidget {
  const SfAppScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onTab,
    required this.tabs,
  });

  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onTab;
  final List<SfNavTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SfColors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: SfGradients.pageSky),
        child: SafeArea(
          bottom: false,
          child: body,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: SfBottomNav(
          currentIndex: currentIndex,
          onTap: onTab,
          tabs: tabs,
        ),
      ),
    );
  }
}

class SfNavTab {
  const SfNavTab({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge,
    this.elevated = false,
  });

  /// Icon when tab is inactive (outlined style).
  final IconData icon;

  /// Icon when tab is active; defaults to [icon].
  final IconData? activeIcon;

  final String label;
  final int? badge;

  /// Slightly raised “primary job” control (e.g. clerk Scan).
  final bool elevated;

  IconData iconFor(bool active) => active ? (activeIcon ?? icon) : icon;
}

class SfBottomNav extends StatelessWidget {
  const SfBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<SfNavTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SfColors.navy.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: SfColors.ink.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == currentIndex;
          final t = tabs[i];
          final badge = t.badge;
          return Expanded(
            child: _SfNavTabButton(
              tab: t,
              active: active,
              badge: badge,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(i);
              },
            ),
          );
        }),
      ),
    );
  }
}

class _SfNavTabButton extends StatelessWidget {
  const _SfNavTabButton({
    required this.tab,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final SfNavTab tab;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final elevated = tab.elevated;
    final iconSize = elevated ? 22.0 : 20.0;

    Widget iconCore;
    if (elevated) {
      iconCore = Transform.translate(
        offset: const Offset(0, -6),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? SfColors.navy : SfColors.paper,
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? SfColors.navy
                  : SfColors.navy.withValues(alpha: 0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: SfColors.navy.withValues(alpha: active ? 0.28 : 0.1),
                blurRadius: active ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            tab.iconFor(active),
            size: iconSize,
            color: active ? Colors.white : SfColors.navy,
          ),
        ),
      );
    } else if (active) {
      iconCore = Container(
        width: 40,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: SfColors.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          tab.iconFor(true),
          size: iconSize,
          color: Colors.white,
        ),
      );
    } else {
      iconCore = SizedBox(
        width: 40,
        height: 32,
        child: Icon(
          tab.iconFor(false),
          size: iconSize,
          color: SfColors.muted,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: elevated ? 2 : 4,
          horizontal: 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                iconCore,
                if (badge != null && badge! > 0)
                  Positioned(
                    right: elevated ? 0 : 2,
                    top: elevated ? -2 : -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: SfColors.red,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 14,
                      ),
                      child: Text(
                        badge! > 9 ? '9+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: elevated ? 0 : 4),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? SfColors.navy : SfColors.muted,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Destination shown in the role “More” sheet.
class SfMoreDestination {
  const SfMoreDestination({
    required this.icon,
    required this.title,
    this.route,
    this.subtitle,
    this.extra,
    this.onTap,
  }) : assert(route != null || onTap != null);

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? route;
  final Object? extra;
  final VoidCallback? onTap;
}

/// Secondary destinations sheet — same pattern for clerk / head / admin.
Future<void> showSfMoreSheet(
  BuildContext context, {
  required String title,
  required List<SfMoreDestination> destinations,
  String subtitle = 'Secondary tools and account.',
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final bottom = media.padding.bottom;
      final maxH = media.size.height * 0.85;
      return Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottom),
        child: Material(
          color: SfColors.paper,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SfColors.muted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SfColors.navy,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SfColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...destinations.map((d) {
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SfColors.navy.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(d.icon, color: SfColors.navy, size: 22),
                      ),
                      title: Text(
                        d.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: SfColors.ink,
                        ),
                      ),
                      subtitle: d.subtitle == null
                          ? null
                          : Text(
                              d.subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: SfColors.muted,
                              ),
                            ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: SfColors.muted.withValues(alpha: 0.6),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        HapticFeedback.selectionClick();
                        if (d.onTap != null) {
                          d.onTap!();
                          return;
                        }
                        final route = d.route;
                        if (route == null) return;
                        if (d.extra != null) {
                          context.go(route, extra: d.extra);
                        } else {
                          context.go(route);
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
