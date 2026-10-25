import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/router.dart';
import 'package:smartflow/screens/auth/login_screen.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/widgets/sf_widgets.dart';

Map<String, dynamic> syntheticUser(int id) => {
  'id': id,
  'username': 'synthetic$id',
  'name': 'Synthetic $id',
  'role': 'staff',
  'office_id': id,
  'office_code': id == 1 ? 'ENG' : 'ACC',
  'office_name': id == 1 ? 'Engineering Office' : 'Accounting Office',
};

http.Response ok(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'success': true, ...data}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test(
    'abandoning login during queued persistence restores the prior signed-out state',
    () async {
      const channel = MethodChannel('plugins.flutter.io/shared_preferences');
      SharedPreferences.resetStatic();
      final stored = <String, Object>{};
      final writing = Completer<void>();
      final release = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getAll') return stored;
            final args = call.arguments as Map;
            if (call.method == 'setString' &&
                args['key'] == 'flutter.smartflow_token' &&
                !writing.isCompleted) {
              writing.complete();
              await release.future;
            }
            if (call.method == 'remove') {
              stored.remove(args['key']);
            } else {
              stored[args['key'] as String] = args['value'] as Object;
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final auth = AuthProvider(
        httpClient: MockClient(
          (_) async =>
              ok({'token': 'abandoned-candidate', 'user': syntheticUser(1)}),
        ),
      );
      addTearDown(auth.dispose);
      final owner = auth.beginLoginAttempt();
      final pending = auth.login(
        'synthetic1',
        'synthetic-password',
        attempt: owner,
      );
      await writing.future;
      auth.cancelLoginAttempt(owner);
      release.complete();
      expect(await pending, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.token, isNull);
      expect(stored, isEmpty);
    },
  );

  for (final staleFails in [false, true]) {
    test(
      'latest login owns state when the older request ${staleFails ? 'fails' : 'succeeds'}',
      () async {
        SharedPreferences.setMockInitialValues({});
        final first = Completer<http.Response>();
        final auth = AuthProvider(
          httpClient: MockClient((request) async {
            final name = (jsonDecode(request.body) as Map)['username'];
            return name == 'synthetic1'
                ? first.future
                : ok({'token': 'new-login', 'user': syntheticUser(2)});
          }),
        );
        addTearDown(auth.dispose);
        final older = auth.login('synthetic1', 'synthetic-password');
        expect(await auth.login('synthetic2', 'synthetic-password'), isTrue);
        first.complete(
          staleFails
              ? http.Response(
                  '{"success":false,"message":"Old invalid password"}',
                  401,
                )
              : ok({'token': 'old-login', 'user': syntheticUser(1)}),
        );
        expect(await older, isFalse);
        expect(auth.token, 'new-login');
        expect(auth.user?.id, 2);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString('smartflow_token'), 'new-login');
        expect(
          (jsonDecode(preferences.getString('smartflow_user')!) as Map)['id'],
          2,
        );
      },
    );
  }

  test(
    'cancelling an abandoned owner cannot cancel a newer login attempt',
    () async {
      SharedPreferences.setMockInitialValues({});
      final response = Completer<http.Response>();
      final auth = AuthProvider(httpClient: MockClient((_) => response.future));
      addTearDown(auth.dispose);
      final abandoned = auth.beginLoginAttempt();
      final newer = auth.beginLoginAttempt();
      final pending = auth.login(
        'synthetic2',
        'synthetic-password',
        attempt: newer,
      );
      auth.cancelLoginAttempt(abandoned);
      response.complete(ok({'token': 'owned-login', 'user': syntheticUser(2)}));
      expect(await pending, isTrue);
      expect(auth.user?.id, 2);
    },
  );

  test('session end supersedes an already-started replacement login', () async {
    SharedPreferences.setMockInitialValues({});
    final response = Completer<http.Response>();
    final auth = AuthProvider(
      httpClient: MockClient((request) async {
        final name = (jsonDecode(request.body) as Map)['username'];
        return name == 'synthetic2'
            ? response.future
            : ok({'token': 'initial-login', 'user': syntheticUser(1)});
      }),
    );
    addTearDown(auth.dispose);
    await auth.login('synthetic1', 'synthetic-password');
    final pending = auth.login('synthetic2', 'synthetic-password');
    await auth.endSession('initial-login');
    response.complete(ok({'token': 'late-login', 'user': syntheticUser(2)}));
    expect(await pending, isFalse);
    expect(auth.isAuthenticated, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getString('smartflow_token'),
      isNull,
    );
  });

  testWidgets(
    'real Back/reopen controls discard abandoned A after newer B signs in',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'sf_role_tip_seen_v2_synthetic1': true,
        'sf_role_tip_seen_v2_synthetic2': true,
      });
      final first = Completer<http.Response>();
      final second = Completer<http.Response>();
      final loginNames = <String>[];
      final unexpected = <String>[];
      final auth = AuthProvider(
        httpClient: MockClient((request) async {
          final endpoint = request.url.pathSegments.last;
          if (endpoint == 'auth-login.php') {
            final name =
                (jsonDecode(request.body) as Map)['username'] as String;
            loginNames.add(name);
            return name == 'synthetic1' ? first.future : second.future;
          }
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
            unexpected.add('${request.method} $endpoint');
            return http.Response('{"success":false}', 500);
          }
          return ok(fixture);
        }),
      );
      await auth.bootstrap();
      final router = createRouter(auth);
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildSmartflowTheme(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final signIn = find.widgetWithText(SfPrimaryButton, 'Sign in');
      await tester.tap(signIn);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'synthetic1');
      await tester.enterText(
        find.byType(TextField).at(1),
        'synthetic-password',
      );
      await tester.tap(signIn);
      await tester.pump();
      expect(loginNames, ['synthetic1']);
      final oldLogin = tester.state(find.byType(LoginScreen));

      // This remains enabled during the pending HTTP request in the real screen.
      await tester.tap(find.text('Back to welcome'));
      await tester.pumpAndSettle();
      expect(oldLogin.mounted, isFalse);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      await tester.tap(signIn);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'synthetic2');
      await tester.enterText(
        find.byType(TextField).at(1),
        'synthetic-password',
      );
      await tester.tap(signIn);
      await tester.pump();
      expect(loginNames, ['synthetic1', 'synthetic2']);

      second.complete(
        ok({'token': 'synthetic-session-b', 'user': syntheticUser(2)}),
      );
      await tester.pumpAndSettle();
      expect(auth.user?.id, 2);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/staff');
      final preferences = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(preferences.getString('smartflow_user')!) as Map)['id'],
        2,
      );

      first.complete(
        ok({'token': 'synthetic-session-a', 'user': syntheticUser(1)}),
      );
      await tester.pumpAndSettle();
      expect(auth.user?.id, 2);
      expect(auth.user?.officeId, 2);
      expect(auth.token, 'synthetic-session-b');
      expect(preferences.getString('smartflow_token'), 'synthetic-session-b');
      expect(
        (jsonDecode(preferences.getString('smartflow_user')!) as Map)['id'],
        2,
      );
      expect(router.routerDelegate.currentConfiguration.uri.path, '/staff');
      expect(unexpected, isEmpty);
      expect(tester.takeException(), isNull);
      // Only synthetic ids: no live requests, account data, or tokens in evidence.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      auth.dispose();
    },
  );

  testWidgets(
    'failed login after actual Back must not update disposed screen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final pending = Completer<http.Response>();
      var loginCount = 0;
      final auth = AuthProvider(
        httpClient: MockClient((request) async {
          expect(request.url.pathSegments.last, 'auth-login.php');
          loginCount++;
          return pending.future;
        }),
      );
      await auth.bootstrap();
      final router = createRouter(auth);
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildSmartflowTheme(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final signIn = find.widgetWithText(SfPrimaryButton, 'Sign in');
      await tester.tap(signIn);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'synthetic1');
      await tester.enterText(
        find.byType(TextField).at(1),
        'synthetic-password',
      );
      await tester.tap(signIn);
      await tester.pump();
      expect(loginCount, 1);
      final oldLogin = tester.state(find.byType(LoginScreen));
      await tester.tap(find.text('Back to welcome'));
      await tester.pumpAndSettle();
      expect(oldLogin.mounted, isFalse);
      pending.complete(
        http.Response(
          jsonEncode({
            'success': false,
            'message': 'Invalid username or password',
          }),
          401,
        ),
      );
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      auth.dispose();
    },
  );
}
