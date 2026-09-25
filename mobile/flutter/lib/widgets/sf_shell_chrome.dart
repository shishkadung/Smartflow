import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/help_guides.dart';
import '../providers/auth_provider.dart';
import '../theme/smartflow_theme.dart';
import 'sf_account_menu.dart';
import 'sf_help.dart';
import 'sf_widgets.dart';

/// Solid navy top chrome — mobile twin of the web brand + office topbar.
///
/// Edge-to-edge under the status bar so seal / SmartFlow / office name read as
/// one municipal header (same idea as web `.shell-brand` + `.topbar`).
class SfShellTopBar extends StatelessWidget {
  const SfShellTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    final loc = GoRouterState.of(context).uri.path;
    final onProfile = sfIsOnProfilePage(loc, user.role);
    final topInset = MediaQuery.paddingOf(context).top;
    final helpPage = sfHelpPageForPath(loc) ??
        (user.role == 'admin' ? SfHelpPage.adminHome : SfHelpPage.home);
    final requestsRoute = switch (user.role) {
      'head' => '/head/requests',
      'admin' => '/admin/requests',
      _ => '/staff/requests',
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: SfColors.bg,
      ),
      child: Container(
        width: double.infinity,
        color: SfColors.navy,
        padding: EdgeInsets.fromLTRB(14, topInset + 10, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SfLguSeal(size: 36, elevated: false, lightPlate: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.officeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Source Serif 4',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      height: 1.15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const SfSmartFlowWordmark(fontSize: 13, onDark: true),
                ],
              ),
            ),
            IconButton(
              tooltip: 'How to use this page',
              onPressed: () => showSfHelpSheet(context, helpPage),
              icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Document requests',
              onPressed: () => context.go(requestsRoute),
              icon: Icon(
                Icons.swap_horiz_rounded,
                color: loc == requestsRoute ? const Color(0xFFE8D9B5) : Colors.white,
              ),
            ),
            SfOfficeCodeBadge(
              code: user.officeCode,
              tooltip: '${user.officeName} · Account menu',
              active: onProfile,
              onNavy: true,
              onTap: () => showSfAccountMenu(context),
            ),
          ],
        ),
      ),
    );
  }
}
