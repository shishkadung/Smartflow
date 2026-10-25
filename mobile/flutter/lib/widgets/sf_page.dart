import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/smartflow_theme.dart';
import 'sf_shell_chrome.dart';
import 'movement_recovery_banner.dart';

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
                      minHeight:
                          constraints.maxHeight -
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
    required this.onMenu,
    required this.onProfile,
    this.menuActive = false,
    this.profileActive = false,
  });

  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onTab;
  final List<SfNavTab> tabs;

  /// Final bottom-navigation action. Opens the role tools sheet.
  final VoidCallback onMenu;

  /// Header action. Opens the signed-in role's Profile.
  final VoidCallback onProfile;

  /// True while a tools-sheet destination is on screen.
  final bool menuActive;

  final bool profileActive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SfColors.bg,
      extendBody: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: SfGradients.pageSky),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SfShellTopBar(onProfile: onProfile, profileActive: profileActive),
            const MovementRecoveryBanner(),
            Expanded(
              child: Builder(
                builder: (context) {
                  final media = MediaQuery.of(context);
                  final keyboardOpen = media.viewInsets.bottom > 0;
                  final inset = keyboardOpen ? 0.0 : media.padding.bottom;
                  final clearance = keyboardOpen
                      ? 0.0
                      : SfBottomNav._raisedClearance;
                  final reserved = (inset - clearance).clamp(0.0, inset);
                  // Page paint continues behind Scan; the solid row stays clear.
                  return Padding(
                    padding: EdgeInsets.only(bottom: reserved),
                    child: MediaQuery(
                      data: media.copyWith(
                        padding: media.padding.copyWith(
                          bottom: inset - reserved,
                        ),
                      ),
                      child: SafeArea(top: false, bottom: false, child: body),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SfBottomNav(
        currentIndex: menuActive ? tabs.length - 1 : currentIndex,
        onTap: (index) => index == tabs.length - 1 ? onMenu() : onTab(index),
        tabs: tabs,
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
  static const _raisedClearance = 26.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final labelSize = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.3).scale(11);
    final contentHeight = 62 + labelSize * 1.1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: SfColors.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: contentHeight > 78 ? contentHeight : 78,
            child: ColoredBox(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _raisedClearance,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: SfColors.paper,
                        border: Border(
                          top: BorderSide(
                            color: SfColors.navy.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(tabs.length, (i) {
                        final t = tabs[i];
                        return Expanded(
                          child: _SfNavTabButton(
                            tab: t,
                            active: i == currentIndex,
                            badge: t.badge,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onTap(i);
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ColoredBox(
            color: SfColors.paper,
            child: SizedBox(height: bottom),
          ),
        ],
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
    final textScaler = MediaQuery.textScalerOf(context);
    final largeText = textScaler.scale(11) > 12;
    final label = Text(
      largeText && tab.label == 'Documents' ? 'Docs' : tab.label,
      semanticsLabel: tab.label,
      // As with native navigation bars, bounded labels retain readable words.
      // Full names remain available to screen readers and in scaled tooltips.
      textScaler: textScaler.clamp(maxScaleFactor: 1.3),
      style: TextStyle(
        fontSize: 11,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        color: active ? SfColors.blue : SfColors.muted,
        height: 1.1,
        letterSpacing: -0.15,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    final Widget iconCore = elevated
        ? SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SfColors.navy,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? const Color(0xFFE8D9B5) : Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SfColors.navy.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(tab.iconFor(true), size: 24, color: Colors.white),
              ),
            ),
          )
        : SizedBox(
            width: 40,
            height: 28,
            child: Icon(
              tab.iconFor(active),
              size: 20,
              color: active ? SfColors.blue : SfColors.muted,
            ),
          );

    return Tooltip(
      message: tab.label,
      excludeFromSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    iconCore,
                    if (badge != null && badge! > 0)
                      Positioned(
                        right: elevated ? -2 : 0,
                        top: elevated ? -2 : -4,
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
                SizedBox(height: elevated ? 2 : 4),
                label,
              ],
            ),
          ),
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
    this.badge,
  }) : assert(route != null || onTap != null);

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? route;
  final Object? extra;
  final VoidCallback? onTap;

  /// Optional count, shown beside the row (pending sign-ups).
  final int? badge;
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
      final largeMenuText = media.textScaler.scale(14) > 20;
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
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SfColors.navy,
                      ),
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SfColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: Column(
                      children: [
                        for (final destination in destinations)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              contentPadding: largeMenuText
                                  ? const EdgeInsets.symmetric(horizontal: 8)
                                  : null,
                              minLeadingWidth: largeMenuText ? 24 : null,
                              horizontalTitleGap: largeMenuText ? 8 : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              leading: Icon(
                                destination.icon,
                                color: SfColors.navy,
                              ),
                              title: Text(
                                destination.title,
                                style: TextStyle(
                                  fontSize: largeMenuText ? 14 : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: destination.subtitle == null
                                  ? null
                                  : Text(destination.subtitle!),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if ((destination.badge ?? 0) > 0)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        right: largeMenuText ? 0 : 8,
                                      ),
                                      child: Text(
                                        '${destination.badge}',
                                        style: const TextStyle(
                                          color: SfColors.red,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  if (!largeMenuText)
                                    const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                HapticFeedback.selectionClick();
                                if (destination.onTap != null) {
                                  destination.onTap!();
                                } else if (destination.route != null) {
                                  context.go(
                                    destination.route!,
                                    extra: destination.extra,
                                  );
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
