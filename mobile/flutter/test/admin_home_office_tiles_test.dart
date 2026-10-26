import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/screens/admin/admin_widgets.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

// Like the web dashboard: an office that needs follow-up opens its overdue folders, a quiet one opens what is on its desk.

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());

  @override
  Future<Map<String, dynamic>> accountantDashboard() async => {
    'month': '2026-10',
    'stats': {
      'active_documents': 9,
      'overdue': 2,
      'pending_signups': 0,
      'pilot_offices': 3,
    },
    'office_totals': [
      {
        'office_id': 4,
        'office_name': 'Accounting Office',
        'office_code': 'ACC',
        'docs_processed': 5,
        'in_office': 3,
        'overdue': 2,
      },
      {
        'office_id': 2,
        'office_name': 'Budget Office',
        'office_code': 'BUD',
        'docs_processed': 4,
        'in_office': 4,
        'overdue': 0,
      },
      {
        'office_id': 5,
        'office_name': 'Treasury Office',
        'office_code': 'TRE',
        'docs_processed': 0,
        'in_office': 0,
        'overdue': 0,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> documentRequestsSummary() async => {
    'pending_inbox_count': 0,
  };
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final _Api fixture;
  @override
  SmartflowApi get api => fixture;
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get user => const AppUser(
    id: 10,
    name: 'UI reviewer',
    username: 'ui.reviewer',
    role: 'admin',
    officeId: 4,
    officeName: 'Accounting Office',
    officeCode: 'ACC',
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'sf_role_tip_seen_v2_ui.reviewer': true,
    });
  });

  Future<List<Uri>> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final opened = <Uri>[];
    final auth = _Auth(_Api());
    addTearDown(auth.dispose);
    final router = GoRouter(
      initialLocation: '/admin',
      routes: [
        GoRoute(
          path: '/admin',
          builder: (_, _) => const Scaffold(body: AdminDashboardScreen()),
        ),
        GoRoute(
          path: '/admin/documents',
          builder: (_, state) {
            opened.add(state.uri);
            return const Scaffold(body: Text('Documents list'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
          theme: buildSmartflowTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('an office with overdue folders opens its overdue list', (
    tester,
  ) async {
    final opened = await mount(tester);
    expect(
      find.descendant(
        of: find.byType(SfAdminOfficeHealthTile).first,
        matching: find.text('Follow up'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(SfAdminOfficeHealthTile).first);
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(opened.single.path, '/admin/documents');
    expect(opened.single.queryParameters, {
      'scope': 'municipal',
      'office_id': '4',
      'overdue': '1',
    });
  });

  testWidgets('an office with nothing overdue opens what is on its desk', (
    tester,
  ) async {
    final opened = await mount(tester);
    final tiles = find.byType(SfAdminOfficeHealthTile);
    await tester.tap(tiles.at(1));
    await tester.pumpAndSettle();
    expect(opened.single.queryParameters, {
      'scope': 'municipal',
      'office_id': '2',
      'tray': 'in_office',
    });
  });

  testWidgets('a quiet office keeps opening its desk too', (tester) async {
    final opened = await mount(tester);
    await tester.tap(find.byType(SfAdminOfficeHealthTile).at(2));
    await tester.pumpAndSettle();
    expect(opened.single.queryParameters['tray'], 'in_office');
    expect(opened.single.queryParameters.containsKey('overdue'), isFalse);
  });
}
