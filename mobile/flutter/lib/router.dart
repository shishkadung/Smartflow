import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'theme/smartflow_theme.dart';
import 'screens/admin/admin_qr_monitor_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/get_started_screen.dart';
import 'screens/auth/forced_password_change_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/head/head_shell.dart';
import 'screens/shared/document_register_screen.dart';
import 'screens/shared/document_requests_screen.dart';
import 'screens/shared/documents_screen.dart';
import 'screens/shared/office_checklists_screen.dart';
import 'screens/staff/scanner_screen.dart';
import 'screens/staff/staff_shell.dart';

GoRouter createRouter(AuthProvider auth) {
  final modals = _SessionModalObserver();
  final staffModals = _SessionModalObserver();
  final headModals = _SessionModalObserver();
  final adminModals = _SessionModalObserver();
  return GoRouter(
    observers: [modals],
    initialLocation: '/',
    refreshListenable: auth,
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: SfColors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: SfGradients.pageSky),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: SfColors.blue),
                const SizedBox(height: 16),
                Text(
                  'Redirecting...',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: SfColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      // Don't redirect while loading or logging out - prevents flash
      if (auth.loading || auth.loggingOut) return null;

      final loggedIn = auth.isAuthenticated;
      final loc = state.matchedLocation;

      // Prevent flash during logout - redirect ALL protected routes to login when logged out
      if (!loggedIn &&
          (loc.startsWith('/staff') ||
              loc.startsWith('/head') ||
              loc.startsWith('/admin') ||
              loc.startsWith('/clerk') ||
              loc.startsWith('/scanner'))) {
        return '/login';
      }
      final onPublicAuth =
          loc == '/' ||
          loc.startsWith('/login') ||
          loc.startsWith('/signup') ||
          loc.startsWith('/forgot-password') ||
          loc.startsWith('/reset-password');

      if (!loggedIn && !onPublicAuth) return '/';
      if (!loggedIn) return null;

      // A temporary password must be replaced before anything else is reachable.
      if (auth.user!.mustChangePassword) {
        return loc == '/change-password' ? null : '/change-password';
      }
      if (loc == '/change-password') return _homeForRole(auth.user!.role);

      final role = auth.user!.role;

      if (loc == '/' || loc == '/login') {
        return _homeForRole(role);
      }

      if (role == 'staff') {
        if (loc.startsWith('/head') || loc.startsWith('/admin')) {
          return '/staff';
        }
        if (!loc.startsWith('/staff') && !onPublicAuth) {
          return '/staff';
        }
      }

      if (role == 'head') {
        if (loc == '/staff/scan') return '/head/scan';
        if (loc.startsWith('/staff')) {
          return '/head';
        }
        if (loc.startsWith('/admin')) {
          return '/head';
        }
      }

      if (role == 'admin') {
        if (loc == '/staff/scan') return '/admin/scan';
        if (loc.startsWith('/staff')) {
          return '/admin';
        }
        if (loc.startsWith('/head')) {
          return '/admin';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const GetStartedScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/change-password',
        builder: (_, _) => const ForcedPasswordChangeScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          username: (state.extra as Map<String, dynamic>?)?['username']
              ?.toString(),
        ),
      ),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(
        path: '/signup/pending',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return SignupPendingScreen(
            requestCode: extra['code']?.toString() ?? '',
            username: extra['username']?.toString() ?? '',
            summary: extra,
          );
        },
      ),
      GoRoute(
        path: '/signup/approved',
        builder: (_, state) => SignupApprovedScreen(
          request: state.extra as Map<String, dynamic>? ?? {},
        ),
      ),
      GoRoute(
        path: '/home',
        redirect: (_, _) {
          if (!auth.isAuthenticated) return '/login';
          return _homeForRole(auth.user!.role);
        },
      ),
      ShellRoute(
        observers: [staffModals],
        builder: (_, _, child) => _AuthenticatedShell(
          auth: auth,
          modals: [modals, staffModals],
          child: StaffShell(key: ValueKey(auth.sessionIdentity), child: child),
        ),
        routes: [
          GoRoute(
            path: '/staff',
            builder: (_, _) => _sessionScreen(auth, StaffDashboardScreen()),
          ),
          GoRoute(
            path: '/staff/documents',
            builder: (_, state) => _sessionScreen(
              auth,
              DocumentsScreen(
                initialDocumentId: state.uri.queryParameters['id'],
                fromRequest: (state.extra as Map?)?['fromRequest'] == true,
              ),
            ),
          ),
          GoRoute(
            path: '/staff/scan',
            builder: (_, _) => _sessionScreen(auth, ScannerScreen()),
          ),
          GoRoute(
            path: '/staff/register',
            builder: (_, state) => _sessionScreen(
              auth,
              DocumentRegisterScreen(
                homeRoute: '/staff',
                request:
                    (state.extra as Map<String, dynamic>?)?['request']
                        as Map<String, dynamic>?,
              ),
            ),
          ),
          GoRoute(
            path: '/staff/alerts',
            builder: (_, _) => _sessionScreen(auth, StaffAlertsScreen()),
          ),
          GoRoute(
            path: '/staff/profile',
            builder: (_, _) => _sessionScreen(auth, ProfileScreen()),
          ),
          GoRoute(
            path: '/staff/history',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return _sessionScreen(
                auth,
                StaffHistoryScreen(
                  initialDocumentId: extra['documentId']?.toString(),
                  initialTodayFilter: extra['todayFilter']?.toString(),
                ),
              );
            },
          ),
          GoRoute(
            path: '/staff/requests',
            builder: (_, state) => _sessionScreen(
              auth,
              DocumentRequestsScreen(
                homeRoute: '/staff',
                initialRequestId: int.tryParse(
                  state.uri.queryParameters['id'] ?? '',
                ),
              ),
            ),
          ),
        ],
      ),
      ShellRoute(
        observers: [headModals],
        builder: (_, _, child) => _AuthenticatedShell(
          auth: auth,
          modals: [modals, headModals],
          child: HeadShell(key: ValueKey(auth.sessionIdentity), child: child),
        ),
        routes: [
          GoRoute(
            path: '/head',
            builder: (_, _) => _sessionScreen(auth, HeadDashboardScreen()),
          ),
          GoRoute(
            path: '/head/documents',
            builder: (_, state) => _sessionScreen(
              auth,
              DocumentsScreen(
                initialDocumentId: state.uri.queryParameters['id'],
                fromRequest: (state.extra as Map?)?['fromRequest'] == true,
              ),
            ),
          ),
          GoRoute(
            path: '/head/scan',
            builder: (_, _) => _sessionScreen(auth, ScannerScreen()),
          ),
          GoRoute(path: '/head/register', redirect: (_, _) => '/head'),
          GoRoute(
            path: '/head/checklists',
            builder: (_, _) => _sessionScreen(auth, OfficeChecklistsScreen()),
          ),
          GoRoute(
            path: '/head/queue',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return _sessionScreen(
                auth,
                HeadQueueScreen(
                  initialFilter: HeadQueueScreen.parseFilter(
                    extra['filter']?.toString(),
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: '/head/alerts',
            builder: (_, _) => _sessionScreen(auth, HeadAlertsScreen()),
          ),
          GoRoute(
            path: '/head/analytics',
            builder: (_, _) => _sessionScreen(auth, HeadAnalyticsScreen()),
          ),
          GoRoute(
            path: '/head/profile',
            builder: (_, _) => _sessionScreen(auth, ProfileScreen()),
          ),
          GoRoute(
            path: '/head/history',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return _sessionScreen(
                auth,
                StaffHistoryScreen(
                  initialDocumentId: extra['documentId']?.toString(),
                  initialTodayFilter: extra['todayFilter']?.toString(),
                  monitorOnly: true,
                ),
              );
            },
          ),
          GoRoute(
            path: '/head/requests',
            builder: (_, state) => _sessionScreen(
              auth,
              DocumentRequestsScreen(
                homeRoute: '/head',
                initialRequestId: int.tryParse(
                  state.uri.queryParameters['id'] ?? '',
                ),
              ),
            ),
          ),
        ],
      ),
      ShellRoute(
        observers: [adminModals],
        builder: (_, _, child) => _AuthenticatedShell(
          auth: auth,
          modals: [modals, adminModals],
          child: AdminShell(key: ValueKey(auth.sessionIdentity), child: child),
        ),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (_, _) => _sessionScreen(auth, AdminDashboardScreen()),
          ),
          GoRoute(
            path: '/admin/documents',
            builder: (_, state) => _sessionScreen(
              auth,
              DocumentsScreen(
                initialDocumentId: state.uri.queryParameters['id'],
                fromRequest: (state.extra as Map?)?['fromRequest'] == true,
                municipal: state.uri.queryParameters['scope'] == 'municipal',
                initialOfficeId: int.tryParse(
                  state.uri.queryParameters['office_id'] ?? '',
                ),
                initialOverdue: state.uri.queryParameters['overdue'] == '1',
                initialTray: state.uri.queryParameters['tray'],
              ),
            ),
          ),
          GoRoute(
            path: '/admin/scan',
            builder: (_, _) => _sessionScreen(auth, ScannerScreen()),
          ),
          GoRoute(path: '/admin/register', redirect: (_, _) => '/admin'),
          GoRoute(
            path: '/admin/checklists',
            builder: (_, _) => _sessionScreen(auth, OfficeChecklistsScreen()),
          ),
          GoRoute(
            path: '/admin/alerts',
            builder: (_, _) =>
                _sessionScreen(auth, StaffAlertsScreen(municipal: true)),
          ),
          GoRoute(
            path: '/admin/history',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return _sessionScreen(
                auth,
                StaffHistoryScreen(
                  initialDocumentId: extra['documentId']?.toString(),
                  monitorOnly: true,
                ),
              );
            },
          ),
          GoRoute(
            path: '/admin/users',
            builder: (_, _) => _sessionScreen(auth, AdminUsersScreen()),
          ),
          GoRoute(
            path: '/admin/offices',
            builder: (_, _) => _sessionScreen(auth, AdminOfficesScreen()),
          ),
          GoRoute(
            path: '/admin/system',
            builder: (_, _) => _sessionScreen(auth, AdminSystemScreen()),
          ),
          GoRoute(
            path: '/admin/qr-monitor',
            builder: (_, _) => _sessionScreen(auth, AdminQrMonitorScreen()),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (_, _) => _sessionScreen(auth, AdminReportsScreen()),
          ),
          GoRoute(
            path: '/admin/profile',
            builder: (_, _) => _sessionScreen(auth, ProfileScreen()),
          ),
          GoRoute(
            path: '/admin/thresholds',
            builder: (_, _) => _sessionScreen(auth, AdminThresholdsScreen()),
          ),
          GoRoute(
            path: '/admin/requests',
            builder: (_, state) => _sessionScreen(
              auth,
              DocumentRequestsScreen(
                homeRoute: '/admin',
                initialRequestId: int.tryParse(
                  state.uri.queryParameters['id'] ?? '',
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

// GoRouter can retain an unchanged location when refreshListenable fires.
// Listen at the actual page so a replacement login disposes its prior state.
Widget _sessionScreen(AuthProvider auth, Widget child) => ListenableBuilder(
  listenable: auth,
  builder: (_, _) =>
      KeyedSubtree(key: ValueKey(auth.sessionIdentity), child: child),
);

/// Remove protected widgets as soon as identity clears, while redirects settle.
class _SessionModalObserver extends NavigatorObserver {
  final routes = <PopupRoute<dynamic>>{};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute<dynamic>) routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    routes.remove(oldRoute);
    if (newRoute is PopupRoute<dynamic>) routes.add(newRoute);
  }
}

class _AuthenticatedShell extends StatefulWidget {
  const _AuthenticatedShell({
    required this.auth,
    required this.modals,
    required this.child,
  });

  final AuthProvider auth;
  final List<_SessionModalObserver> modals;
  final Widget child;

  @override
  State<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<_AuthenticatedShell> {
  late Object _identity;

  @override
  void initState() {
    super.initState();
    _identity = widget.auth.sessionIdentity;
    widget.auth.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    final next = widget.auth.sessionIdentity;
    if (next != _identity) {
      _identity = next;
      // Dialogs/bottom sheets use the root navigator by default and outlive a
      // ShellRoute's page. Remove them along with the old protected workspace.
      final oldModals = [
        for (final observer in widget.modals) ...observer.routes,
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final route in oldModals) {
          final navigator = route.navigator;
          if (route.isActive && navigator != null && navigator.mounted) {
            navigator.removeRoute(route);
          }
        }
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.auth.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    return IgnorePointer(
      ignoring: auth.loggingOut,
      child: auth.isAuthenticated || (auth.loggingOut && auth.user != null)
          ? widget.child
          : const SizedBox.shrink(),
    );
  }
}

String _homeForRole(String role) {
  switch (role) {
    case 'head':
      return '/head';
    case 'admin':
      return '/admin';
    default:
      return '/staff';
  }
}
