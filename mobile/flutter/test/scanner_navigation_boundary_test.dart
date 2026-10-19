import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/staff/scanner_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';

const id = 'DOC-2026-000721';

class TestAuth extends AuthProvider {
  TestAuth(this.clientApi);
  final SmartflowApi clientApi;
  @override
  SmartflowApi get api => clientApi;
  @override
  bool get isAuthenticated => true;
  @override
  bool get loading => false;
  @override
  AppUser get user => const AppUser(
    id: 721,
    username: 'synthetic.recovery',
    name: 'Synthetic staff',
    role: 'staff',
    officeId: 1,
    officeCode: 'ENG',
    officeName: 'Engineering Office',
  );
}

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  for (final leave in [false, true]) {
    for (final outcome in ['rejected', 'successful', 'uncertain']) {
      testWidgets(
        '${leave ? 'leaving' : 'keeping'} Scan before $outcome movement response stays lifecycle safe',
        (tester) async {
          tester.view.physicalSize = const Size(900, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final response = Completer<http.Response>();
          var posts = 0;
          final api = SmartflowApi(
            ApiClient(
              token: 'synthetic-session',
              client: MockClient((request) async {
                if (request.url.pathSegments.last == 'documents-show.php') {
                  return http.Response(
                    jsonEncode({
                      'success': true,
                      'document': {
                        'id': id,
                        'title': 'Synthetic delayed handoff',
                        'type': 'Others: Controlled folder',
                        'origin_office_name': 'Budget Office',
                        'current_status': 'OUT',
                        'current_office_id': 2,
                        'current_office_name': 'Budget Office',
                        'destination_office_id': 1,
                        'destination_office_name': 'Engineering Office',
                        'last_movement_id': 721,
                        'tray': 'incoming',
                        'folder_inventory': null,
                      },
                    }),
                    200,
                  );
                }
                if (request.url.pathSegments.last == 'movement-requests.php') {
                  return http.Response(
                    '{"success":false,"message":"Synthetic outcome unavailable"}',
                    503,
                  );
                }
                if (request.url.pathSegments.last == 'movements-create.php') {
                  posts++;
                  return response.future;
                }
                throw StateError(
                  'Unexpected mock request ${request.url.pathSegments.last}',
                );
              }),
            ),
            movementScope: '721_1',
          );
          final auth = TestAuth(api);
          final nav = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: MaterialApp(
                navigatorKey: nav,
                theme: ThemeData(platform: TargetPlatform.windows),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(body: ScannerScreen()),
                        ),
                      ),
                      child: const Text('Open Scan'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open Scan'));
          await frames(tester);
          await tester.enterText(find.byType(TextField), id);
          await tester.tap(find.text('Look up document'));
          await frames(tester);
          await tester.ensureVisible(find.text('Receive (IN)'));
          await tester.tap(find.text('Receive (IN)'));
          await frames(tester);
          await tester.tap(find.byType(CheckboxListTile));
          await frames(tester);
          await tester.tap(find.text('Confirm receipt'));
          await frames(tester);
          expect(posts, 1);
          // A normal system Back is available while the write is pending.
          if (leave) {
            nav.currentState!.pop();
            await frames(tester);
            expect(find.text('Open Scan'), findsOneWidget);
            expect(find.byType(ScannerScreen), findsNothing);
          }
          response.complete(
            http.Response(
              jsonEncode(
                outcome == 'successful'
                    ? {
                        'success': true,
                        'message': 'Movement recorded',
                        'movement_id': 722,
                      }
                    : {
                        'success': false,
                        'message': 'The document moved since you opened it',
                        'scan_error': 'document_changed',
                      },
              ),
              outcome == 'successful'
                  ? 201
                  : outcome == 'uncertain'
                  ? 503
                  : 409,
            ),
          );
          await frames(tester);
          expect(
            await api.pendingMovement(),
            outcome == 'uncertain' ? isNotNull : isNull,
          );
          expect(
            posts,
            1,
            reason:
                'Leaving a page or checking an uncertain result never repeats the custody write.',
          );
          expect(
            tester.takeException(),
            isNull,
            reason:
                'A completed/rejected handoff must not update a disposed Scan widget.',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          auth.dispose();
        },
        variant: TargetPlatformVariant({TargetPlatform.windows}),
      );
    }
  }
}
