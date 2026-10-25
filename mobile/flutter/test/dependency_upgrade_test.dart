import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/router.dart';
import 'package:smartflow/screens/auth/login_screen.dart';
import 'package:smartflow/screens/shared/documents_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/utils/format_time.dart';
import 'package:smartflow/widgets/sf_account_menu.dart';

/// Routes use the real screens and API decoding, with no live backend requests.
class _RoutingAuth extends AuthProvider {
  _RoutingAuth(String? role) {
    if (role != null) {
      _identity = AppUser(
        id: 101,
        name: 'Routing regression user',
        username: 'routing.$role',
        role: role,
        officeId: 1,
        officeName: 'Engineering Office',
        officeCode: 'ENG',
      );
    }
  }

  AppUser? _identity;
  bool _ending = false;
  final logoutResponse = Completer<void>();
  final unexpectedRequests = <String>[];
  final requestedEndpoints = <String>[];
  late final _fixtureApi = SmartflowApi(
    ApiClient(
      token: 'fixture-token',
      client: MockClient((request) async {
        final endpoint = request.url.pathSegments.last;
        requestedEndpoints.add(endpoint);
        const fixtures = <String, Map<String, dynamic>>{
          'alerts-list.php': {'alerts': []},
          'dashboard-stats.php': {'stats': {}},
          'head-dashboard.php': {'stats': {}, 'queue': []},
          'accountant-dashboard.php': {'stats': {}},
          'document-requests-summary.php': {},
          'office-documents.php': {
            'documents': [],
            'total': 0,
            'has_more': false,
            'tray_counts': {},
            'overdue_count': 0,
          },
        };
        final fixture = fixtures[endpoint];
        if (request.method != 'GET' || fixture == null) {
          unexpectedRequests.add('${request.method} $endpoint');
          return http.Response('{"success":false}', 500);
        }
        return http.Response(jsonEncode({'success': true, ...fixture}), 200);
      }),
    ),
  );

  @override
  AppUser? get user => _identity;
  @override
  bool get isAuthenticated => _identity != null && !_ending;
  @override
  bool get loggingOut => _ending;
  @override
  Future<void> logout() async {
    _ending = true;
    notifyListeners();
    try {
      await logoutResponse.future;
      throw ApiException('Portal temporarily unavailable', 503);
    } finally {
      _ending = false;
      notifyListeners();
    }
  }

  @override
  bool get loading => false;
  @override
  SmartflowApi get api => _fixtureApi;

  void expireSession() {
    _identity = null;
    sessionMessage = 'Your session has ended. Please sign in again.';
    notifyListeners();
  }
}

Future<GoRouter> _mountRouter(WidgetTester tester, _RoutingAuth auth) async {
  SharedPreferences.setMockInitialValues({
    'sf_role_tip_seen_v2_${auth.user?.username}': true,
  });
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = createRouter(auth);
  addTearDown(router.dispose);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(
        theme: ThemeData(platform: TargetPlatform.windows),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets(
    'failed logout retains the protected screen and displays its error',
    (tester) async {
      final auth = _RoutingAuth('staff');
      final router = await _mountRouter(tester, auth);
      router.go('/staff/documents');
      await tester.pumpAndSettle();
      final original = tester.state(find.byType(DocumentsScreen));
      final signingOut = sfLogout(tester.element(find.byType(DocumentsScreen)));
      await tester.pump();
      expect(find.byType(DocumentsScreen), findsOneWidget);
      expect(tester.state(find.byType(DocumentsScreen)), same(original));
      auth.logoutResponse.complete();
      await signingOut;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(DocumentsScreen)), same(original));
      expect(find.textContaining('Could not sign out.'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/staff/documents',
      );
      expect(auth.isAuthenticated, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  for (final role in ['staff', 'head', 'admin']) {
    testWidgets('$role routing, documents, access control and session expiry', (
      tester,
    ) async {
      final auth = _RoutingAuth(role);
      final router = await _mountRouter(tester, auth);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/$role');

      router.go('/$role/documents');
      await tester.pumpAndSettle();
      expect(find.byType(DocumentsScreen), findsOneWidget);
      expect(auth.requestedEndpoints, contains('office-documents.php'));

      if (role != 'staff') {
        for (final registerPath in ['/$role/register', '/staff/register']) {
          router.go(registerPath);
          await tester.pumpAndSettle();
          expect(router.routerDelegate.currentConfiguration.uri.path, '/$role');
          expect(
            auth.requestedEndpoints,
            isNot(contains('documents-create.php')),
          );
        }
      }

      for (final otherRole in ['staff', 'head', 'admin']) {
        if (otherRole == role) continue;
        router.go('/$otherRole');
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.uri.path, '/$role');
      }

      auth.expireSession();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(auth.sessionMessage!), findsOneWidget);
      expect(auth.unexpectedRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('signed-out users cannot open protected document routes', (
    tester,
  ) async {
    final auth = _RoutingAuth(null);
    final router = await _mountRouter(tester, auth);
    router.go('/staff/documents');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(auth.requestedEndpoints, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  test('upgraded intl preserves municipal movement date formatting', () {
    expect(formatSmartflowTime('2000-01-02 13:05:00'), 'Jan 2, 1:05 PM');
    expect(formatMovementListTime('2000-01-02 13:05:00'), 'Jan 2, 1:05 PM');
    expect(formatMovementListTime(null), '—');
    expect(formatMovementListTime('invalid timestamp'), 'invalid timestamp');
  });

  test('optional API fields remain omitted from requests', () async {
    final requests = <http.Request>[];
    final api = SmartflowApi(
      ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"success":true}', 200);
        }),
      ),
    );
    await api.officeDocuments();
    expect(requests.single.url.queryParameters, isEmpty);
    await api.recordMovement(
      documentId: 'DOC-2026-000101',
      officeId: 1,
      status: 'OUT',
      expectedMovementId: 17,
    );
    expect(jsonDecode(requests.last.body), {
      'document_id': 'DOC-2026-000101',
      'office_id': 1,
      'status': 'OUT',
      'expected_movement_id': 17,
    });
  });
}
