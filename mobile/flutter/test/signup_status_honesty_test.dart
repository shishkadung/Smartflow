import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/auth/signup_screen.dart';

Future<AuthProvider> _mount(
  WidgetTester tester, {
  required Map<String, dynamic> summary,
  String code = '',
  String username = '',
  http.Response? response,
}) async {
  tester.view.physicalSize = const Size(390, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = AuthProvider(
    httpClient: MockClient((_) async => response ?? http.Response('{}', 500)),
  );
  final router = GoRouter(
    initialLocation: '/signup/pending',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login destination')),
      ),
      GoRoute(
        path: '/signup/pending',
        builder: (_, _) => SignupPendingScreen(
          requestCode: code,
          username: username,
          summary: summary,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'opening Check access request without a request never claims one is pending',
    (tester) async {
      await _mount(tester, summary: const {});
      expect(find.text('Check your access request'), findsOneWidget);
      expect(find.text('Not checked yet'), findsOneWidget);
      expect(find.text('Pending admin approval'), findsNothing);
      expect(find.textContaining('request was received'), findsNothing);
      expect(find.text('Awaiting admin'), findsNothing);
      expect(find.text('Request recorded'), findsNothing);
      expect(find.text('Pending'), findsNothing);
      expect(find.text('Employee (Clerk)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('right after submitting, the request is shown as pending', (
    tester,
  ) async {
    await _mount(
      tester,
      code: 'REQ-0042',
      username: 'ana.eng',
      summary: const {
        'full_name': 'Ana Reyes',
        'office_name': 'Engineering Office',
        'office_code': 'ENG',
        'requested_role': 'staff',
        'status_key': '',
      },
    );
    expect(find.text('Pending admin approval'), findsOneWidget);
    expect(find.text('Awaiting admin'), findsOneWidget);
    expect(find.text('Check your access request'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed lookup shows the reason and still claims nothing', (
    tester,
  ) async {
    await _mount(
      tester,
      summary: const {},
      response: http.Response(
        '{"success":false,"message":"Unable to verify request"}',
        404,
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'REQ-9');
    await tester.enterText(find.byType(TextField).at(1), 'wrong-key');
    await tester.tap(find.text('Refresh status'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to verify request'), findsOneWidget);
    expect(find.text('Check your access request'), findsOneWidget);
    expect(find.text('Pending admin approval'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copying with no status key explains instead of copying nothing', (
    tester,
  ) async {
    await _mount(tester, summary: const {});
    await tester.ensureVisible(find.text('Copy private status key'));
    await tester.tap(find.text('Copy private status key'));
    await tester.pump();
    expect(find.text('There is no status key to copy yet.'), findsOneWidget);
    expect(find.text('Status key copied. Keep it private.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
