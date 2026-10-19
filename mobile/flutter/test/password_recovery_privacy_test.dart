import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartflow/screens/auth/forgot_password_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _mount(
  WidgetTester tester,
  SmartflowApi api,
  void Function(Object?) onReset,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => ForgotPasswordScreen(api: api),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) {
          onReset(state.extra);
          return const Scaffold(body: Text('Reset password details'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: buildSmartflowTheme()),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final legacyResponse in [false, true]) {
    testWidgets(
      'password recovery requires an entered code with ${legacyResponse ? 'legacy code-bearing' : 'generic'} response',
      (tester) async {
        Map<String, dynamic>? resetDetails;
        final api = SmartflowApi(
          ApiClient(
            client: MockClient((request) async {
              expect(request.url.pathSegments.last, 'auth-forgot-password.php');
              expect(jsonDecode(request.body), {
                'username': 'synthetic.reviewer',
              });
              return http.Response(
                jsonEncode({
                  'success': true,
                  'message':
                      'If an account exists, check its registered email.',
                  if (legacyResponse) 'dev_reset_code': '123456',
                }),
                200,
              );
            }),
          ),
        );
        await _mount(tester, api, (extra) {
          resetDetails = Map<String, dynamic>.from(extra as Map);
        });
        await tester.enterText(_field('Username'), 'synthetic.reviewer');
        await tester.ensureVisible(find.text('Send reset code'));
        await tester.tap(find.text('Send reset code'));
        await tester.pumpAndSettle();
        expect(find.text('Check your email'), findsOneWidget);
        expect(find.textContaining('Development test code'), findsNothing);
        expect(find.textContaining('123456'), findsNothing);
        expect(
          tester.widget<TextField>(_field('Enter reset code')).controller!.text,
          isEmpty,
        );
        final verify = find.text('Verify & reset password');
        await tester.ensureVisible(verify);
        await tester.tap(verify);
        await tester.pumpAndSettle();
        expect(resetDetails, isNull);
        expect(find.text('Please enter 6-digit code'), findsOneWidget);
        await tester.enterText(_field('Enter reset code'), '654321');
        await tester.ensureVisible(verify);
        await tester.tap(verify);
        await tester.pumpAndSettle();
        expect(resetDetails, {
          'username': 'synthetic.reviewer',
          'code': '654321',
        });
        expect(find.text('Reset password details'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'already-have-code navigation keeps manual entry without requesting a code',
    (tester) async {
      Object? resetDetails;
      final api = SmartflowApi(
        ApiClient(
          client: MockClient((_) async {
            throw StateError(
              'Manual reset entry must not request another code',
            );
          }),
        ),
      );
      await _mount(tester, api, (extra) => resetDetails = extra);
      await tester.enterText(_field('Username'), 'synthetic.reviewer');
      await tester.ensureVisible(find.text('Already have a code?'));
      await tester.tap(find.text('Already have a code?'));
      await tester.pumpAndSettle();
      expect(resetDetails, {'username': 'synthetic.reviewer'});
      expect(tester.takeException(), isNull);
    },
  );
}
