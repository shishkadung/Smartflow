import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

  /// Icon when tab is inactive (outlined style).
  final IconData icon;

  /// Icon when tab is active; defaults to [icon].
  final IconData? activeIcon;

  final String label;
  final int? badge;

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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1A1D4ED8)),
        boxShadow: [
          BoxShadow(
            color: SfColors.ink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (i) {
          final active = i == currentIndex;
          final t = tabs[i];
          final badge = t.badge;
          final compact = tabs.length > 4;
          return InkWell(
            onTap: () => onTap(i),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 6,
                vertical: 6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (active)
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: SfGradients.brandTitle,
                            boxShadow: [
                              BoxShadow(
                                color: SfColors.blue.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            t.iconFor(true),
                            size: 20,
                            color: Colors.white,
                          ),
                        )
                      else
                        Icon(
                          t.iconFor(false),
                          size: 22,
                          color: SfColors.muted,
                        ),
                      if (badge != null && badge > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: SfColors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              badge > 9 ? '9+' : '$badge',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.label,
                    style: TextStyle(
                      fontSize: compact ? 9 : 10,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? SfColors.ink : SfColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
