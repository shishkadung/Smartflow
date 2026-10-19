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
import 'package:smartflow/screens/staff/clerk_widgets.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

Map<String, dynamic> _stats(int count) => {
  'stats': {'active_documents': count, 'overdue': 2, 'pending_signups': 1},
};

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  bool failStats = false;
  bool failStatus = false;
  bool controlledStats = false;
  int count = 24;
  int listReads = 0;
  bool pending = true;
  final snapshots = <Completer<Map<String, dynamic>>>[];
  final decisions = <(int, String)>[];
  Completer<void>? decision;

  @override
  Future<Map<String, dynamic>> accountantDashboard() async {
    if (controlledStats) {
      final reply = Completer<Map<String, dynamic>>();
      snapshots.add(reply);
      return reply.future;
    }
    if (failStats) throw ApiException('Sample snapshot read failed', 503);
    return _stats(count);
  }

  @override
  Future<Map<String, dynamic>> systemStatus() async {
    if (failStatus) throw ApiException('Sample status read failed', 503);
    return {
      'status': {'api': 'Online', 'database': 'Online'},
    };
  }

  @override
  Future<Map<String, dynamic>> usersList() async {
    listReads++;
    return {
      'users': [
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
  Future<Map<String, dynamic>> signupPending() async => {
    'pending': pending
        ? [
            {
              'id': 203,
              'username': 'sample.applicant',
              'requested_role': 'staff',
              'office_name': 'Engineering Office',
              'office_code': 'ENG',
              'request_code': 'SIGNUP-SAMPLE-003',
            },
          ]
        : [],
  };

  @override
  Future<void> signupApprove(int requestId, String action) async {
    decisions.add((requestId, action));
    await decision?.future;
    pending = false;
  }
}

class _Auth extends AuthProvider {
  _Auth(this.api);
  @override
  final SmartflowApi api;
  int account = 101;
  bool ending = false;
  @override
  bool get isAuthenticated => true;
  @override
  bool get loading => false;
  @override
  bool get loggingOut => ending;
  @override
  String get token => 'synthetic-admin-$account';
  @override
  AppUser get user => AppUser(
    id: account,
    name: 'Sample administrator $account',
    username: 'sample.admin.$account',
    role: 'admin',
    officeId: 4,
    officeName: 'Accounting Office',
    officeCode: 'ACC',
  );
  void replaceLogin() {
    account++;
    notifyListeners();
  }

  void logoutPending(bool value) {
    ending = value;
    notifyListeners();
  }
}

Future<_Auth> _mount(
  WidgetTester tester,
  _Api api, {
  bool users = false,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(600, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth(api);
  final router = GoRouter(
    initialLocation: users ? '/admin/users' : '/admin/profile',
    routes: [
      GoRoute(path: '/admin', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/admin/profile',
        builder: (_, _) => Scaffold(body: AdminProfileView(user: auth.user)),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (_, _) => const Scaffold(body: AdminUsersScreen()),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    auth.dispose();
  });
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
  return auth;
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _confirm(WidgetTester tester, String action) async {
  await tester.tap(
    find.descendant(of: find.byType(AlertDialog), matching: find.text(action)),
  );
  await _frames(tester);
}

SfProfileAccountCard _profile(WidgetTester tester) =>
    tester.widget<SfProfileAccountCard>(find.byType(SfProfileAccountCard));
SfAdminPendingSignupCard _signup(WidgetTester tester) => tester
    .widget<SfAdminPendingSignupCard>(find.byType(SfAdminPendingSignupCard));

void main() {
  testWidgets(
    'Admin Profile initial failure keeps identity and retry restores the snapshot',
    (tester) async {
      final api = _Api()..failStats = true;
      await _mount(tester, api);
      expect(
        find.textContaining('Municipal snapshot unavailable.'),
        findsOneWidget,
      );
      expect(_profile(tester).inFlow, isNull);
      expect(find.text('Account & security'), findsOneWidget);
      expect(find.text('System status unknown.'), findsOneWidget);
      api.failStats = false;
      await tester.tap(find.text('Retry snapshot'));
      await tester.pumpAndSettle();
      expect(_profile(tester).inFlow, '24');
      expect(find.textContaining('System online'), findsOneWidget);
      expect(find.textContaining('unavailable.'), findsNothing);
    },
  );

  testWidgets(
    'Admin Profile refresh retains counts as stale and removes the old online claim',
    (tester) async {
      final api = _Api();
      await _mount(tester, api);
      api.failStats = true;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(_profile(tester).inFlow, '24');
      expect(
        find.textContaining('Previously loaded snapshot may be stale.'),
        findsOneWidget,
      );
      expect(find.textContaining('Last successful update'), findsOneWidget);
      expect(find.textContaining('System online'), findsNothing);
      api
        ..failStats = false
        ..controlledStats = true;
      await tester.tap(find.text('Retry snapshot'));
      await _frames(tester);
      expect(
        find.textContaining('Previously loaded snapshot may be stale.'),
        findsOneWidget,
      );
      expect(find.textContaining('Last successful update'), findsOneWidget);
      expect(_profile(tester).inFlow, '24');
      api.snapshots.last.complete(_stats(32));
      await _frames(tester);
      expect(_profile(tester).inFlow, '32');
      expect(find.textContaining('may be stale'), findsNothing);
    },
  );

  testWidgets(
    'An unavailable status read is unknown and can retry instead of confirming offline',
    (tester) async {
      final api = _Api()..failStatus = true;
      await _mount(tester, api);
      expect(find.textContaining('System status unavailable.'), findsOneWidget);
      expect(find.text('System status unknown.'), findsOneWidget);
      expect(find.textContaining('Services unavailable ·'), findsNothing);
      expect(find.textContaining('System online'), findsNothing);
      api.failStatus = false;
      await tester.tap(find.text('Retry snapshot'));
      await tester.pumpAndSettle();
      expect(find.textContaining('System online'), findsOneWidget);
    },
  );

  testWidgets('Only the latest Admin Profile read can publish a snapshot', (
    tester,
  ) async {
    final api = _Api();
    await _mount(tester, api);
    api.controlledStats = true;
    final reload = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    final older = reload();
    await tester.pump();
    final newer = reload();
    await tester.pump();
    api.snapshots[1].complete(_stats(40));
    await _frames(tester);
    await newer;
    api.snapshots[0].complete(_stats(999));
    await _frames(tester);
    await older;
    expect(_profile(tester).inFlow, '40');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A replaced login and disposed Profile ignore the previous snapshot',
    (tester) async {
      final api = _Api();
      final auth = await _mount(tester, api);
      api.controlledStats = true;
      final older = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      auth.replaceLogin();
      await tester.pump();
      expect(api.snapshots, hasLength(2));
      api.snapshots[1].complete(_stats(41));
      await _frames(tester);
      api.snapshots[0].complete(_stats(999));
      await older;
      await _frames(tester);
      expect(_profile(tester).inFlow, '41');
      final pending = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      api.snapshots.last.complete(_stats(1000));
      await pending;
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Signup confirmation reserves the decision and cancel releases it',
    (tester) async {
      final api = _Api();
      await _mount(tester, api, users: true);
      final previous = _signup(tester);
      previous.onApprove();
      previous.onReject();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_signup(tester).enabled, isFalse);
      final reads = api.listReads;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      expect(api.listReads, reads);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_signup(tester).enabled, isTrue);
      expect(api.decisions, isEmpty);
    },
  );

  for (final action in ['approve', 'reject']) {
    testWidgets(
      'Pending signup $action blocks duplicates and a failed logout preserves its outcome',
      (tester) async {
        final api = _Api()..decision = Completer<void>();
        final auth = await _mount(tester, api, users: true);
        final previous = _signup(tester);
        (action == 'approve' ? previous.onApprove : previous.onReject)();
        await tester.pumpAndSettle();
        await _confirm(tester, action == 'approve' ? 'Approve' : 'Reject');
        expect(api.decisions, [(203, action)]);
        expect(_signup(tester).pendingAction, action);
        expect(_signup(tester).enabled, isFalse);
        expect(
          find.text(
            action == 'approve' ? 'Approving sign-up…' : 'Rejecting sign-up…',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<SfAdminUserCard>(find.byType(SfAdminUserCard))
              .onToggleActive,
          isNull,
        );
        previous.onApprove();
        previous.onReject();
        await _frames(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(api.decisions, hasLength(1));
        auth.logoutPending(true);
        api.decision!.completeError(
          ApiException('Sample decision rejected', 409),
        );
        await _frames(tester);
        auth.logoutPending(false);
        await tester.pumpAndSettle();
        expect(find.text('Sample decision rejected'), findsOneWidget);
        expect(_signup(tester).enabled, isTrue);
        expect(_signup(tester).pendingAction, isNull);
      },
    );
  }

  testWidgets('A signup response cannot publish after the page is disposed', (
    tester,
  ) async {
    final api = _Api()..decision = Completer<void>();
    await _mount(tester, api, users: true);
    _signup(tester).onApprove();
    await tester.pumpAndSettle();
    await _confirm(tester, 'Approve');
    final reads = api.listReads;
    await tester.pumpWidget(const SizedBox.shrink());
    api.decision!.complete();
    await _frames(tester);
    expect(api.listReads, reads);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Successful signup approval refreshes the directory and clears pending feedback',
    (tester) async {
      final api = _Api()..decision = Completer<void>();
      await _mount(tester, api, users: true);
      _signup(tester).onApprove();
      await tester.pumpAndSettle();
      await _confirm(tester, 'Approve');
      final reads = api.listReads;
      api.decision!.complete();
      await _frames(tester);
      expect(api.listReads, reads + 1);
      expect(find.byType(SfAdminPendingSignupCard), findsNothing);
      expect(find.text('Approving…'), findsNothing);
      expect(find.text('Sign-up approved — account is active'), findsOneWidget);
      expect(
        tester
            .widget<SfAdminUserCard>(find.byType(SfAdminUserCard))
            .onToggleActive,
        isNotNull,
      );
    },
  );
}
