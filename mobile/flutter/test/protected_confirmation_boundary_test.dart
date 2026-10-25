import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/screens/staff/scanner_screen.dart';
import 'package:smartflow/screens/shared/documents_screen.dart';
import 'package:smartflow/router.dart';

const folderId = 'DOC-2026-000731';
Map<String, dynamic> user(int id) => {
  'id': id,
  'username': 'synthetic$id',
  'name': 'Synthetic staff $id',
  'role': 'staff',
  'office_id': 1,
  'office_name': 'Engineering Office',
  'office_code': 'ENG',
};
Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'sf_role_tip_seen_v2_synthetic1': true,
      'sf_role_tip_seen_v2_synthetic2': true,
    });
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  for (final endFirst in [true, false]) {
    testWidgets(
      '${endFirst ? 'ended session' : 'in-place login replacement'} invalidates an old Scan receipt confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final writes = <Map<String, dynamic>>[];
        http.Response ok(Map<String, dynamic> body) =>
            http.Response(jsonEncode({'success': true, ...body}), 200);
        final auth = AuthProvider(
          httpClient: MockClient((request) async {
            final endpoint = request.url.pathSegments.last;
            switch (endpoint) {
              case 'auth-login.php':
                final id = jsonDecode(request.body)['username'] == 'synthetic2'
                    ? 2
                    : 1;
                return ok({'token': 'synthetic$id-session', 'user': user(id)});
              case 'auth-session.php':
                return ok({'user': user(1)});
              case 'documents-show.php':
                return ok({
                  'document': {
                    'id': folderId,
                    'title': 'Synthetic reviewed folder A',
                    'type': 'Others: Controlled folder',
                    'origin_office_name': 'Budget Office',
                    'current_status': 'OUT',
                    'current_office_id': 2,
                    'current_office_name': 'Budget Office',
                    'destination_office_id': 1,
                    'destination_office_name': 'Engineering Office',
                    'last_movement_id': 731,
                    'tray': 'incoming',
                    'folder_inventory': null,
                  },
                });
              case 'movements-create.php':
                writes.add({
                  'authorization': request.headers['Authorization'],
                  'body': jsonDecode(request.body),
                });
                return ok({
                  'message': 'Synthetic movement recorded',
                  'movement_id': 732,
                });
              case 'dashboard-stats.php':
                return ok({
                  'stats': {'in_flow': 0, 'out_flow': 0, 'active_tags': 0},
                  'active_documents': [],
                  'in_transit': [],
                  'recent_movements': [],
                });
              case 'document-requests-summary.php':
                return ok({'pending_inbox_count': 0});
              case 'alerts.php':
                return ok({'alerts': []});
              default:
                throw StateError('Unexpected mock endpoint $endpoint');
            }
          }),
        );
        await auth.bootstrap();
        await auth.login('synthetic1', 'synthetic-password');
        final tokenA = auth.token!;
        final router = createRouter(auth);
        router.go('/staff/scan');
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp.router(
              routerConfig: router,
              theme: ThemeData(platform: TargetPlatform.windows),
            ),
          ),
        );
        await frames(tester);
        await tester.enterText(find.byType(TextField), folderId);
        await tester.tap(find.text('Look up document'));
        await frames(tester);
        await tester.ensureVisible(find.text('Receive (IN)'));
        await tester.tap(find.text('Receive (IN)'));
        await frames(tester);
        expect(find.text('Check folder contents'), findsOneWidget);
        if (endFirst) {
          await auth.endSession(tokenA, message: 'Synthetic session ended');
          await frames(tester);
        }
        // Direct replacement models the already-confirmed abandoned login response.
        await auth.login('synthetic2', 'synthetic-password');
        await frames(tester);
        expect(auth.user?.id, 2);
        expect(find.text('Check folder contents'), findsNothing);
        if (find.text('Check folder contents').evaluate().isNotEmpty) {
          await tester.tap(find.byType(CheckboxListTile));
          await frames(tester);
          await tester.tap(find.text('Confirm receipt'));
          await frames(tester);
        }
        final captured = List<Map<String, dynamic>>.from(writes);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        auth.dispose();
        expect(
          captured,
          isEmpty,
          reason:
              'An old folder confirmation must not dispatch under the replacement login. Captured synthetic request: $captured',
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.windows}),
    );
  }

  for (final scan in [true, false]) {
    for (final action in ['receipt', 'send', 'file', 'correction']) {
      for (final sameAccount in [true, false]) {
        testWidgets(
          '${scan ? 'Scan' : 'Documents'} $action root dialog closes on ${sameAccount ? 'same-account new token' : 'same-office replacement user'}',
          (tester) async {
            tester.view.physicalSize = const Size(900, 1800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final writes = <String>[];
            var sequence = 0;
            final incoming = action == 'receipt';
            final correction = action == 'correction';
            final document = {
              'id': folderId,
              'title': 'Synthetic reviewed folder',
              'type': 'Others: Controlled folder',
              'origin_office_name': 'Budget Office',
              'current_status': incoming || correction ? 'OUT' : 'IN',
              'current_office_id': incoming ? 2 : 1,
              'current_office_name': incoming
                  ? 'Budget Office'
                  : 'Engineering Office',
              'destination_office_id': incoming ? 1 : 2,
              'destination_office_name': incoming
                  ? 'Engineering Office'
                  : 'Budget Office',
              'last_movement_id': 731,
              'tray': incoming
                  ? 'incoming'
                  : correction
                  ? 'forwarded'
                  : 'in_office',
              'folder_inventory': null,
              'journey': [],
              'can_file': action == 'file',
              'can_correct_destination': correction,
              'suggested_forward': {
                'office_id': 2,
                'office_code': 'BUD',
                'office_name': 'Budget Office',
                'reason': 'Reviewed suggestion',
              },
            };
            http.Response ok(Map<String, dynamic> body) =>
                http.Response(jsonEncode({'success': true, ...body}), 200);
            final auth = AuthProvider(
              httpClient: MockClient((request) async {
                final endpoint = request.url.pathSegments.last;
                switch (endpoint) {
                  case 'auth-login.php':
                    final id =
                        jsonDecode(request.body)['username'] == 'synthetic2'
                        ? 2
                        : 1;
                    return ok({
                      'token': 'synthetic-login-${++sequence}',
                      'user': user(id),
                    });
                  case 'documents-show.php':
                  case 'office-documents.php':
                    return ok({'document': document});
                  case 'offices-list.php':
                    return ok({
                      'offices': [
                        {'id': 1, 'code': 'ENG', 'name': 'Engineering Office'},
                        {'id': 2, 'code': 'BUD', 'name': 'Budget Office'},
                        {'id': 3, 'code': 'ACC', 'name': 'Accounting Office'},
                      ],
                    });
                  case 'movements-create.php':
                  case 'documents-file.php':
                  case 'movements-correct-destination.php':
                    writes.add(endpoint);
                    return ok({
                      'message': 'Saved synthetic action',
                      'movement_id': 732,
                    });
                  case 'alerts-list.php':
                    return ok({'alerts': []});
                  case 'document-requests-summary.php':
                    return ok({'pending_inbox_count': 0});
                  default:
                    throw StateError('Unexpected synthetic endpoint $endpoint');
                }
              }),
            );
            await auth.bootstrap();
            await auth.login('synthetic1', 'synthetic-password');
            final router = createRouter(auth);
            router.go(scan ? '/staff/scan' : '/staff/documents?id=$folderId');
            await tester.pumpWidget(
              ChangeNotifierProvider<AuthProvider>.value(
                value: auth,
                child: MaterialApp.router(
                  routerConfig: router,
                  theme: ThemeData(platform: TargetPlatform.windows),
                ),
              ),
            );
            await frames(tester);
            if (scan) {
              await tester.enterText(find.byType(TextField), folderId);
              await tester.tap(find.text('Look up document'));
              await frames(tester);
            }
            final label = switch (action) {
              'receipt' => 'Receive (IN)',
              'send' => 'Send (OUT)',
              'file' => 'File this folder',
              _ => 'Correct recorded destination',
            };
            await tester.ensureVisible(find.text(label));
            await tester.tap(find.text(label));
            await frames(tester);
            expect(find.byType(AlertDialog), findsOneWidget);
            final rootNavigator = Navigator.of(
              tester.element(find.byType(AlertDialog)),
              rootNavigator: true,
            );
            final oldScreen = tester.state(
              find.byType(scan ? ScannerScreen : DocumentsScreen),
            );
            await auth.login(
              sameAccount ? 'synthetic1' : 'synthetic2',
              'synthetic-password',
            );
            Future<void>? currentDialog;
            if (scan && action == 'receipt' && sameAccount) {
              currentDialog = showDialog<void>(
                context: rootNavigator.context,
                builder: (_) =>
                    const AlertDialog(title: Text('Current login dialog')),
              );
            }
            await frames(tester);
            if (currentDialog != null) {
              expect(find.text('Current login dialog'), findsOneWidget);
              expect(find.text('Check folder contents'), findsNothing);
              rootNavigator.pop();
              await currentDialog;
              await frames(tester);
            }
            expect(find.byType(AlertDialog), findsNothing);
            expect(oldScreen.mounted, isFalse);
            expect(writes, isEmpty);
            expect(auth.user?.id, sameAccount ? 1 : 2);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            router.dispose();
            auth.dispose();
          },
          variant: TargetPlatformVariant({TargetPlatform.windows}),
        );
      }
    }
  }

  testWidgets(
    'same-token profile refresh retains Scan workspace and root receipt confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      http.Response ok(Map<String, dynamic> body) =>
          http.Response(jsonEncode({'success': true, ...body}), 200);
      final auth = AuthProvider(
        httpClient: MockClient((request) async {
          switch (request.url.pathSegments.last) {
            case 'auth-login.php':
              return ok({'token': 'synthetic-stable-login', 'user': user(1)});
            case 'documents-show.php':
              return ok({
                'document': {
                  'id': folderId,
                  'title': 'Same-session folder',
                  'type': 'Others: Controlled folder',
                  'current_status': 'OUT',
                  'current_office_id': 2,
                  'current_office_name': 'Budget Office',
                  'destination_office_id': 1,
                  'destination_office_name': 'Engineering Office',
                  'last_movement_id': 731,
                  'folder_inventory': null,
                },
              });
            case 'movements-create.php':
              writes++;
              expect(
                request.headers['Authorization'],
                'Bearer synthetic-stable-login',
              );
              expect(jsonDecode(request.body)['expected_movement_id'], 731);
              return ok({
                'movement_id': 732,
                'message': 'Synthetic receipt saved',
              });
            case 'alerts-list.php':
              return ok({'alerts': []});
            case 'document-requests-summary.php':
              return ok({'pending_inbox_count': 0});
            default:
              throw StateError(
                'Unexpected synthetic endpoint ${request.url.path}',
              );
          }
        }),
      );
      await auth.bootstrap();
      await auth.login('synthetic1', 'synthetic-password');
      final router = createRouter(auth);
      router.go('/staff/scan');
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp.router(
            routerConfig: router,
            theme: ThemeData(platform: TargetPlatform.windows),
          ),
        ),
      );
      await frames(tester);
      await tester.enterText(find.byType(TextField), folderId);
      await tester.tap(find.text('Look up document'));
      await frames(tester);
      final original = tester.state(find.byType(ScannerScreen));
      await tester.ensureVisible(find.text('Receive (IN)'));
      await tester.tap(find.text('Receive (IN)'));
      await frames(tester);
      expect(
        await auth.refreshUser(
          AppUser.fromJson({...user(1), 'name': 'Updated own profile'}),
          expectedToken: auth.token!,
        ),
        isTrue,
      );
      await frames(tester);
      expect(tester.state(find.byType(ScannerScreen)), same(original));
      expect(find.text('Check folder contents'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await frames(tester);
      await tester.tap(find.text('Confirm receipt'));
      await frames(tester);
      expect(writes, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
}
