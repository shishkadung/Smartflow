import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/auth/signup_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/utils/printable_label.dart';

const user = {
  'id': 1,
  'name': 'Test Staff',
  'username': 'staff',
  'role': 'staff',
  'office_id': 1,
  'office_name': 'Engineering',
  'office_code': 'ENG',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  test('all authenticated transports keep credentials in headers', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      token: 'private-session',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          request.url.path.endsWith('qr-label.php')
              ? '<!doctype html>label'
              : '{"success":true}',
          200,
        );
      }),
    );
    await client.get('check.php', query: {'id': 'DOC-1'});
    await client.post('write.php', body: {'note': 'visible value'});
    await client.postMultipart('avatar.php', fields: {'remove': '1'});
    await SmartflowApi(client).printableLabel('DOC-1');
    for (final request in requests) {
      expect(request.url.toString(), isNot(contains('private-session')));
      expect(request.body, isNot(contains('private-session')));
      expect(request.headers['Authorization'], 'Bearer private-session');
      expect(request.headers['X-Smartflow-Token'], 'private-session');
    }
  });
  test('signup status sends ownership proof in a public POST body', () async {
    final api = SmartflowApi(
      ApiClient(
        token: 'unrelated-session',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.query, isEmpty);
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect(jsonDecode(request.body), {
            'request_code': 'REQ-1',
            'status_key': 'owner-proof',
          });
          return http.Response(
            '{"success":true,"request":{"status":"pending"}}',
            200,
          );
        }),
      ),
    );
    await api.signupStatus(code: 'REQ-1', statusKey: 'owner-proof');
  });
  test(
    'failed logout retains identity and saved session until server confirmation',
    () async {
      SharedPreferences.setMockInitialValues({});
      var rejectLogout = true;
      final auth = AuthProvider(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('auth-login.php')) {
            return http.Response(
              jsonEncode({'success': true, 'token': 'session-1', 'user': user}),
              200,
            );
          }
          if (request.url.path.endsWith('auth-logout.php') && rejectLogout) {
            return http.Response('{"success":false,"message":"Offline"}', 503);
          }
          return http.Response('{"success":true}', 200);
        }),
      );
      try {
        await auth.login('staff', 'test-password');
        await expectLater(auth.logout(), throwsA(isA<ApiException>()));
        expect(auth.isAuthenticated, isTrue);
        expect(auth.loggingOut, isFalse);
        expect(
          (await SharedPreferences.getInstance()).getString('smartflow_token'),
          'session-1',
        );
        rejectLogout = false;
        await auth.logout();
        expect(auth.isAuthenticated, isFalse);
        expect(
          (await SharedPreferences.getInstance()).getString('smartflow_token'),
          isNull,
        );
      } finally {
        auth.dispose();
      }
    },
  );
  test('delayed session clearing cannot erase a newer login', () async {
    SharedPreferences.setMockInitialValues({});
    var sequence = 0;
    final auth = AuthProvider(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'token': 'session-${++sequence}',
            'user': user,
          }),
          200,
        ),
      ),
    );
    try {
      await auth.login('staff', 'test-password');
      final oldToken = auth.token!;
      await auth.login('staff', 'test-password');
      await auth.endSession(oldToken, message: 'Old change response');
      expect(auth.token, 'session-2');
      expect(auth.sessionMessage, isNull);
      await auth.endSession(
        'session-2',
        message: 'Password changed. Sign in again.',
      );
      expect(auth.isAuthenticated, isFalse);
      expect(auth.sessionMessage, contains('Sign in again'));
    } finally {
      auth.dispose();
    }
  });
  testWidgets('native label printing embeds QR without network or JavaScript', (
    tester,
  ) async {
    late String output;
    await tester.runAsync(() async {
      output = await preparePrintableLabel(
        '\n<!doctype html><html><head></head><body>'
        '<div class="qr" id="label-qr"><noscript>Enable scripts</noscript></div>'
        '<script type="application/json" id="qr-label-data">{"payload":"SF1.TEST-PAYLOAD","size":220}</script>'
        '<script src="qr-generator.js"></script></body></html>',
      );
    });
    expect(output, startsWith('<!doctype html>'));
    expect(output, contains('data:image/png;base64,'));
    expect(output, isNot(contains('<script')));
    expect(output, isNot(contains('<noscript')));
    expect(output, isNot(contains('http')));
    await expectLater(
      preparePrintableLabel('<!doctype html>bad label'),
      throwsFormatException,
    );
  });
  testWidgets(
    'leaving signup status before its response does not touch disposed controllers',
    (tester) async {
      final response = Completer<http.Response>();
      final auth = AuthProvider(httpClient: MockClient((_) => response.future));
      final router = GoRouter(
        initialLocation: '/signup/pending',
        routes: [
          GoRoute(
            path: '/login',
            builder: (_, _) => const Scaffold(body: Text('Login destination')),
          ),
          GoRoute(
            path: '/signup/pending',
            builder: (_, _) => const SignupPendingScreen(
              requestCode: 'REQ-1',
              username: 'applicant',
              summary: {'status_key': 'owner-proof'},
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Back').first);
      await tester.pumpAndSettle();
      expect(find.text('Login destination'), findsOneWidget);
      response.complete(
        http.Response(
          '{"success":false,"message":"Unable to verify request"}',
          404,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
    },
  );
}
