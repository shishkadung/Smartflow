import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/screens/shared/edit_profile_sheet.dart';
import 'package:smartflow/screens/shared/profile_photo.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

Map<String, dynamic> user(int id, {String? name}) => {
  'id': id,
  'username': 'synthetic$id',
  'name': name ?? 'Synthetic $id',
  'email': 'synthetic$id@example.test',
  'role': 'admin',
  'office_id': 3,
  'office_code': 'ACC',
  'office_name': 'Accounting Office',
};
http.Response ok(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'success': true, ...data}), 200);

AuthProvider authWith(Future<http.Response> Function(http.Request)? endpoint) {
  var sequence = 0;
  return AuthProvider(
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('auth-login.php')) {
        final id = (jsonDecode(request.body) as Map)['username'] == 'synthetic2'
            ? 2
            : 1;
        return ok({'token': 'synthetic-$id-${++sequence}', 'user': user(id)});
      }
      return endpoint == null ? ok({}) : endpoint(request);
    }),
  );
}

Future<GoRouter> mount(
  WidgetTester tester,
  AuthProvider auth,
  Widget child,
) async {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
    ],
  );
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
  return router;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  const preferences = MethodChannel('plugins.flutter.io/shared_preferences');
  const picker = MethodChannel('plugins.flutter.io/image_picker');
  late Map<String, Object> stored;
  Future<void> Function(MethodCall)? beforeWrite;
  setUp(() {
    SharedPreferences.resetStatic();
    stored = {};
    beforeWrite = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferences, (call) async {
          if (call.method == 'getAll') return Map<String, Object>.from(stored);
          await beforeWrite?.call(call);
          final args = call.arguments as Map;
          if (call.method == 'remove') {
            stored.remove(args['key']);
          } else {
            stored[args['key'] as String] = args['value'] as Object;
          }
          return true;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferences, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(picker, null);
  });

  test(
    'current profile refresh is saved; wrong user, old login and logout responses are rejected',
    () async {
      final auth = authWith(null);
      addTearDown(auth.dispose);
      await auth.login('synthetic1', 'synthetic-password');
      final originalToken = auth.token!;
      expect(
        await auth.refreshUser(
          AppUser.fromJson(user(1, name: 'Edited current user')),
          expectedToken: originalToken,
        ),
        isTrue,
      );
      expect(
        (jsonDecode(stored['flutter.smartflow_user']! as String)
            as Map)['name'],
        'Edited current user',
      );
      expect(
        await auth.refreshUser(
          AppUser.fromJson(user(2)),
          expectedToken: originalToken,
        ),
        isFalse,
      );
      await auth.login('synthetic1', 'synthetic-password');
      expect(
        await auth.refreshUser(
          AppUser.fromJson(user(1)),
          expectedToken: originalToken,
        ),
        isFalse,
      );
      final currentToken = auth.token!;
      await auth.logout();
      expect(
        await auth.refreshUser(
          AppUser.fromJson(user(1)),
          expectedToken: currentToken,
        ),
        isFalse,
      );
      expect(stored, isEmpty);
    },
  );

  test(
    'successful profile response stays current when overlapping logout fails',
    () async {
      final logout = Completer<http.Response>();
      final auth = authWith(
        (request) async => request.url.path.endsWith('auth-logout.php')
            ? logout.future
            : ok({}),
      );
      addTearDown(auth.dispose);
      await auth.login('synthetic1', 'synthetic-password');
      final token = auth.token!;
      final ending = auth.logout();
      expect(auth.loggingOut, isTrue);
      expect(
        await auth.refreshUser(
          AppUser.fromJson(user(1, name: 'Saved during logout')),
          expectedToken: token,
        ),
        isTrue,
      );
      final rejected = expectLater(ending, throwsA(isA<ApiException>()));
      logout.complete(
        http.Response(
          '{"success":false,"message":"Synthetic logout unavailable"}',
          503,
        ),
      );
      await rejected;
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user!.name, 'Saved during logout');
      expect(
        (jsonDecode(stored['flutter.smartflow_user']! as String)
            as Map)['name'],
        'Saved during logout',
      );
      expect(stored['flutter.smartflow_token'], token);
    },
  );

  for (final clearing in [false, true]) {
    test(
      'new login is persisted after an already-running ${clearing ? 'clear' : 'profile write'}',
      () async {
        final auth = authWith(null);
        addTearDown(auth.dispose);
        await auth.login('synthetic1', 'synthetic-password');
        final token = auth.token!;
        final started = Completer<void>();
        final release = Completer<void>();
        beforeWrite = (call) async {
          final args = call.arguments as Map;
          final shouldHold = clearing
              ? call.method == 'remove' &&
                    args['key'] == 'flutter.smartflow_token'
              : call.method == 'setString' &&
                    args['key'] == 'flutter.smartflow_user';
          if (shouldHold && !started.isCompleted) {
            started.complete();
            await release.future;
          }
        };
        final oldWrite = clearing
            ? auth.endSession(token)
            : auth.refreshUser(
                AppUser.fromJson(user(1, name: 'Old pending edit')),
                expectedToken: token,
              );
        await started.future;
        final newerLogin = auth.login('synthetic2', 'synthetic-password');
        await Future<void>.delayed(Duration.zero);
        expect(
          auth.user?.id,
          clearing ? isNull : 1,
          reason:
              'A queued candidate must not replace the committed identity before its saved pair completes.',
        );
        release.complete();
        await oldWrite;
        await newerLogin;
        expect(stored['flutter.smartflow_token'], auth.token);
        expect(
          (jsonDecode(stored['flutter.smartflow_user']! as String)
              as Map)['id'],
          2,
        );
      },
    );
  }

  for (final changedLogin in [false, true]) {
    testWidgets(
      'dismissed profile response ${changedLogin ? 'cannot change new login' : 'still updates its current account'}',
      (tester) async {
        final response = Completer<http.Response>();
        final auth = authWith(
          (request) async =>
              request.url.path.endsWith('users-profile-update.php')
              ? response.future
              : ok({}),
        );
        await auth.login('synthetic1', 'synthetic-password');
        final router = await mount(tester, auth, const EditProfileSheet());
        await tester.tap(find.text('Save profile'));
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        if (changedLogin) {
          await auth.logout();
          await auth.login('synthetic2', 'synthetic-password');
        }
        response.complete(
          ok({'user': user(1, name: 'Saved original profile')}),
        );
        await tester.pumpAndSettle();
        expect(auth.user!.id, changedLogin ? 2 : 1);
        expect(
          auth.user!.name,
          changedLogin ? 'Synthetic 2' : 'Saved original profile',
        );
        expect(
          (jsonDecode(stored['flutter.smartflow_user']! as String)
              as Map)['id'],
          changedLogin ? 2 : 1,
        );
        expect(stored['flutter.smartflow_token'], auth.token);
        expect(tester.takeException(), isNull);
        auth.dispose();
      },
    );
  }

  testWidgets('a form opened by A cannot dispatch its values using B login', (
    tester,
  ) async {
    var writes = 0;
    final auth = authWith((_) async {
      writes++;
      return ok({});
    });
    await auth.login('synthetic1', 'synthetic-password');
    final router = await mount(tester, auth, const EditProfileSheet());
    await auth.login('synthetic2', 'synthetic-password');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(
      find.text('Your sign-in changed. Close and reopen this form.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
  });

  testWidgets(
    'pending avatar removal cannot apply identity or feedback to a newer login',
    (tester) async {
      final response = Completer<http.Response>();
      final auth = authWith(
        (request) async => request.url.path.endsWith('users-avatar-upload.php')
            ? response.future
            : ok({}),
      );
      await auth.login('synthetic1', 'synthetic-password');
      final router = await mount(
        tester,
        auth,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(sfRemoveProfilePhoto(context)),
            child: const Text('Remove photo'),
          ),
        ),
      );
      await tester.tap(find.text('Remove photo'));
      await tester.pump();
      await auth.login('synthetic2', 'synthetic-password');
      response.complete(ok({'user': user(1), 'message': 'Old photo removed'}));
      await tester.pumpAndSettle();
      expect(auth.user!.id, 2);
      expect(find.text('Old photo removed'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
    },
  );

  testWidgets(
    'changing login while photo picker is open prevents upload dispatch',
    (tester) async {
      final selected = Completer<String>();
      var pickerOpened = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker, (_) {
            pickerOpened = true;
            return selected.future;
          });
      var writes = 0;
      final auth = authWith((_) async {
        writes++;
        return ok({});
      });
      await auth.login('synthetic1', 'synthetic-password');
      final router = await mount(
        tester,
        auth,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(sfPickAndUploadProfilePhoto(context)),
            child: const Text('Choose photo'),
          ),
        ),
      );
      await tester.tap(find.text('Choose photo'));
      await tester.pump();
      expect(pickerOpened, isTrue);
      await auth.login('synthetic2', 'synthetic-password');
      selected.complete('synthetic-unused-photo.png');
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(auth.user!.id, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
    },
  );
}
