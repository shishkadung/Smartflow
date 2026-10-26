import 'dart:async';

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

class _UsersApi extends SmartflowApi {
  _UsersApi() : super(ApiClient());

  bool failUsers = false;
  bool failPending = false;
  bool empty = false;
  bool rejectStatusChange = false;
  int statusWrites = 0;
  int signupWrites = 0;

  @override
  Future<Map<String, dynamic>> usersList() async {
    if (failUsers) throw ApiException('Sample connection unavailable', 503);
    return {
      'users': empty
          ? []
          : [
              {
                'id': 202,
                'username': 'sample.staff',
                'role': 'staff',
                'office_name': 'Engineering Office',
                'office_code': 'ENG',
                'is_active': true,
              },
            ],
    };
  }

  @override
  Future<Map<String, dynamic>> signupPending() async {
    if (failPending) throw ApiException('Sample sign-up read unavailable', 503);
    return {
      'pending': empty
          ? []
          : [
              {
                'id': 203,
                'username': 'sample.applicant',
                'requested_role': 'staff',
                'office_name': 'Engineering Office',
                'office_code': 'ENG',
                'request_code': 'SIGNUP-SAMPLE-003',
              },
            ],
    };
  }

  @override
  Future<Map<String, dynamic>> setUserActive(int userId, bool active) async {
    statusWrites++;
    if (rejectStatusChange) throw ApiException('Sample action rejected', 409);
    return {'success': true};
  }

  @override
  Future<void> signupApprove(int requestId, String action) async {
    signupWrites++;
  }
}

class _UsersAuth extends AuthProvider {
  _UsersAuth(this.api);

  @override
  final SmartflowApi api;

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

class _OverlappingUsersApi extends _UsersApi {
  bool controlled = false;
  final pendingReads = <Completer<Map<String, dynamic>>>[];

  @override
  Future<Map<String, dynamic>> signupPending() {
    if (!controlled) return super.signupPending();
    final response = Completer<Map<String, dynamic>>();
    pendingReads.add(response);
    return response.future;
  }
}

Future<void> _mount(WidgetTester tester, _UsersApi api) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  // Tall enough for the office and role filters above the accounts.
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _UsersAuth(api);
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
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<(Future<void>, Future<void>)> _startOverlappingReads(
  WidgetTester tester,
  _OverlappingUsersApi api,
) async {
  api.controlled = true;
  final reload = tester
      .widget<RefreshIndicator>(find.byType(RefreshIndicator))
      .onRefresh;
  final older = reload();
  await tester.pump();
  final newer = reload();
  await tester.pump();
  expect(api.pendingReads, hasLength(2));
  return (older, newer);
}

void main() {
  testWidgets(
    'Failed initial Users read stays unavailable until empty retry succeeds',
    (tester) async {
      final api = _UsersApi()..failUsers = true;
      await _mount(tester, api);

      expect(
        find.textContaining('Accounts and sign-ups unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Pending (0)'), findsNothing);
      expect(find.textContaining('Directory ·'), findsNothing);
      expect(find.text('No users found'), findsNothing);
      expect(find.text('No pending sign-ups'), findsNothing);
      expect(find.byType(SfAdminUserCard), findsNothing);
      expect(find.byType(SfAdminPendingSignupCard), findsNothing);

      api
        ..failUsers = false
        ..empty = true;
      await tester.tap(find.text('Retry accounts'));
      await tester.pumpAndSettle();

      expect(find.textContaining('unavailable.'), findsNothing);
      expect(find.text('Pending (0)'), findsOneWidget);
      expect(find.text('Directory · 0'), findsOneWidget);
      expect(find.text('No users found'), findsOneWidget);
      await tester.tap(find.text('Pending (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No pending sign-ups'), findsOneWidget);
      expect(api.statusWrites + api.signupWrites, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Failed refresh retains stale Users and blocks actions until retry',
    (tester) async {
      final api = _UsersApi();
      await _mount(tester, api);
      final previousSignup = tester.widget<SfAdminPendingSignupCard>(
        find.byType(SfAdminPendingSignupCard),
      );
      final previousUser = tester.widget<SfAdminUserCard>(
        find.byType(SfAdminUserCard),
      );
      await tester.ensureVisible(find.text('Deactivate'));
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      api.failPending = true;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      await refresh;
      await tester.tap(find.text('Deactivate account'));
      await tester.pumpAndSettle();
      expect(api.statusWrites, 0);

      expect(
        find.textContaining(
          'Previously loaded accounts and sign-ups may be stale.',
        ),
        findsOneWidget,
      );
      expect(find.text('Pending (1 · stale)'), findsOneWidget);
      expect(find.text('Directory · 1 · may be stale'), findsOneWidget);
      expect(find.text('sample.staff'), findsOneWidget);
      expect(find.text('sample.applicant'), findsOneWidget);
      final blockedSignup = find.ancestor(
        of: find.byType(SfAdminPendingSignupCard),
        matching: find.byType(AbsorbPointer),
      );
      expect(
        tester
            .widgetList<AbsorbPointer>(blockedSignup)
            .where((node) => node.absorbing),
        hasLength(1),
      );
      expect(
        tester
            .widget<SfAdminUserCard>(find.byType(SfAdminUserCard))
            .onToggleActive,
        isNull,
      );
      previousSignup.onApprove();
      previousSignup.onReject();
      previousUser.onToggleActive!();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.statusWrites + api.signupWrites, 0);

      api.failPending = false;
      await tester.ensureVisible(find.text('Retry accounts'));
      await tester.tap(find.text('Retry accounts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('may be stale'), findsNothing);
      expect(find.text('Directory · 1'), findsOneWidget);
      expect(
        tester
            .widget<SfAdminUserCard>(find.byType(SfAdminUserCard))
            .onToggleActive,
        isNotNull,
      );

      // An action rejection must not invalidate the successfully loaded directory.
      api.rejectStatusChange = true;
      await tester.ensureVisible(find.text('Deactivate'));
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate account'));
      await tester.pumpAndSettle();
      expect(api.statusWrites, 1);
      expect(find.text('Sample action rejected'), findsOneWidget);
      expect(find.text('Directory · 1'), findsOneWidget);
      expect(find.textContaining('may be stale'), findsNothing);
      expect(find.text('Retry accounts'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('An older Users failure cannot replace a newer successful read', (
    tester,
  ) async {
    final api = _OverlappingUsersApi();
    await _mount(tester, api);
    final (older, newer) = await _startOverlappingReads(tester, api);

    api.pendingReads[1].complete({'pending': []});
    await tester.pumpAndSettle();
    await newer;
    expect(find.text('Pending (0)'), findsOneWidget);
    expect(find.text('Directory · 1'), findsOneWidget);

    api.pendingReads[0].completeError(
      ApiException('Obsolete read failure', 503),
    );
    await tester.pumpAndSettle();
    await older;

    expect(find.textContaining('Obsolete read failure'), findsNothing);
    expect(find.textContaining('may be stale'), findsNothing);
    expect(find.text('Retry accounts'), findsNothing);
    expect(find.text('Pending (0)'), findsOneWidget);
    expect(find.text('Directory · 1'), findsOneWidget);
    expect(
      tester
          .widget<SfAdminUserCard>(find.byType(SfAdminUserCard))
          .onToggleActive,
      isNotNull,
    );
    expect(api.statusWrites + api.signupWrites, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('An older Users success cannot validate a newer failed read', (
    tester,
  ) async {
    final api = _OverlappingUsersApi();
    await _mount(tester, api);
    final (older, newer) = await _startOverlappingReads(tester, api);

    api.pendingReads[1].completeError(
      ApiException('Current read unavailable', 503),
    );
    await tester.pumpAndSettle();
    await newer;
    expect(find.text('Pending (1 · stale)'), findsOneWidget);
    expect(find.text('Directory · 1 · may be stale'), findsOneWidget);

    api.pendingReads[0].complete({
      'pending': [
        {
          'id': 999,
          'username': 'obsolete.applicant',
          'requested_role': 'staff',
          'office_name': 'Engineering Office',
          'office_code': 'ENG',
        },
      ],
    });
    await tester.pumpAndSettle();
    await older;

    expect(find.textContaining('Current read unavailable'), findsOneWidget);
    expect(find.text('Retry accounts'), findsOneWidget);
    expect(find.text('sample.applicant'), findsOneWidget);
    expect(find.text('obsolete.applicant'), findsNothing);
    expect(find.text('Pending (1 · stale)'), findsOneWidget);
    expect(find.text('Directory · 1 · may be stale'), findsOneWidget);
    expect(
      tester
          .widget<SfAdminUserCard>(find.byType(SfAdminUserCard))
          .onToggleActive,
      isNull,
    );
    expect(api.statusWrites + api.signupWrites, 0);
    expect(tester.takeException(), isNull);
  });
}
