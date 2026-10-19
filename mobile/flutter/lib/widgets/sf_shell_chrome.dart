import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/sf_icons.dart';
import '../theme/smartflow_theme.dart';
import 'sf_widgets.dart';

/// Solid navy top chrome — seal, office name, and Profile.
///
/// Edge-to-edge under the status bar so seal / office name read as one
/// municipal header (same idea as web `.shell-brand` + `.topbar`).
class SfShellTopBar extends StatelessWidget {
  const SfShellTopBar({
    super.key,
    required this.onProfile,
    this.profileActive = false,
  });

  final VoidCallback onProfile;
  final bool profileActive;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    final topInset = MediaQuery.paddingOf(context).top;
    final iconColor = profileActive ? const Color(0xFFE8D9B5) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: SfColors.bg,
      ),
      child: Container(
        width: double.infinity,
        color: SfColors.navy,
        padding: EdgeInsets.fromLTRB(14, topInset + 10, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SfLguSeal(size: 36, elevated: false, lightPlate: true),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                user.role == 'admin' ? 'Municipal Admin' : user.officeName,
                maxLines: MediaQuery.textScalerOf(context).scale(17) > 22
                    ? 2
                    : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Profile',
              child: IconButton(
                tooltip: 'Profile',
                onPressed: onProfile,
                icon: Icon(
                  profileActive ? SfIcons.profileActive : SfIcons.profile,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
