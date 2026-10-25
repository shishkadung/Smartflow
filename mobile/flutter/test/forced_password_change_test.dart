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
import 'package:smartflow/router.dart';
import 'package:smartflow/screens/auth/forced_password_change_screen.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/widgets/sf_widgets.dart';

Map<String, dynamic> user({required bool mustChange}) => {
  'id': 7,
  'username': 'synthetic7',
  'name': 'Synthetic Seven',
  'role': 'staff',
  'office_id': 1,
  'office_code': 'ENG',
  'office_name': 'Engineering Office',
  'must_change_password': mustChange,
};

http.Response ok(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'success': true, ...data}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('the temporary-password flag is read, saved and defaults to false', () {
    expect(AppUser.fromJson(user(mustChange: true)).mustChangePassword, isTrue);
    expect(
      AppUser.fromJson(user(mustChange: false)).mustChangePassword,
      isFalse,
    );
    final plain = Map<String, dynamic>.of(user(mustChange: false))
      ..remove('must_change_password');
    expect(AppUser.fromJson(plain).mustChangePassword, isFalse);
    final saved = AppUser.fromJson(user(mustChange: true)).toJson();
    expect(AppUser.fromJson(saved).mustChangePassword, isTrue);
    expect(
      AppUser.fromJson(
        user(mustChange: true),
      ).copyWith(name: 'Renamed').mustChangePassword,
      isTrue,
    );
  });

  // The session watcher is a periodic timer, so each test must dispose the tree and provider itself.
  Future<void> finish(
    WidgetTester tester,
    AuthProvider auth,
    GoRouter router,
  ) async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    auth.dispose();
  }

  Future<(AuthProvider, List<String>, GoRouter)> pumpApp(
    WidgetTester tester, {
    required bool mustChange,
    int changeStatus = 200,
    String changeMessage = '',
    Future<http.Response> Function()? onLogout,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final calls = <String>[];
    final auth = AuthProvider(
      httpClient: MockClient((request) async {
        final endpoint = request.url.pathSegments.last;
        calls.add(endpoint);
        if (endpoint == 'auth-login.php') {
          return ok({
            'token': 'synthetic-token',
            'user': user(mustChange: mustChange),
          });
        }
        if (endpoint == 'users-change-password.php') {
          if (changeStatus != 200) {
            return http.Response(
              jsonEncode({'success': false, 'message': changeMessage}),
              changeStatus,
            );
          }
          return ok({'message': 'Password updated'});
        }
        if (endpoint == 'auth-logout.php' && onLogout != null) {
          return onLogout();
        }
        return ok({'user': user(mustChange: mustChange)});
      }),
    );
    await auth.bootstrap();
    final router = createRouter(auth);
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
    await tester.enterText(find.byType(TextField).at(0), 'synthetic7');
    await tester.enterText(find.byType(TextField).at(1), 'temporary-pw-1');
    await tester.tap(signIn);
    await tester.pumpAndSettle();
    return (auth, calls, router);
  }

  testWidgets('a temporary-password sign-in is held on the change screen', (
    tester,
  ) async {
    final (auth, _, router) = await pumpApp(tester, mustChange: true);
    expect(auth.isAuthenticated, isTrue);
    expect(find.byType(ForcedPasswordChangeScreen), findsOneWidget);
    expect(find.text('Choose a new password'), findsOneWidget);
    expect(find.text('Temporary password'), findsOneWidget);
    await finish(tester, auth, router);
  });

  testWidgets('a normal sign-in never shows the change screen', (tester) async {
    final (auth, _, router) = await pumpApp(tester, mustChange: false);
    expect(find.byType(ForcedPasswordChangeScreen), findsNothing);
    await finish(tester, auth, router);
  });

  testWidgets('failed Sign out explains the retained session and can retry', (
    tester,
  ) async {
    var failLogout = true;
    final (auth, calls, router) = await pumpApp(
      tester,
      mustChange: true,
      onLogout: () async => failLogout
          ? http.Response(
              jsonEncode({
                'success': false,
                'message': 'Synthetic logout unavailable',
              }),
              503,
            )
          : ok({}),
    );
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.isAuthenticated, isTrue);
    expect(find.byType(ForcedPasswordChangeScreen), findsOneWidget);
    expect(find.textContaining('Could not sign out.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    failLogout = false;
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.isAuthenticated, isFalse);
    expect(find.byType(ForcedPasswordChangeScreen), findsNothing);
    expect(calls.where((call) => call == 'auth-logout.php').length, 2);
    await finish(tester, auth, router);
  });

  testWidgets('weak, matching and unchanged passwords are refused locally', (
    tester,
  ) async {
    final (auth, calls, router) = await pumpApp(tester, mustChange: true);
    Future<void> attempt(String current, String next, String confirm) async {
      await tester.enterText(find.byType(TextField).at(0), current);
      await tester.enterText(find.byType(TextField).at(1), next);
      await tester.enterText(find.byType(TextField).at(2), confirm);
      await tester.tap(
        find.widgetWithText(SfPrimaryButton, 'Save new password'),
      );
      await tester.pumpAndSettle();
    }

    await attempt('temporary-pw-1', 'short', 'short');
    expect(find.textContaining('at least 8 characters'), findsWidgets);
    await attempt('temporary-pw-1', 'long-enough-pw-2', 'different-pw-3');
    expect(find.textContaining('do not match'), findsOneWidget);
    await attempt('temporary-pw-1', 'temporary-pw-1', 'temporary-pw-1');
    expect(find.textContaining('different from the temporary'), findsOneWidget);
    expect(calls.contains('users-change-password.php'), isFalse);
    await finish(tester, auth, router);
  });

  testWidgets('a server refusal is shown and the user stays on the screen', (
    tester,
  ) async {
    final (auth, _, router) = await pumpApp(
      tester,
      mustChange: true,
      changeStatus: 400,
      changeMessage: 'Current password is incorrect',
    );
    await tester.enterText(find.byType(TextField).at(0), 'wrong-temp-pw');
    await tester.enterText(find.byType(TextField).at(1), 'long-enough-pw-2');
    await tester.enterText(find.byType(TextField).at(2), 'long-enough-pw-2');
    await tester.tap(find.widgetWithText(SfPrimaryButton, 'Save new password'));
    await tester.pumpAndSettle();
    expect(find.text('Current password is incorrect'), findsOneWidget);
    expect(find.byType(ForcedPasswordChangeScreen), findsOneWidget);
    await finish(tester, auth, router);
  });

  testWidgets(
    'a successful change ends the session and asks for a new sign-in',
    (tester) async {
      final (auth, calls, router) = await pumpApp(tester, mustChange: true);
      await tester.enterText(find.byType(TextField).at(0), 'temporary-pw-1');
      await tester.enterText(find.byType(TextField).at(1), 'long-enough-pw-2');
      await tester.enterText(find.byType(TextField).at(2), 'long-enough-pw-2');
      await tester.tap(
        find.widgetWithText(SfPrimaryButton, 'Save new password'),
      );
      await tester.pumpAndSettle();
      expect(calls.where((c) => c == 'users-change-password.php').length, 1);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.sessionMessage, contains('Sign in again'));
      expect(find.byType(ForcedPasswordChangeScreen), findsNothing);
      await finish(tester, auth, router);
    },
  );
}
