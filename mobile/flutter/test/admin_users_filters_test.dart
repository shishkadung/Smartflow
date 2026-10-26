import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

// The phone Users page filters by office and role as the web page does, next to the search and the status chips.

Map<String, dynamic> _account(
  int id,
  String name,
  String username,
  String office,
  String role,
  bool active,
) => {
  'id': id,
  'name': name,
  'username': username,
  'email': '$username@example.com',
  'office_code': office,
  'office_name': '$office Office',
  'role': role,
  'is_active': active,
};

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  bool failUsers = false;

  @override
  Future<Map<String, dynamic>> usersList() async {
    if (failUsers) throw ApiException('Sample connection unavailable', 503);
    return {
      'users': [
        _account(1, 'Ana Reyes', 'ana_acc', 'ACC', 'staff', true),
        _account(2, 'Ben Cruz', 'ben_bud', 'BUD', 'staff', false),
        _account(3, 'Carla Diaz', 'carla_acc', 'ACC', 'head', true),
        _account(4, 'System Admin', 'sys_admin', 'MAY', 'admin', true),
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> signupPending() async => {
    'pending': [
      {
        'id': 91,
        'username': 'pending.acc',
        'full_name': 'Pending Accountant',
        'requested_role': 'head',
        'office_name': 'ACC Office',
        'office_code': 'ACC',
        'request_code': 'SIGNUP-91',
      },
      {
        'id': 92,
        'username': 'pending.bud',
        'full_name': 'Pending Budget',
        'requested_role': 'staff',
        'office_name': 'BUD Office',
        'office_code': 'BUD',
        'request_code': 'SIGNUP-92',
      },
    ],
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
    id: 101,
    name: 'Sample administrator',
    username: 'sample.admin',
    role: 'admin',
    officeId: 4,
    officeName: 'Accounting Office',
    officeCode: 'ACC',
  );
}

Future<void> _mount(
  WidgetTester tester,
  _Api api, {
  double width = 390,
  double scale = 1,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth(api);
  addTearDown(auth.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: AdminUsersScreen()),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(
        theme: buildSmartflowTheme().copyWith(platform: TargetPlatform.windows),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String field, String option) async {
  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'office and role filters appear above the accounts, with the total',
    (tester) async {
      await _mount(tester, _Api());
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('4 accounts'), findsOneWidget);
      expect(find.text('Directory · 4'), findsOneWidget);
      for (final user in ['ana_acc', 'ben_bud', 'carla_acc', 'sys_admin']) {
        expect(find.text(user), findsOneWidget, reason: user);
      }
      expect(find.text('Clear filters'), findsNothing);
      // Office choices come from the accounts, sorted, without repeats.
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Office'),
      );
      await tester.pumpAndSettle();
      expect(find.text('All offices'), findsWidgets);
      for (final code in ['ACC', 'BUD', 'MAY']) {
        expect(find.text(code), findsWidgets, reason: code);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the office filter narrows the list and says how many of how many',
    (tester) async {
      await _mount(tester, _Api());
      await _choose(tester, 'Office', 'ACC');
      expect(find.text('ana_acc'), findsOneWidget);
      expect(find.text('carla_acc'), findsOneWidget);
      expect(find.text('ben_bud'), findsNothing);
      expect(find.text('sys_admin'), findsNothing);
      expect(find.text('Directory · 2'), findsOneWidget);
      expect(find.text('Showing 2 of 4 accounts'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
      // The role filter narrows it further, together with the office.
      await _choose(tester, 'Role', 'Head');
      expect(find.text('carla_acc'), findsOneWidget);
      expect(find.text('ana_acc'), findsNothing);
      expect(find.text('Showing 1 of 4 accounts'), findsOneWidget);
    },
  );

  testWidgets(
    'search needs every typed word, and works with the status chips',
    (tester) async {
      await _mount(tester, _Api());
      await tester.enterText(find.byType(TextField).first, 'carla acc');
      await tester.pumpAndSettle();
      expect(find.text('carla_acc'), findsOneWidget);
      expect(find.text('ana_acc'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'ana');
      await tester.tap(find.widgetWithText(FilterChip, 'Inactive'));
      await tester.pumpAndSettle();
      expect(find.text('No users found'), findsOneWidget);
      expect(find.text('No accounts match these filters.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      expect(find.text('ben_bud'), findsOneWidget);
      expect(find.text('ana_acc'), findsNothing);
      expect(find.text('Showing 1 of 4 accounts'), findsOneWidget);
    },
  );

  testWidgets(
    'Clear filters empties the search, both dropdowns and the status chip',
    (tester) async {
      await _mount(tester, _Api());
      await _choose(tester, 'Office', 'ACC');
      await _choose(tester, 'Role', 'Staff');
      await tester.enterText(find.byType(TextField).first, 'ana');
      await tester.tap(find.widgetWithText(FilterChip, 'Active'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 1 of 4 accounts'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('4 accounts'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '',
      );
      for (final user in ['ana_acc', 'ben_bud', 'carla_acc', 'sys_admin']) {
        expect(find.text(user), findsOneWidget, reason: user);
      }
      expect(find.text('All offices'), findsOneWidget);
      expect(find.text('All roles'), findsOneWidget);
    },
  );

  testWidgets(
    'pending sign-ups follow the office and role filters, using the role they asked for',
    (tester) async {
      await _mount(tester, _Api());
      expect(find.text('Pending sign-up · 2'), findsOneWidget);
      await _choose(tester, 'Office', 'ACC');
      expect(find.text('Pending sign-up · 1'), findsOneWidget);
      expect(find.textContaining('pending.acc'), findsOneWidget);
      expect(find.textContaining('pending.bud'), findsNothing);
      await _choose(tester, 'Role', 'Staff');
      expect(find.text('No pending match'), findsOneWidget);
      expect(
        find.text('Try a different search, office or role.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a directory that could not be read shows no filters and no totals',
    (tester) async {
      await _mount(tester, _Api()..failUsers = true);
      expect(find.textContaining('unavailable'), findsWidgets);
      expect(find.text('Office'), findsNothing);
      expect(find.text('Role'), findsNothing);
      expect(find.textContaining(RegExp(r'\d+ accounts?')), findsNothing);
    },
  );

  testWidgets('the filters fit 320px with doubled text', (tester) async {
    await _mount(tester, _Api(), width: 320, scale: 2);
    await _choose(tester, 'Office', 'ACC');
    expect(find.text('Clear filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
