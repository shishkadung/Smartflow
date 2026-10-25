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
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/router.dart';
import 'package:smartflow/widgets/sf_widgets.dart';
import 'package:smartflow/screens/shared/change_password_sheet.dart';
import 'package:smartflow/widgets/creation_recovery.dart';

const _preferences = MethodChannel('plugins.flutter.io/shared_preferences');
const _folder = 'DOC-2026-000851';
Map<String, dynamic> _user(int id, {String role = 'admin'}) => {
  'id': id,
  'username': 'staging$id',
  'name': 'Synthetic staging $id',
  'role': role,
  'office_id': 1,
  'office_code': 'ENG',
  'office_name': 'Engineering Office',
};
http.Response _ok(Map<String, dynamic> body) =>
    http.Response(jsonEncode({'success': true, ...body}), 200);
Future<void> _frames(WidgetTester tester, {int count = 6}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late Map<String, Object> stored;
  Future<void> Function(MethodCall)? beforeWrite;
  bool Function(MethodCall)? acceptWrite;
  setUp(() {
    SharedPreferences.resetStatic();
    stored = {
      'flutter.sf_role_tip_seen_v2_staging1': true,
      'flutter.sf_role_tip_seen_v2_staging2': true,
    };
    beforeWrite = null;
    acceptWrite = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_preferences, (call) async {
          if (call.method == 'getAll') return Map<String, Object>.from(stored);
          await beforeWrite?.call(call);
          if (acceptWrite?.call(call) == false) return false;
          final args = call.arguments as Map;
          if (call.method == 'remove') {
            stored.remove(args['key']);
          } else {
            stored[args['key'] as String] = args['value'] as Object;
          }
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_preferences, null),
  );

  for (final initialLogin in [false, true]) {
    test(
      'false token write attempts both halves, restores ${initialLogin ? 'committed identity' : 'signed-out storage'} and permits a later login',
      () async {
        final calls = <String>[];
        final auth = AuthProvider(
          httpClient: MockClient((request) async {
            final id = int.parse(
              (jsonDecode(request.body)['username'] as String).replaceFirst(
                'staging',
                '',
              ),
            );
            return _ok({'token': 'staging-token-$id', 'user': _user(id)});
          }),
        );
        addTearDown(auth.dispose);
        if (initialLogin) await auth.login('staging1', 'synthetic-password');
        acceptWrite = (call) {
          final args = call.arguments as Map;
          calls.add('${call.method}:${args['key']}');
          return !(call.method == 'setString' &&
              args['key'] == 'flutter.smartflow_token' &&
              args['value'] == 'staging-token-2');
        };
        await expectLater(
          auth.login('staging2', 'synthetic-password'),
          throwsA(isA<ApiException>()),
        );
        expect(
          calls.where((call) => call == 'setString:flutter.smartflow_user'),
          isNotEmpty,
          reason:
              'A false first preference result cannot skip the second half.',
        );
        expect(auth.user?.id, initialLogin ? 1 : isNull);
        expect(auth.token, initialLogin ? 'staging-token-1' : isNull);
        expect(
          stored['flutter.smartflow_token'],
          initialLogin ? 'staging-token-1' : isNull,
        );
        expect(
          stored['flutter.smartflow_user'] == null
              ? null
              : (jsonDecode(stored['flutter.smartflow_user']! as String)
                    as Map)['id'],
          initialLogin ? 1 : isNull,
        );
        expect(await auth.login('staging3', 'synthetic-password'), isTrue);
        expect(auth.user?.id, 3);
        expect(stored['flutter.smartflow_token'], 'staging-token-3');
        expect(
          (jsonDecode(stored['flutter.smartflow_user']! as String)
              as Map)['id'],
          3,
        );
      },
    );
  }

  for (final initialLogin in [false, true]) {
    test(
      'two cancelled overlapping candidate writes preserve ${initialLogin ? 'the committed account' : 'signed-out state'}',
      () async {
        final started = Completer<void>();
        final release = Completer<void>();
        final auth = AuthProvider(
          httpClient: MockClient((request) async {
            final id = int.parse(
              (jsonDecode(request.body)['username'] as String).replaceFirst(
                'staging',
                '',
              ),
            );
            return _ok({'token': 'staging-token-$id', 'user': _user(id)});
          }),
        );
        addTearDown(auth.dispose);
        if (initialLogin) await auth.login('staging3', 'synthetic-password');
        beforeWrite = (call) async {
          final args = call.arguments as Map;
          if (call.method == 'setString' &&
              args['key'] == 'flutter.smartflow_token' &&
              args['value'] == 'staging-token-1' &&
              !started.isCompleted) {
            started.complete();
            await release.future;
          }
        };
        final ownerA = auth.beginLoginAttempt();
        final candidateA = auth.login(
          'staging1',
          'synthetic-password',
          attempt: ownerA,
        );
        await started.future;
        final ownerB = auth.beginLoginAttempt();
        final candidateB = auth.login(
          'staging2',
          'synthetic-password',
          attempt: ownerB,
        );
        await Future<void>.delayed(Duration.zero);
        auth.cancelLoginAttempt(ownerA);
        auth.cancelLoginAttempt(ownerB);
        release.complete();
        expect(await candidateA, isFalse);
        expect(await candidateB, isFalse);
        expect(auth.user?.id, initialLogin ? 3 : isNull);
        expect(auth.token, initialLogin ? 'staging-token-3' : isNull);
        expect(
          stored['flutter.smartflow_token'],
          initialLogin ? 'staging-token-3' : isNull,
        );
        final raw = stored['flutter.smartflow_user'];
        expect(
          raw == null ? null : (jsonDecode(raw as String) as Map)['id'],
          initialLogin ? 3 : isNull,
        );
      },
    );
  }

  Future<(AuthProvider, GoRouter, List<String>)> mount(
    WidgetTester tester, {
    String role = 'admin',
    String route = '/admin/users',
    Widget? screen,
    Future<http.Response> Function(http.Request)? extra,
    Future<http.Response?> Function(http.Request)? intercept,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final writes = <String>[];
    final auth = AuthProvider(
      httpClient: MockClient((request) async {
        final intercepted = await intercept?.call(request);
        if (intercepted != null) return intercepted;
        final endpoint = request.url.pathSegments.last;
        switch (endpoint) {
          case 'auth-login.php':
            final id = jsonDecode(request.body)['username'] == 'staging2'
                ? 2
                : 1;
            return _ok({
              'token': 'staging-token-$id',
              'user': _user(id, role: role),
            });
          case 'users-list.php':
            return _ok({
              'users': [
                {
                  'id': 9,
                  'username': 'synthetic-target',
                  'name': 'Synthetic target',
                  'role': 'staff',
                  'office_code': 'ENG',
                  'office_name': 'Engineering Office',
                  'is_active': true,
                },
              ],
            });
          case 'signup-pending-list.php':
            return _ok({
              'pending': [
                {
                  'id': 51,
                  'username': 'synthetic-applicant',
                  'name': 'Synthetic applicant',
                  'requested_role': 'staff',
                  'office_code': 'ENG',
                  'office_name': 'Engineering Office',
                },
              ],
            });
          case 'signup-approve.php':
          case 'users-set-active.php':
          case 'document-requests-create.php':
          case 'movements-create.php':
          case 'documents-create.php':
          case 'folder-checklists.php' when request.method == 'POST':
          case 'users-change-password.php':
          case 'admin-thresholds-update.php':
            writes.add('$endpoint:${request.headers['Authorization']}');
            return _ok({
              'movement_id': 852,
              'message': 'Synthetic action saved',
              'document': {
                'id': _folder,
                'title': 'Synthetic registered folder',
                'type': 'Disbursement Voucher',
                'qr_payload': _folder,
              },
            });
          case 'folder-checklists.php':
            return _ok({
              'checklists': [
                {
                  'id': 71,
                  'name': 'Synthetic supporting requirements',
                  'document_type': 'Disbursement Voucher',
                  'items': [
                    {'name': 'Supporting document', 'required': true},
                  ],
                },
              ],
            });
          case 'documents-find-by-reference.php':
            return _ok({
              'matches': [
                {
                  'id': _folder,
                  'type': 'Disbursement Voucher',
                  'origin_office_code': 'ENG',
                },
              ],
            });
          case 'admin-offices.php':
            return _ok({
              'offices': [
                {
                  'office_id': 1,
                  'office_code': 'ENG',
                  'office_name': 'Engineering Office',
                  'thresholds': [
                    {
                      'document_type': 'Disbursement Voucher',
                      'max_hours': 48,
                      'out_unconfirmed_hours': 24,
                    },
                  ],
                },
              ],
            });
          case 'accountant-dashboard.php':
            return _ok({
              'stats': {'pending_signups': 1},
            });
          case 'document-requests-summary.php':
            return _ok({'pending_inbox_count': 0});
          case 'alerts-list.php':
            return _ok({'alerts': []});
          case 'document-requests-list.php':
            return _ok({
              'requests': [],
              'total': 0,
              'has_more': false,
              'page': 1,
              'page_size': 25,
              'counts': {'total': 0, 'active': 0, 'past': 0, 'overdue': 0},
            });
          case 'offices-list.php':
            return _ok({
              'offices': [
                {'id': 1, 'code': 'ENG', 'name': 'Engineering Office'},
                {'id': 2, 'code': 'BUD', 'name': 'Budget Office'},
              ],
            });
          case 'documents-show.php':
            return _ok({
              'document': {
                'id': _folder,
                'title': 'Synthetic toast folder',
                'type': 'Others: Controlled folder',
                'current_status': 'OUT',
                'current_office_id': 2,
                'current_office_name': 'Budget Office',
                'destination_office_id': 1,
                'destination_office_name': 'Engineering Office',
                'last_movement_id': 851,
                'folder_inventory': null,
              },
            });
          case 'office-documents.php':
            return _ok({
              'documents': [],
              'total': 0,
              'has_more': false,
              'tray_counts': {},
              'overdue_count': 0,
            });
          default:
            if (extra != null) return extra(request);
            throw StateError('Unexpected synthetic endpoint $endpoint');
        }
      }),
    );
    await auth.bootstrap();
    await auth.login('staging1', 'synthetic-password');
    final router = screen == null
        ? createRouter(auth)
        : GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(body: screen),
              ),
            ],
          );
    router.go(screen == null ? route : '/');
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(platform: TargetPlatform.windows),
        ),
      ),
    );
    await _frames(tester);
    return (auth, router, writes);
  }

  Future<void> cleanup(
    WidgetTester tester,
    AuthProvider auth,
    GoRouter router,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
  }

  Future<void> openAdminConfirmation(
    WidgetTester tester,
    bool activation,
  ) async {
    final label = activation ? 'Deactivate' : 'Approve';
    await tester.ensureVisible(find.text(label).first);
    await tester.tap(find.text(label).first);
    await _frames(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  for (final activation in [false, true]) {
    testWidgets(
      '${activation ? 'activation' : 'signup'} old confirmation uses committed A while B preferences are pending',
      (tester) async {
        final (auth, router, writes) = await mount(tester);
        await openAdminConfirmation(tester, activation);
        final writing = Completer<void>();
        final release = Completer<void>();
        beforeWrite = (call) async {
          final args = call.arguments as Map;
          if (call.method == 'setString' &&
              args['key'] == 'flutter.smartflow_token' &&
              args['value'] == 'staging-token-2') {
            writing.complete();
            await release.future;
          }
        };
        final candidate = auth.login('staging2', 'synthetic-password');
        await tester.pump();
        await writing.future;
        expect(
          auth.user?.id,
          1,
          reason:
              'An uncommitted login cannot become the identity used by mounted protected forms.',
        );
        final confirm = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        );
        await tester.tap(confirm);
        await _frames(tester);
        expect(writes.single, endsWith('Bearer staging-token-1'));
        release.complete();
        expect(await candidate, isTrue);
        await _frames(tester);
        await cleanup(tester, auth, router);
      },
      variant: TargetPlatformVariant({TargetPlatform.windows}),
    );

    testWidgets(
      '${activation ? 'activation' : 'signup'} queued old confirmation cannot write after B commits before a frame',
      (tester) async {
        final (auth, router, writes) = await mount(tester);
        await openAdminConfirmation(tester, activation);
        final oldConfirm = tester.widget<FilledButton>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await auth.login('staging2', 'synthetic-password');
        oldConfirm.onPressed!();
        await _frames(tester);
        expect(writes, isEmpty);
        expect(tester.takeException(), isNull);
        await cleanup(tester, auth, router);
      },
      variant: TargetPlatformVariant({TargetPlatform.windows}),
    );
  }

  for (final queued in [false, true]) {
    testWidgets(
      'nested Requests creation sheet ${queued ? 'queued callback is guarded before a frame' : 'closes on same-role replacement'}',
      (tester) async {
        final (auth, router, writes) = await mount(
          tester,
          role: 'staff',
          route: '/staff/requests',
        );
        await tester.tap(find.text('New request'));
        await _frames(tester);
        expect(find.text('New document request'), findsOneWidget);
        final oldSheet = tester.state(find.byType(BottomSheet));
        final nestedNavigator = Navigator.of(
          tester.element(find.text('New document request')),
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Purpose',
          ),
          'Synthetic original-user draft',
        );
        final submit = tester.widget<SfPrimaryButton>(
          find.widgetWithText(SfPrimaryButton, 'Submit request'),
        );
        await auth.login('staging2', 'synthetic-password');
        if (queued) submit.onPressed!();
        Future<void>? fresh;
        if (!queued) {
          fresh = showModalBottomSheet<void>(
            context: nestedNavigator.context,
            builder: (_) => const Text('Current nested popup'),
          );
        }
        await _frames(tester);
        expect(oldSheet.mounted, isFalse);
        expect(find.text('New document request'), findsNothing);
        if (fresh != null) {
          expect(find.text('Current nested popup'), findsOneWidget);
          nestedNavigator.pop();
          await fresh;
          await _frames(tester);
        }
        expect(writes, isEmpty);
        expect(tester.takeException(), isNull);
        await cleanup(tester, auth, router);
      },
      variant: TargetPlatformVariant({TargetPlatform.windows}),
    );
  }

  testWidgets(
    'saved Scan snackbar action stays safe after changing the persistent shell page',
    (tester) async {
      final (auth, router, writes) = await mount(
        tester,
        role: 'staff',
        route: '/staff/scan',
      );
      await tester.enterText(find.byType(TextField), _folder);
      await tester.tap(find.text('Look up document'));
      await _frames(tester, count: 2);
      await tester.ensureVisible(find.text('Receive (IN)'));
      await tester.tap(find.text('Receive (IN)'));
      await _frames(tester, count: 2);
      await tester.tap(find.byType(CheckboxListTile));
      await _frames(tester, count: 2);
      await tester.tap(find.text('Confirm receipt'));
      await _frames(tester, count: 2);
      expect(writes.length, 1);
      expect(find.text('Scan another'), findsOneWidget);
      router.go('/staff/documents');
      await _frames(tester, count: 6);
      expect(find.text('Scan another'), findsOneWidget);
      await tester.tap(find.text('Scan another'));
      await _frames(tester, count: 2);
      expect(tester.takeException(), isNull);
      expect(writes.length, 1);
      await cleanup(tester, auth, router);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  for (final changed in [false, true]) {
    for (final caller in [
      'registration',
      'checklist publish',
      'checklist archive',
      'password',
      'threshold',
    ]) {
      testWidgets(
        '$caller reviewed callback ${changed ? 'rejects replacement login before a frame' : 'succeeds in its original session'}',
        (tester) async {
          final role = caller == 'registration' ? 'staff' : 'admin';
          final route = switch (caller) {
            'registration' => '/staff/register',
            'threshold' => '/admin/thresholds',
            _ => '/admin/checklists',
          };
          final (auth, router, writes) = await mount(
            tester,
            role: role,
            route: route,
            screen: caller == 'password'
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () => ChangePasswordSheet.show(context),
                      child: const Text('Open password sheet'),
                    ),
                  )
                : null,
          );
          late VoidCallback confirm;
          if (caller == 'registration') {
            await tester.enterText(
              find.byType(TextField).first,
              'Synthetic original-office folder',
            );
            await tester.enterText(
              field('Reference / DV no. (required)'),
              'Synthetic-reference',
            );
            await tester.enterText(
              field('Payee (required)'),
              'Synthetic payee',
            );
            await tester.enterText(
              field('Fund source (required)'),
              'Synthetic fund',
            );
            await tester.enterText(field('Main document pages'), '5');
            await tester.ensureVisible(find.byType(CheckboxListTile));
            await tester.tap(find.byType(CheckboxListTile));
            final register = find.widgetWithText(
              SfPrimaryButton,
              'Register folder',
            );
            await tester.ensureVisible(register);
            await tester.pumpAndSettle();
            expect(register.hitTestable(), findsOneWidget);
            await tester.tap(register);
            await _frames(tester);
            expect(find.text('Reference already used'), findsOneWidget);
            confirm = tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Register anyway'),
                )
                .onPressed!;
          } else if (caller.startsWith('checklist')) {
            if (caller.endsWith('publish')) {
              final use = find.text('Use Synthetic supporting requirements');
              await tester.ensureVisible(use);
              await tester.tap(use);
              await _frames(tester);
              final publish = find.text('Publish attachments as checklist');
              await tester.ensureVisible(publish);
              await tester.tap(publish);
              await _frames(tester);
              await tester.enterText(
                field('Checklist name'),
                'Synthetic published requirements',
              );
              confirm = tester
                  .widget<TextButton>(
                    find.widgetWithText(TextButton, 'Publish'),
                  )
                  .onPressed!;
            } else {
              final archive = find.byTooltip('Archive checklist');
              await tester.ensureVisible(archive);
              await tester.tap(archive);
              await _frames(tester);
              confirm = tester
                  .widget<TextButton>(
                    find.widgetWithText(TextButton, 'Archive'),
                  )
                  .onPressed!;
            }
          } else if (caller == 'password') {
            await tester.tap(find.text('Open password sheet'));
            await _frames(tester);
            await tester.enterText(
              find.byType(TextField).at(0),
              'synthetic-old-password',
            );
            await tester.enterText(
              find.byType(TextField).at(1),
              'synthetic-new-password',
            );
            await tester.enterText(
              find.byType(TextField).at(2),
              'synthetic-new-password',
            );
            confirm = tester
                .widget<SfPrimaryButton>(
                  find.widgetWithText(SfPrimaryButton, 'Save new password'),
                )
                .onPressed!;
          } else {
            confirm = tester
                .widget<SfPrimaryButton>(
                  find.widgetWithText(SfPrimaryButton, 'Save time limits'),
                )
                .onPressed!;
          }
          if (changed) await auth.login('staging2', 'synthetic-password');
          confirm();
          await _frames(tester);
          if (changed) {
            expect(writes, isEmpty);
            expect(auth.user?.id, 2);
          } else {
            expect(writes, hasLength(1));
            expect(writes.single, endsWith('Bearer staging-token-1'));
          }
          expect(tester.takeException(), isNull);
          await cleanup(tester, auth, router);
        },
        variant: TargetPlatformVariant({TargetPlatform.windows}),
      );
    }
  }

  for (final successful in [false, true]) {
    testWidgets(
      'a dispatched threshold ${successful ? 'save' : 'rejection'} settles while same-login logout is pending and fails',
      (tester) async {
        final action = Completer<http.Response>();
        final logout = Completer<http.Response>();
        var posts = 0;
        final (auth, router, _) = await mount(
          tester,
          route: '/admin/thresholds',
          intercept: (request) async {
            if (request.url.pathSegments.last == 'auth-logout.php') {
              return logout.future;
            }
            if (request.url.pathSegments.last ==
                'admin-thresholds-update.php') {
              posts++;
              return action.future;
            }
            return null;
          },
        );
        final save = find.widgetWithText(SfPrimaryButton, 'Save time limits');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await _frames(tester);
        expect(posts, 1);
        final ending = auth.logout().then<void>((_) {}, onError: (Object _) {});
        await _frames(tester);
        expect(auth.loggingOut, isTrue);
        action.complete(
          successful
              ? _ok({'message': 'Synthetic time limits saved'})
              : http.Response(
                  '{"success":false,"message":"Synthetic save rejected"}',
                  409,
                ),
        );
        await _frames(tester);
        logout.complete(
          http.Response(
            '{"success":false,"message":"Synthetic logout unavailable"}',
            503,
          ),
        );
        await ending;
        await _frames(tester);
        expect(auth.user?.id, 1);
        expect(auth.loggingOut, isFalse);
        expect(
          tester.widget<SfPrimaryButton>(save).onPressed,
          isNotNull,
          reason:
              'A settled write cannot leave the same account permanently busy after failed logout.',
        );
        if (successful) {
          expect(find.text('Alert time limits saved'), findsOneWidget);
        } else {
          expect(find.text('Synthetic save rejected'), findsOneWidget);
        }
        expect(
          posts,
          1,
          reason: 'Settling a prior action never reissues the write.',
        );
        expect(tester.takeException(), isNull);
        await cleanup(tester, auth, router);
      },
      variant: TargetPlatformVariant({TargetPlatform.windows}),
    );
  }

  testWidgets(
    'creation recovery never retries a saved original operation after its login changes during the outcome read',
    (tester) async {
      final operation = 'a' * 32;
      const key = 'flutter.sf_creation_v1_1_1_request';
      stored[key] = jsonEncode({
        'id': operation,
        'body': {'purpose': 'Synthetic original recovery'},
      });
      final checked = Completer<http.Response>();
      var checks = 0;
      var recovered = 0;
      final (auth, router, writes) = await mount(
        tester,
        role: 'staff',
        screen: CreationRecoveryPanel(
          kind: 'request',
          onRecovered: (_) => recovered++,
        ),
        extra: (request) async {
          expect(request.url.pathSegments.last, 'creation-requests.php');
          expect(request.headers['Authorization'], 'Bearer staging-token-1');
          expect(request.url.queryParameters['operation_id'], operation);
          checks++;
          return checked.future;
        },
      );
      await tester.tap(find.text('Retry saved submission'));
      await tester.pump();
      expect(checks, 1);
      await auth.login('staging2', 'synthetic-password');
      checked.complete(_ok({'state': 'not_found'}));
      await _frames(tester);
      expect(writes, isEmpty);
      expect(recovered, 0);
      expect((jsonDecode(stored[key]! as String) as Map)['id'], operation);
      expect(auth.user?.id, 2);
      expect(tester.takeException(), isNull);
      await cleanup(tester, auth, router);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
}
