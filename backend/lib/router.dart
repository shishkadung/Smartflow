import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'theme/smartflow_theme.dart';
import 'screens/admin/admin_qr_monitor_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/get_started_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/head/head_shell.dart';
import 'screens/shared/document_register_screen.dart';
import 'screens/shared/document_requests_screen.dart';
import 'screens/staff/scanner_screen.dart';
import 'screens/staff/staff_shell.dart';

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: SfColors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: SfGradients.pageSky),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: SfColors.red),
                const SizedBox(height: 16),
                Text(
                  'Screen not found',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: SfColors.ink,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.uri.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SfColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to welcome'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      if (auth.loading) return null;
      final loggedIn = auth.isAuthenticated;
      final loc = state.matchedLocation;
      final onPublicAuth = loc == '/' ||
          loc.startsWith('/login') ||
          loc.startsWith('/signup') ||
          loc.startsWith('/forgot-password') ||
          loc.startsWith('/reset-password');

      if (!loggedIn && !onPublicAuth) return '/';
      if (!loggedIn) return null;

      final role = auth.user!.role;

      if (loc == '/' || loc == '/login') {
        return _homeForRole(role);
      }

      final staffTools = loc.startsWith('/staff/scan') ||
          loc.startsWith('/staff/register');

      if (role == 'staff') {
        if (loc.startsWith('/head') || loc.startsWith('/admin')) {
          return '/staff';
        }
        if (!loc.startsWith('/staff') && !onPublicAuth) {
          return '/staff';
        }
      }

      if (role == 'head') {
        if (loc.startsWith('/staff') && !staffTools) {
          return '/head';
        }
        if (loc.startsWith('/admin')) {
          return '/head';
        }
      }

      if (role == 'admin') {
        if (loc.startsWith('/staff') && !staffTools) {
          return '/admin';
        }
        if (loc.startsWith('/head')) {
          return '/admin';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const GetStartedScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          username: (state.extra as Map<String, dynamic>?)?['username']?.toString(),
        ),
      ),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
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
        redirect: (_, __) {
          if (!auth.isAuthenticated) return '/login';
          return _homeForRole(auth.user!.role);
        },
      ),
      ShellRoute(
        builder: (_, __, child) => StaffShell(child: child),
        routes: [
          GoRoute(path: '/staff', builder: (_, __) => const StaffDashboardScreen()),
          GoRoute(path: '/staff/scan', builder: (_, __) => const ScannerScreen()),
          GoRoute(
            path: '/staff/register',
            builder: (_, __) => const DocumentRegisterScreen(homeRoute: '/staff'),
          ),
          GoRoute(path: '/staff/alerts', builder: (_, __) => const StaffAlertsScreen()),
          GoRoute(path: '/staff/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/staff/history',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return StaffHistoryScreen(
                initialDocumentId: extra['documentId']?.toString(),
                initialTodayFilter: extra['todayFilter']?.toString(),
              );
            },
          ),
          GoRoute(
            path: '/staff/requests',
            builder: (_, __) => const DocumentRequestsScreen(homeRoute: '/staff'),
          ),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) => HeadShell(child: child),
        routes: [
          GoRoute(path: '/head', builder: (_, __) => const HeadDashboardScreen()),
          GoRoute(
            path: '/head/register',
            builder: (_, __) => const DocumentRegisterScreen(homeRoute: '/head'),
          ),
          GoRoute(
            path: '/head/queue',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return HeadQueueScreen(
                initialFilter: HeadQueueScreen.parseFilter(
                  extra['filter']?.toString(),
                ),
              );
            },
          ),
          GoRoute(path: '/head/alerts', builder: (_, __) => const HeadAlertsScreen()),
          GoRoute(path: '/head/analytics', builder: (_, __) => const HeadAnalyticsScreen()),
          GoRoute(path: '/head/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/head/history',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return StaffHistoryScreen(
                initialDocumentId: extra['documentId']?.toString(),
                initialTodayFilter: extra['todayFilter']?.toString(),
                monitorOnly: true,
              );
            },
          ),
          GoRoute(
            path: '/head/requests',
            builder: (_, __) => const DocumentRequestsScreen(homeRoute: '/head'),
          ),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
          GoRoute(path: '/admin/offices', builder: (_, __) => const AdminOfficesScreen()),
          GoRoute(path: '/admin/system', builder: (_, __) => const AdminSystemScreen()),
          GoRoute(
            path: '/admin/qr-monitor',
            builder: (_, __) => const AdminQrMonitorScreen(),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (_, __) => const AdminReportsScreen(),
          ),
          GoRoute(path: '/admin/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/admin/thresholds', builder: (_, __) => const AdminThresholdsScreen()),
          GoRoute(
            path: '/admin/requests',
            builder: (_, __) => const DocumentRequestsScreen(homeRoute: '/admin'),
          ),
        ],
      ),
    ],
  );
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
