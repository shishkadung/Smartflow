import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/auth/forgot_password_screen.dart';
import 'package:smartflow/screens/auth/login_screen.dart';
import 'package:smartflow/screens/auth/signup_screen.dart';
import 'package:smartflow/widgets/sf_pdf_chrome.dart';
import 'package:smartflow/widgets/sf_widgets.dart';

Future<void> _pump(
  WidgetTester tester,
  AuthProvider auth,
  String initial,
) async {
  tester.view.physicalSize = const Size(390, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a sign-in error is gone after visiting Forgot password and coming back', (
    tester,
  ) async {
    final auth = AuthProvider(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"success":false,"message":"Username and password are required"}',
          400,
        ),
      ),
    );
    addTearDown(auth.dispose);
    await _pump(tester, auth, '/login');
    await tester.tap(find.widgetWithText(SfPrimaryButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Username and password are required'), findsOneWidget);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsWidgets);
    await tester.tap(find.textContaining('Back to sign in').first);
    await tester.pumpAndSettle();
    expect(find.text('Username and password are required'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Forgot password says where the code goes', (tester) async {
    final auth = AuthProvider(
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(auth.dispose);
    await _pump(tester, auth, '/forgot-password');
    expect(
      find.textContaining('emailed to the address on your account'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Request access states the approval rule once', (tester) async {
    final auth = AuthProvider(
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(auth.dispose);
    await _pump(tester, auth, '/signup');
    expect(find.textContaining('Admin approval required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an avatar with a photo that cannot load still shows the initials', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SfSquareGradientAvatar(
              initials: 'PA',
              imageUrl: 'http://127.0.0.1:9/missing-avatar.webp',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('PA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an avatar without a photo shows the initials', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SfSquareGradientAvatar(initials: 'NA')),
        ),
      ),
    );
    expect(find.text('NA'), findsOneWidget);
  });
}
