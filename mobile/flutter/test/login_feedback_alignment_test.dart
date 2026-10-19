import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/auth/login_screen.dart';
import 'package:smartflow/widgets/sf_widgets.dart';

void main() {
  for (final sample in [
    (390.0, 1.0, 'Password changed. Sign in again with your new password.'),
    (320.0, 2.0, 'Your session has ended. Please sign in again.'),
  ]) {
    testWidgets(
      'new sign-in error replaces prior session guidance at ${sample.$1}px / ${sample.$2}x',
      (tester) async {
        var attempts = 0;
        final auth = AuthProvider(
          httpClient: MockClient((request) async {
            attempts++;
            expect(request.method, 'POST');
            expect(request.url.pathSegments.last, 'auth-login.php');
            expect(jsonDecode(request.body), {
              'username': 'synthetic.login',
              'password': 'synthetic-invalid-password',
            });
            return http.Response(
              jsonEncode({
                'success': false,
                'message': 'Invalid username or password',
              }),
              401,
            );
          }),
        )..sessionMessage = sample.$3;
        addTearDown(auth.dispose);
        tester.view.physicalSize = Size(sample.$1, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              theme: ThemeData(platform: TargetPlatform.windows),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(sample.$2)),
                child: child!,
              ),
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(sample.$3), findsOneWidget);
        final username = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'Username',
        );
        final password = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'Password',
        );
        await tester.enterText(username, 'synthetic.login');
        await tester.enterText(password, 'synthetic-invalid-password');
        final submit = find.byType(SfPrimaryButton);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text('Invalid username or password'), findsOneWidget);
        expect(find.text(sample.$3), findsNothing);
        expect(auth.sessionMessage, sample.$3);
        expect(attempts, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
