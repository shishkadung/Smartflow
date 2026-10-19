import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/screens/admin/admin_widgets.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

/// Synthetic data only; every call is recorded in memory and nothing reaches a server.
class _Api extends SmartflowApi {
  _Api() : super(ApiClient());

  final emailCalls = <(int, String)>[];
  final resetCalls = <int>[];
  String? resetFailure;
  String staffEmail = 'other.staff@urbiztondo.gov.ph';

  @override
  Future<Map<String, dynamic>> usersList() async => {
    'users': [
      {
        'id': 102,
        'name': 'Self Admin',
        'username': 'self.admin',
        'email': 'self.admin@example.test',
        'role': 'admin',
        'office_name': 'Accounting',
        'office_code': 'ACC',
        'is_active': true,
      },
      {
        'id': 103,
        'name': 'Other Staff',
        'username': 'other.staff',
        'email': staffEmail,
        'role': 'staff',
        'office_name': 'Engineering',
        'office_code': 'ENG',
        'is_active': true,
      },
      {
        'id': 104,
        'name': 'Gone Head',
        'username': 'gone.head',
        'email': 'gone.head@example.test',
        'role': 'head',
        'office_name': 'Budget',
        'office_code': 'BUD',
        'is_active': false,
      },
      {
        'id': 105,
        'name': 'Other Admin',
        'username': 'other.admin',
        'email': 'other.admin@example.test',
        'role': 'admin',
        'office_name': 'Accounting',
        'office_code': 'ACC',
        'is_active': true,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> signupPending() async => {'pending': []};

  @override
  Future<Map<String, dynamic>> adminSetUserEmail(int userId, String email) async {
    emailCalls.add((userId, email));
    staffEmail = email.toLowerCase();
    return {'success': true, 'message': 'Email address updated.'};
  }

  @override
  Future<Map<String, dynamic>> adminResetPassword(int userId) async {
    resetCalls.add(userId);
    if (resetFailure != null) throw ApiException(resetFailure!);
    return {
      'success': true,
      'temporary_password': 'Abcd2345Efgh',
      'expires_at': '2026-10-20 13:00:00',
      'user': {'name': 'Other Staff', 'username': 'other.staff'},
    };
  }
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final _Api fixture;
  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => AppUser(
    id: 102,
    name: 'Self Admin',
    username: 'self.admin',
    role: 'admin',
    officeId: 4,
    officeName: 'Accounting Office',
    officeCode: 'ACC',
  );
}

Future<void> _mount(WidgetTester tester, _Api api, {double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(api),
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildSmartflowTheme(),
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

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  test('email check, manage scope and reset eligibility follow the web rules', () {
    expect(
      sfEmailNeedsCheck({'username': 'a.b', 'email': 'a.b@urbiztondo.gov.ph'}),
      isTrue,
    );
    expect(
      sfEmailNeedsCheck({'username': 'a.b', 'email': 'A.B@Urbiztondo.gov.ph '}),
      isTrue,
    );
    expect(sfEmailNeedsCheck({'username': 'a.b', 'email': null}), isTrue);
    expect(
      sfEmailNeedsCheck({'username': 'a.b', 'email': 'real@gmail.com'}),
      isFalse,
    );
    expect(sfAdminCanManageUser({'role': 'staff'}), isTrue);
    expect(sfAdminCanManageUser({'role': 'head'}), isTrue);
    expect(sfAdminCanManageUser({'role': 'admin'}), isFalse);
    expect(
      sfAdminCanResetPassword({'id': 3, 'role': 'staff', 'is_active': true}, 1),
      isTrue,
    );
    expect(
      sfAdminCanResetPassword({'id': 3, 'role': 'staff', 'is_active': false}, 1),
      isFalse,
    );
    expect(
      sfAdminCanResetPassword({'id': 3, 'role': 'admin', 'is_active': true}, 1),
      isFalse,
    );
    expect(
      sfAdminCanResetPassword({'id': 1, 'role': 'staff', 'is_active': true}, 1),
      isFalse,
    );
    expect(sfEmailPattern.hasMatch('name@example.com'), isTrue);
    expect(sfEmailPattern.hasMatch('not-an-email'), isFalse);
    expect(sfEmailPattern.hasMatch('a@b'), isFalse);
    expect(SfTemporaryPasswordDialog.grouped('Abcd2345Efgh'), 'Abcd 2345 Efgh');
  });

  test('email change and temporary password use the backend contract', () async {
    final calls = <http.Request>[];
    final api = SmartflowApi(
      ApiClient(
        client: MockClient((r) async {
          calls.add(r);
          return http.Response('{"success":true}', 200);
        }),
      ),
    );
    await api.adminSetUserEmail(103, 'new@example.test');
    await api.adminResetPassword(103);
    expect(calls[0].url.pathSegments.last, 'users-admin-set-email.php');
    expect(jsonDecode(calls[0].body), {
      'user_id': 103,
      'email': 'new@example.test',
    });
    expect(calls[1].url.pathSegments.last, 'users-admin-reset-password.php');
    expect(jsonDecode(calls[1].body), {'user_id': 103});
  });

  testWidgets('temporary password is grouped, explained and closed only by its button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSmartflowTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const SfTemporaryPasswordDialog(
                    name: 'Other Staff',
                    username: 'other.staff',
                    password: 'Abcd2345Efgh',
                    expires: '2026-10-20 13:00:00',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Abcd 2345 Efgh'), findsOneWidget);
    expect(find.text('For Other Staff (@other.staff):'), findsOneWidget);
    expect(find.textContaining('never by chat or email'), findsOneWidget);
    expect(find.text('Expires 2026-10-20 13:00:00.'), findsOneWidget);
    expect(find.textContaining('old password no longer works'), findsOneWidget);
    // The system back gesture cannot discard a password that is shown only once.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Abcd 2345 Efgh'), findsOneWidget);
    await tester.tap(find.text('I have shared it'));
    await tester.pumpAndSettle();
    expect(find.text('Abcd 2345 Efgh'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only staff and head accounts can be managed, and reset needs an active account', (
    tester,
  ) async {
    final api = _Api();
    await _mount(tester, api);
    // Staff and head open the sheet; the signed-in admin and another admin do not.
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
    await tester.tap(find.text('self.admin'));
    await tester.pumpAndSettle();
    expect(find.text('Edit reset email'), findsNothing);
    await tester.tap(find.text('other.admin'));
    await tester.pumpAndSettle();
    expect(find.text('Edit reset email'), findsNothing);

    await tester.tap(find.text('gone.head'));
    await tester.pumpAndSettle();
    expect(find.text('Manage gone.head'), findsOneWidget);
    expect(find.text('Edit reset email'), findsOneWidget);
    expect(find.text('Reset password'), findsNothing);
    expect(
      find.text('Password reset is available for active accounts only.'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('other.staff'));
    await tester.pumpAndSettle();
    expect(find.text('Manage other.staff'), findsOneWidget);
    expect(find.textContaining('check this address'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
    expect(api.emailCalls, isEmpty);
    expect(api.resetCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing the reset email validates first, then saves the trimmed address', (
    tester,
  ) async {
    final api = _Api();
    await _mount(tester, api);
    await tester.tap(find.text('other.staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit reset email'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'not-an-email');
    await tester.tap(find.text('Save email'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid email address, for example name@example.com.'),
      findsOneWidget,
    );
    expect(api.emailCalls, isEmpty);

    await tester.enterText(field, '  New.Person@Example.test ');
    await tester.pump();
    expect(
      find.text('Enter a valid email address, for example name@example.com.'),
      findsNothing,
    );
    await tester.tap(find.text('Save email'));
    await tester.pumpAndSettle();
    expect(api.emailCalls, [(103, 'New.Person@Example.test')]);
    expect(find.text('Email address for other.staff updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a temporary password needs confirmation and is shown once', (
    tester,
  ) async {
    final api = _Api();
    await _mount(tester, api);
    await tester.tap(find.text('other.staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('Issue a temporary password?'), findsOneWidget);
    expect(find.textContaining('signed out everywhere'), findsOneWidget);
    expect(find.textContaining('emailed reset code does not reach'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.resetCalls, isEmpty);

    await tester.tap(find.text('other.staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue temporary password'));
    await tester.pumpAndSettle();
    expect(api.resetCalls, [103]);
    expect(find.text('Temporary password'), findsOneWidget);
    expect(find.text('Abcd 2345 Efgh'), findsOneWidget);
    await tester.tap(find.text('I have shared it'));
    await tester.pumpAndSettle();
    expect(find.text('Abcd 2345 Efgh'), findsNothing);
    expect(find.textContaining('Abcd'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused reset shows the reason and never a password', (tester) async {
    final api = _Api()..resetFailure = 'Activate the account before resetting its password.';
    await _mount(tester, api);
    await tester.tap(find.text('other.staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue temporary password'));
    await tester.pumpAndSettle();
    expect(api.resetCalls, [103]);
    expect(find.text('Temporary password'), findsNothing);
    expect(
      find.textContaining('Activate the account before resetting'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Deactivate still works on its own and does not open the Manage sheet', (
    tester,
  ) async {
    final api = _Api();
    await _mount(tester, api);
    await tester.tap(find.text('Deactivate').first);
    await tester.pumpAndSettle();
    expect(find.text('Manage other.staff'), findsNothing);
    expect(find.text('Deactivate account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
