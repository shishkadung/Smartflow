import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../theme/sf_icons.dart';
import '../theme/smartflow_theme.dart';
import 'sf_widgets.dart';

String? _avatarAbs(String? relative) {
  final rel = relative?.trim();
  if (rel == null || rel.isEmpty) return null;
  if (rel.startsWith('http://') || rel.startsWith('https://')) return rel;
  final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
  return '$base/${rel.replaceFirst(RegExp(r'^/+'), '')}';
}

/// Profile route for the signed-in role.
/// Pass [security] true for Account & security (`?view=security`).
String sfProfileRouteForRole(String role, {bool security = false}) {
  final base = switch (role) {
    'head' => '/head/profile',
    'admin' => '/admin/profile',
    _ => '/staff/profile',
  };
  return security ? '$base?view=security' : base;
}

bool sfIsProfileSecurityView(BuildContext context) =>
    GoRouterState.of(context).uri.queryParameters['view'] == 'security';

bool sfIsOnProfilePage(String path, String role) =>
    path == sfProfileRouteForRole(role);

String _accountRoleLine({
  required String role,
  required String officeCode,
}) {
  switch (role) {
    case 'admin':
      return 'Municipal Accountant · $officeCode';
    case 'head':
      return 'Department Head · $officeCode';
    default:
      return 'Employee (Clerk) · $officeCode';
  }
}

/// Account menu from the office badge — See profile · Account & security · Log out.
Future<void> showSfAccountMenu(BuildContext context) {
  final user = context.read<AuthProvider>().user!;
  final roleLine = _accountRoleLine(
    role: user.role,
    officeCode: user.officeCode,
  );

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
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          context.go(sfProfileRouteForRole(user.role));
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Row(
                            children: [
                              SfUserAvatar(
                                initials: SfUserAvatar.fromName(user.name),
                                size: 44,
                                color: SfColors.dept(user.officeCode),
                                imageUrl: _avatarAbs(user.avatarUrl),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: SfColors.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      roleLine,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: SfColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: SfColors.muted.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.go(sfProfileRouteForRole(user.role));
                      },
                      icon: const Icon(SfIcons.moduleProfile, size: 18),
                      label: const Text('See profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SfColors.navy,
                        side: BorderSide(
                          color: SfColors.navy.withValues(alpha: 0.18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  _AccountMenuTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'Account & security',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go(
                        sfProfileRouteForRole(user.role, security: true),
                      );
                    },
                  ),
                  _AccountMenuTile(
                    icon: SfIcons.logout,
                    label: 'Log out',
                    danger: true,
                    onTap: () async {
                      Navigator.pop(sheetContext);
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
                              style: FilledButton.styleFrom(
                                backgroundColor: SfColors.red,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Log out'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await context.read<AuthProvider>().logout();
                        if (context.mounted) context.go('/login');
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      'Municipality of Urbiztondo · SmartFlow',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: SfColors.muted.withValues(alpha: 0.85),
                      ),
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

class _AccountMenuTile extends StatelessWidget {
  const _AccountMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? SfColors.red : SfColors.navy;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: color,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
