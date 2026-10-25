import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/screens/head/head_shell.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/widgets/sf_page.dart';

class _ShellApi extends SmartflowApi {
  _ShellApi(super.client, {this.pendingSignups = 0});

  int alertReads = 0;
  final int pendingSignups;

  @override
  Future<Map<String, dynamic>> alerts(int officeId) async {
    alertReads++;
    return {
      'alerts': [
        {'document_id': 'DOC-2026-000901', 'kind': 'delayed'},
        {'document_id': 'DOC-2026-000902', 'kind': 'unconfirmed'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> accountantDashboard() async => {
    'stats': {'pending_signups': pendingSignups},
  };

  @override
  Future<Map<String, dynamic>> documentRequestsSummary() async => {
    'pending_inbox_count': 0,
  };

  @override
  Future<Map<String, dynamic>?> pendingMovement() async => null;
}

class _ShellAuth extends AuthProvider {
  _ShellAuth(this.api, this.role);

  @override
  final SmartflowApi api;
  final String role;

  @override
  bool get isAuthenticated => true;

  @override
  bool get loading => false;

  @override
  String get token => 'synthetic-alert-position-session';

  @override
  AppUser get user => AppUser(
    id: 901,
    name: 'Sample navigation reviewer',
    username: 'sample.navigation',
    role: role,
    officeId: 1,
    officeName: 'Engineering Office',
    officeCode: 'ENG',
  );
}

Widget _roleShell(String role, Widget child) => switch (role) {
  'staff' => StaffShell(child: child),
  'head' => HeadShell(child: child),
  _ => AdminShell(child: child),
};

void main() {
  for (final role in ['staff', 'head', 'admin']) {
    testWidgets('$role keeps Alerts fourth, Menu fifth and Profile in the header', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Real shell reads use the synthetic API below. Any unexpected transport,
      // including a write, is blocked and makes the test fail.
      final transportCalls = <String>[];
      final client = MockClient((request) async {
        transportCalls.add('${request.method} ${request.url.path}');
        throw StateError('Navigation tests must never use live HTTP.');
      });
      final api = _ShellApi(
        ApiClient(client: client),
        pendingSignups: role == 'admin' ? 3 : 0,
      );
      final auth = _ShellAuth(api, role);
      final secondPath = switch (role) {
        'staff' => '/staff/documents',
        'head' => '/head/queue',
        _ => '/admin/history',
      };
      final centerPath = role == 'admin' ? '/admin/reports' : '/$role/scan';
      final centerLabel = role == 'admin' ? 'Reports' : 'Scan';
      final secondLabel = switch (role) {
        'staff' => 'Documents',
        'head' => 'Queue',
        _ => 'History',
      };
      final routes = [
        '/$role',
        secondPath,
        centerPath,
        '/$role/alerts',
        '/$role/profile',
        '/$role/requests',
      ];
      final router = GoRouter(
        initialLocation: '/$role',
        routes: [
          ShellRoute(
            builder: (_, _, child) => _roleShell(role, child),
            routes: [
              for (final path in routes)
                GoRoute(
                  path: path,
                  builder: (_, _) => ColoredBox(
                    color: Colors.white,
                    child: Center(child: Text('Opened $path')),
                  ),
                ),
            ],
          ),
        ],
      );
      addTearDown(() async {
        // Dispose actual shell refresh timers before checking pending timers.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        router.dispose();
        auth.dispose();
        client.close();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: true),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final nav = find.byType(SfBottomNav);
      SfBottomNav navigation() => tester.widget<SfBottomNav>(nav);
      Finder label(String text) =>
          find.descendant(of: nav, matching: find.text(text));

      expect(navigation().tabs.map((tab) => tab.label), [
        'Home',
        secondLabel,
        centerLabel,
        'Alerts',
        'Menu',
      ]);
      expect(navigation().tabs[2].elevated, isTrue);
      expect(navigation().currentIndex, 0);
      expect(
        tester.getCenter(label('Alerts')).dx,
        greaterThan(tester.getCenter(label(centerLabel)).dx),
      );
      expect(
        tester.getCenter(label('Alerts')).dx,
        lessThan(tester.getCenter(label('Menu')).dx),
      );

      void expectAlertsBadge() {
        final alertsTarget = find.ancestor(
          of: label('Alerts'),
          matching: find.byType(InkWell),
        );
        expect(alertsTarget, findsOneWidget);
        final badge = find.descendant(
          of: alertsTarget,
          matching: find.text('2'),
        );
        if (role == 'admin') {
          expect(navigation().tabs[3].badge, isNull);
          expect(badge, findsNothing);
          expect(navigation().tabs[4].badge, 3);
          final menuTarget = find.ancestor(
            of: label('Menu'),
            matching: find.byType(InkWell),
          );
          expect(
            find.descendant(of: menuTarget, matching: find.text('3')),
            findsOneWidget,
          );
        } else {
          expect(api.alertReads, greaterThan(0));
          expect(navigation().tabs[3].badge, 2);
          expect(badge, findsOneWidget);
          expect(
            navigation().tabs.where((tab) => tab.badge != null).single.label,
            'Alerts',
          );
        }
      }

      expectAlertsBadge();
      await tester.tap(label('Alerts'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/$role/alerts');
      expect(find.text('Opened /$role/alerts'), findsOneWidget);
      expect(navigation().currentIndex, 3);
      expect(tester.widget<Text>(label('Alerts')).style?.color, SfColors.blue);
      expectAlertsBadge();

      // The raised third destination retains its original role-specific route.
      await tester.tap(label(centerLabel));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, centerPath);
      expect(find.text('Opened $centerPath'), findsOneWidget);
      expect(navigation().currentIndex, 2);
      expectAlertsBadge();

      if (role == 'staff') {
        await tester.tap(label('Documents'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, secondPath);
        expect(find.text('Opened /staff/documents'), findsOneWidget);
        expect(navigation().currentIndex, 1);
        expectAlertsBadge();
      }

      // Profile is a direct header action and leaves every bottom tab inactive.
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/$role/profile');
      expect(find.text('Opened /$role/profile'), findsOneWidget);
      expect(navigation().currentIndex, -1);
      expect(tester.widget<Text>(label('Menu')).style?.color, SfColors.muted);
      expectAlertsBadge();

      // The fifth slot opens the existing tools sheet without changing routes.
      await tester.tap(label('Menu'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/$role/profile');
      final menuSheet = find.byType(BottomSheet);
      expect(menuSheet, findsOneWidget);
      expect(
        find.descendant(of: menuSheet, matching: find.text('Requests')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: menuSheet, matching: find.text('Requests')),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/$role/requests');
      expect(find.text('Opened /$role/requests'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(navigation().currentIndex, 4);
      expect(tester.widget<Text>(label('Menu')).style?.color, SfColors.blue);
      expectAlertsBadge();
      expect(transportCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
