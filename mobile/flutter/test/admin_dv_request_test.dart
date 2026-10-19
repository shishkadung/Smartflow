import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/shared/document_requests_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

class _Fixture {
  _Fixture({this.status = 'approved'});

  String status;
  bool failList = false;
  final writes = <Map<String, dynamic>>[];

  Map<String, dynamic> get request => {
    'id': 91,
    'request_code': 'REQ-2026-000091',
    'status': status,
    'revision': 'reviewed-revision-91',
    'document_category': 'disbursement',
    'purpose': 'Release the synthetic project payment after actual release.',
    'related_document_id': 'DOC-2026-000091',
    'requester': {'user_id': 201, 'office_code': 'ENG'},
    'handler_office': {
      'office_id': 3,
      'office_code': 'ACC',
      'office_name': 'Accounting Office',
    },
  };

  late final client = MockClient((request) async {
    switch (request.url.pathSegments.last) {
      case 'document-requests-list.php':
        if (failList) {
          return http.Response('{"message":"List unavailable"}', 503);
        }
        final rows = request.url.queryParameters['view'] == 'inbox'
            ? [this.request]
            : <Map<String, dynamic>>[];
        return http.Response(
          jsonEncode({
            'requests': rows,
            'total': rows.length,
            'page': 1,
            'page_size': 25,
            'pending_inbox_count': status == 'pending' ? 1 : 0,
            'counts': {'active': rows.length, 'past': 0, 'overdue': 0},
          }),
          200,
        );
      case 'document-requests-update.php':
        writes.add(jsonDecode(request.body) as Map<String, dynamic>);
        status = 'fulfilled';
        return http.Response('{"success":true}', 200);
      default:
        throw StateError('Unexpected fixture endpoint: ${request.url.path}');
    }
  });
}

class _Auth extends AuthProvider {
  _Auth(_Fixture fixture, {required String role, required String office})
    : _api = SmartflowApi(
        ApiClient(token: 'synthetic-test-session', client: fixture.client),
      ),
      _user = AppUser(
        id: 102,
        name: 'Synthetic reviewer',
        username: 'synthetic.reviewer',
        role: role,
        officeId: office == 'ACC' ? 3 : 4,
        officeName: '$office Office',
        officeCode: office,
      );

  final SmartflowApi _api;
  final AppUser _user;
  @override
  SmartflowApi get api => _api;
  @override
  AppUser get user => _user;
}

Future<void> _mount(
  WidgetTester tester,
  _Fixture fixture, {
  String role = 'admin',
  String office = 'ACC',
}) async {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth(fixture, role: role, office: office);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const DocumentRequestsScreen(homeRoute: '/admin'),
      ),
    ],
  );
  addTearDown(auth.dispose);
  addTearDown(router.dispose);
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
}

Finder get _release => find.text('Mark payment released');

Future<void> _details(WidgetTester tester) async {
  await tester.tap(
    find.text('Release the synthetic project payment after actual release.'),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  for (final scenario in [
    (role: 'admin', office: 'ACC', allowed: true),
    (role: 'staff', office: 'ACC', allowed: false),
    (role: 'head', office: 'ACC', allowed: false),
    (role: 'staff', office: 'TRE', allowed: true),
    (role: 'head', office: 'TRE', allowed: true),
  ]) {
    testWidgets(
      '${scenario.office} ${scenario.role} has matching DV release authority in card and details',
      (tester) async {
        final fixture = _Fixture();
        await _mount(
          tester,
          fixture,
          role: scenario.role,
          office: scenario.office,
        );
        expect(_release, scenario.allowed ? findsOneWidget : findsNothing);
        await _details(tester);
        final detailsRelease = find.descendant(
          of: find.byType(RequestDetailsSheet),
          matching: _release,
        );
        expect(
          detailsRelease,
          scenario.allowed ? findsOneWidget : findsNothing,
        );
        if (scenario.allowed) {
          expect(
            find.descendant(
              of: find.byType(RequestDetailsSheet),
              matching: find.text(
                'Treasury records payment release before this DV request closes.',
              ),
            ),
            findsNothing,
          );
        }
        expect(fixture.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final status in ['pending', 'fulfilled', 'rejected', 'cancelled']) {
    testWidgets('Accounting admin cannot release a $status DV request', (
      tester,
    ) async {
      final fixture = _Fixture(status: status);
      await _mount(tester, fixture);
      expect(_release, findsNothing);
      await _details(tester);
      expect(_release, findsNothing);
      expect(fixture.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final fromDetails in [false, true]) {
    testWidgets(
      'Accounting admin confirms DV release from ${fromDetails ? 'details' : 'card'} with reviewed revision',
      (tester) async {
        final fixture = _Fixture();
        await _mount(tester, fixture);
        if (fromDetails) await _details(tester);
        await tester.tap(
          fromDetails
              ? find.descendant(
                  of: find.byType(RequestDetailsSheet),
                  matching: _release,
                )
              : _release,
        );
        await tester.pumpAndSettle();
        expect(fixture.writes, isEmpty);
        await tester.enterText(
          find.byType(TextField).last,
          'Actual payment released with complete receipt evidence.',
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Mark payment released').last,
        );
        await tester.pumpAndSettle();
        expect(fixture.writes, [
          {
            'request_id': 91,
            'action': 'fulfill',
            'expected_status': 'approved',
            'expected_revision': 'reviewed-revision-91',
            'review_notes':
                'Actual payment released with complete receipt evidence.',
            'related_document_id': 'DOC-2026-000091',
          },
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Accounting admin cancelling DV release records no update', (
    tester,
  ) async {
    final fixture = _Fixture();
    await _mount(tester, fixture);
    await tester.tap(_release);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fixture.writes, isEmpty);
    expect(_release, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
