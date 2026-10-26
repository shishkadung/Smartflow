import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/data/help_guides.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/screens/head/head_shell.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/widgets/sf_page.dart';

// Office checklists are in the Head and Admin Menu, as on the web; staff never see them.

class _Api extends SmartflowApi {
  _Api(super.client);

  @override
  Future<Map<String, dynamic>> alerts(int officeId) async => {'alerts': []};

  @override
  Future<Map<String, dynamic>> accountantDashboard() async => {
    'stats': {'pending_signups': 0},
  };

  @override
  Future<Map<String, dynamic>> documentRequestsSummary() async => {
    'pending_inbox_count': 0,
  };

  @override
  Future<Map<String, dynamic>?> pendingMovement() async => null;
}

class _Auth extends AuthProvider {
  _Auth(this.api, this.role);

  @override
  final SmartflowApi api;
  final String role;

  @override
  bool get isAuthenticated => true;

  @override
  bool get loading => false;

  @override
  String get token => 'synthetic-checklist-menu-session';

  @override
  AppUser get user => AppUser(
    id: 902,
    name: 'Sample menu reviewer',
    username: 'sample.menu',
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
    testWidgets(
      '$role ${role == 'staff' ? 'has no' : 'opens'} Office checklists from the Menu',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final client = MockClient((request) async {
          throw StateError('Menu tests must never use live HTTP.');
        });
        final auth = _Auth(_Api(ApiClient(client: client)), role);
        final path = '/$role/checklists';
        final router = GoRouter(
          initialLocation: '/$role',
          routes: [
            ShellRoute(
              builder: (_, _, child) => _roleShell(role, child),
              routes: [
                for (final route in ['/$role', path])
                  GoRoute(
                    path: route,
                    builder: (_, _) => Center(child: Text('Opened $route')),
                  ),
              ],
            ),
          ],
        );
        addTearDown(() async {
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

        await tester.tap(
          find.descendant(
            of: find.byType(SfBottomNav),
            matching: find.text('Menu'),
          ),
        );
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        final entry = find.descendant(
          of: sheet,
          matching: find.text('Office checklists'),
        );
        if (role == 'staff') {
          expect(entry, findsNothing);
          return;
        }
        expect(entry, findsOneWidget);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, path);
        expect(find.text('Opened $path'), findsOneWidget);
      },
    );
  }

  test('the Office checklists screens have their own help', () {
    for (final path in ['/head/checklists', '/admin/checklists']) {
      expect(
        sfHelpPageForPath(path),
        SfHelpPage.officeChecklists,
        reason: path,
      );
    }
    final guide = sfHelpGuide(SfHelpPage.officeChecklists);
    expect(guide.title, 'How to use Office checklists');
    expect(guide.steps.length, greaterThanOrEqualTo(3));
  });
}
