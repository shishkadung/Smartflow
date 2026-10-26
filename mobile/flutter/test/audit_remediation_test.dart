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
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/screens/head/head_shell.dart';
import 'package:smartflow/screens/shared/documents_screen.dart';
import 'package:smartflow/screens/staff/scanner_screen.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/utils/tracking_id.dart';

const _id = 'DOC-2026-000071';

class _Fixture {
  int latest = 41;
  int documentReads = 0;
  int officeReads = 0;
  bool advanceOnDialogRead = false;
  bool failAnalytics = false;
  bool failReport = false;
  bool failExceptions = false;
  final filingWrites = <Map<String, dynamic>>[];
  bool includeSlow = false;
  int exceptionCount = 0;
  Map<String, dynamic> folder = {
    'id': _id,
    'title': 'Controlled receipt folder',
    'type': 'Others: Test folder',
    'current_status': 'OUT',
    'current_office_id': 2,
    'current_office_name': 'Budget Office',
    'destination_office_id': 1,
    'destination_office_name': 'Engineering Office',
    'last_movement_id': 41,
    'origin_office_name': 'Budget Office',
    'tray': 'incoming',
    'folder_inventory': {
      'total_pages': 3,
      'items': [
        {'id': 'main', 'name': 'Main document', 'pages': 3, 'required': true},
      ],
    },
  };
  final writes = <Map<String, dynamic>>[];
  late final api = SmartflowApi(
    ApiClient(token: 'fixture', client: MockClient(_respond)),
    movementScope: '813_1',
  );

  http.Response _json(Map<String, dynamic> data, [int status = 200]) =>
      http.Response(
        jsonEncode(data),
        status,
        headers: {'content-type': 'application/json'},
      );
  Future<http.Response> _respond(http.Request request) async {
    final path = request.url.pathSegments.last;
    if (path == 'reports-register.php') {
      return _json({'documents': [], 'total': 0, 'total_pages': 0, 'page': 1});
    }
    if (path == 'documents-show.php') {
      documentReads++;
      if (advanceOnDialogRead) {
        latest = 99;
      }
      return _json({
        'success': true,
        'document': {
          ...folder,
          'last_movement_id': latest == 0 ? null : latest,
        },
      });
    }
    if (path == 'office-documents.php') {
      officeReads++;
      return _json({
        'success': true,
        'document': {...folder, 'last_movement_id': latest},
      });
    }
    if (path == 'offices-list.php') {
      return _json({
        'success': true,
        'offices': [
          {'id': 1, 'code': 'ENG', 'name': 'Engineering Office'},
          {'id': 2, 'code': 'BUD', 'name': 'Budget Office'},
        ],
      });
    }
    if (path == 'movements-create.php') {
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      writes.add(body);
      if (body['expected_movement_id'] != latest) {
        return _json({
          'success': false,
          'message':
              'The document moved since you opened it. Refresh and review its current location.',
          'scan_error': 'document_changed',
        }, 409);
      }
      latest++;
      folder = {
        ...folder,
        'current_status': body['status'],
        'current_office_id': 1,
        'current_office_name': 'Engineering Office',
      };
      return _json({
        'success': true,
        'movement_id': latest,
        'message': 'Movement recorded',
      });
    }
    if (path == 'documents-file.php') {
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      filingWrites.add(body);
      if (body['expected_movement_id'] != latest) {
        return _json({
          'success': false,
          'message':
              'The folder moved since you opened it. Refresh and review before filing.',
        }, 409);
      }
      folder = {
        ...folder,
        'can_file': false,
        'trail_complete': true,
        'tray': 'completed',
      };
      return _json({'success': true, 'message': 'Folder filed'});
    }
    if (path == 'dashboard-stats.php') {
      return _json({
        'success': true,
        'stats': {'in_flow': 1, 'out_flow': 0, 'active_tags': 1},
        'active_documents': [
          {
            'document_id': _id,
            'title': 'Controlled receipt folder',
            'type': 'Others: Test folder',
          },
        ],
        'in_transit': [],
        'recent_movements': [],
      });
    }
    if (path == 'document-requests-summary.php') {
      return _json({'success': true, 'pending_inbox_count': 0});
    }
    if (path == 'head-analytics.php') {
      if (failAnalytics) {
        return _json({
          'success': false,
          'message': 'Analytics connection failed',
        }, 503);
      }
      return _json({
        'success': true,
        'month': 'October 2026',
        'stats': {
          'processed': 7,
          'late_count': includeSlow ? 1 : 0,
          'on_time_percent': 100,
        },
        'slow_documents': includeSlow
            ? [
                {'document_id': _id, 'hours': 90},
              ]
            : [],
      });
    }
    if (path == 'reports-summary.php') {
      if (failReport) {
        return _json({
          'success': false,
          'message': 'Report connection failed',
        }, 503);
      }
      return _json({
        'success': true,
        'export_allowed': false,
        'compliance': {
          'on_time': {'percent': 100},
          'unforwarded': {'percent': 0},
          'delayed': {'percent': 0},
        },
        'totals': {'documents_in_period': 0},
        'office_totals': [],
        'generated_at': '2026-10-15 09:00:00',
        'timezone': 'Asia/Manila',
        'scope': 'Municipal',
        'prepared_by': 'Sample administrator',
      });
    }
    if (path == 'audit-exceptions.php' && failExceptions) {
      return _json({
        'success': false,
        'message': 'Temporary exception connection failure',
      }, 503);
    }
    if (path == 'audit-exceptions.php') {
      return _json({
        'success': true,
        'exceptions': [
          for (var i = 1; i <= exceptionCount; i++)
            {
              'document_id': 'EXCEPTION-$i',
              'detail':
                  'Complete exception evidence for folder $i. Follow up on the unreceived handoff.',
              'exception_type': 'unforwarded',
            },
        ],
      });
    }
    throw StateError('Unexpected fixture request: $path');
  }
}

class _Auth extends AuthProvider {
  _Auth(this.fixture, this.role);
  final _Fixture fixture;
  final String role;
  @override
  SmartflowApi get api => fixture.api;
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get user => AppUser(
    id: 813,
    username: 'audit.sample',
    name: 'Sample reviewer',
    role: role,
    officeId: role == 'admin' ? 4 : 1,
    officeCode: role == 'admin' ? 'ACC' : 'ENG',
    officeName: role == 'admin' ? 'Accounting Office' : 'Engineering Office',
  );
}

Future<void> _settle(WidgetTester tester) async {
  // Scan deliberately keeps its busy indicator running behind confirmation dialogs.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openExceptions(WidgetTester tester) async {
  // The Exceptions part of Custody reports is opened from its chip, as on the web.
  final chip = find.byWidgetPredicate(
    (widget) =>
        widget is ChoiceChip &&
        widget.label is Text &&
        ((widget.label as Text).data ?? '').startsWith('Exceptions'),
  );
  await _show(tester, chip);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await _settle(tester);
}

Future<void> _mount(
  WidgetTester tester,
  Widget screen,
  _Fixture fixture, {
  String role = 'staff',
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: screen),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(fixture, role),
      child: MaterialApp.router(
        theme: buildSmartflowTheme().copyWith(platform: TargetPlatform.windows),
        routerConfig: router,
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _show(
  WidgetTester tester,
  Finder finder, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await _settle(tester);
}

Future<void> _lookup(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), _id);
  await tester.tap(find.text('Look up document'));
  await _settle(tester);
}

Future<void> _confirmReceipt(WidgetTester tester, {bool counted = true}) async {
  if (counted) {
    await tester.enterText(
      find.widgetWithText(TextField, 'Main document — received pages'),
      '3',
    );
  }
  await tester.tap(find.byType(CheckboxListTile));
  await _settle(tester);
  await tester.tap(find.text('Confirm receipt'));
  await _settle(tester);
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'sf_role_tip_seen_v2_audit.sample': true,
    });
  });
  test('scan Receive follows the effective corrected destination', () {
    final wrong = clerkScanActions(
      lastMovement: null,
      myOfficeId: 1,
      currentStatus: 'OUT',
      currentOfficeId: 2,
      currentOfficeName: 'Budget Office',
      destinationOfficeId: 4,
      destinationOfficeName: 'Accounting Office',
    );
    expect(wrong.canIn, false);
    expect(wrong.blockReason, contains('Accounting Office'));
    final corrected = clerkScanActions(
      lastMovement: null,
      myOfficeId: 1,
      currentStatus: 'OUT',
      currentOfficeId: 2,
      destinationOfficeId: 1,
      destinationOfficeName: 'Engineering Office',
    );
    expect(corrected.canIn, true);
    final legacy = clerkScanActions(
      lastMovement: null,
      myOfficeId: 1,
      currentStatus: 'OUT',
      currentOfficeId: 2,
    );
    expect(legacy.canIn, true);
  });
  testWidgets('wrong-destination Scan has no Receive or receipt dialog', (
    tester,
  ) async {
    final fixture = _Fixture();
    fixture.folder = {
      ...fixture.folder,
      'destination_office_id': 4,
      'destination_office_name': 'Accounting Office',
    };
    await _mount(tester, const ScannerScreen(), fixture);
    await _lookup(tester);
    expect(find.text('Receive (IN)'), findsNothing);
    expect(
      find.textContaining('Only the recorded receiving office'),
      findsOneWidget,
    );
    expect(fixture.writes, isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  testWidgets(
    'Scan receipt cancellation makes no write; stale confirmation keeps the displayed movement and counts',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, const ScannerScreen(), fixture);
      await _lookup(tester);
      await _show(tester, find.text('Receive (IN)'));
      await tester.tap(find.text('Receive (IN)'));
      await _settle(tester);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(fixture.writes, isEmpty);
      await tester.tap(find.text('Receive (IN)'));
      await _settle(tester);
      fixture.latest =
          99; // Another complete custody cycle ended at the same apparent OUT state.
      await _confirmReceipt(tester);
      expect(fixture.writes, hasLength(1));
      expect(fixture.writes.single['expected_movement_id'], 41);
      expect(fixture.writes.single['movement_source'], 'scan');
      expect(fixture.writes.single['receipt_confirmed'], true);
      expect(fixture.writes.single['contents_receipt']['items'], [
        {'id': 'main', 'pages': 3},
      ]);
      expect(fixture.documentReads, 1);
      expect(
        find.textContaining('The document moved since you opened it.'),
        findsOneWidget,
      );
      expect(await fixture.api.pendingMovement(), isNull);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'Scan Send never replaces the reviewed ID with a newer destination-dialog lookup',
    (tester) async {
      final fixture = _Fixture();
      fixture.folder = {
        ...fixture.folder,
        'current_status': 'IN',
        'current_office_id': 1,
        'current_office_name': 'Engineering Office',
        'folder_inventory': null,
        'tray': 'in_office',
      };
      await _mount(tester, const ScannerScreen(), fixture);
      await _lookup(tester);
      fixture.advanceOnDialogRead = true;
      await _show(tester, find.text('Send (OUT)'));
      await tester.tap(find.text('Send (OUT)'));
      await _settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Budget Office'),
        ),
      );
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Send (OUT)'));
      await _settle(tester);
      expect(fixture.documentReads, 2);
      expect(fixture.writes, hasLength(1));
      expect(fixture.writes.single['expected_movement_id'], 41);
      expect(fixture.writes.single['destination_office_id'], 2);
      expect(
        find.textContaining('The document moved since you opened it.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets('legacy Scan with no reviewed movement explicitly sends zero', (
    tester,
  ) async {
    final fixture = _Fixture()..latest = 0;
    fixture.folder = {
      ...fixture.folder,
      'current_status': null,
      'current_office_id': null,
      'current_office_name': null,
      'folder_inventory': null,
      'last_movement_id': null,
    };
    await _mount(tester, const ScannerScreen(), fixture);
    await _lookup(tester);
    await _show(tester, find.text('Receive (IN)'));
    await tester.tap(find.text('Receive (IN)'));
    await _settle(tester);
    await _confirmReceipt(tester, counted: false);
    expect(fixture.writes.single['expected_movement_id'], 0);
    expect(fixture.writes.single['receipt_confirmed'], true);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  testWidgets(
    'Home quick Send freezes its pre-dialog review and does not rebase before posting',
    (tester) async {
      final fixture = _Fixture()..advanceOnDialogRead = true;
      fixture.folder = {
        ...fixture.folder,
        'current_status': 'IN',
        'current_office_id': 1,
        'current_office_name': 'Engineering Office',
        'tray': 'in_office',
      };
      await _mount(tester, const StaffDashboardScreen(), fixture);
      await _show(tester, find.text('Send (OUT)'));
      await tester.tap(find.text('Send (OUT)'));
      await _settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Budget Office'),
        ),
      );
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Send (OUT)'));
      await _settle(tester);
      expect(fixture.officeReads, 1);
      expect(fixture.documentReads, 1);
      expect(fixture.writes.single['expected_movement_id'], 41);
      expect(fixture.writes.single['movement_source'], 'system');
      expect(
        find.textContaining('The document moved since you opened it.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final scanner in [true, false]) {
    testWidgets(
      '${scanner ? 'Scan' : 'Documents'} filing cancellation and stale cycle keep the frozen displayed movement',
      (tester) async {
        final fixture = _Fixture();
        fixture.folder = {
          ...fixture.folder,
          'current_status': 'IN',
          'current_office_id': 1,
          'current_office_name': 'Engineering Office',
          'can_file': true,
          'tray': 'in_office',
        };
        await _mount(
          tester,
          scanner
              ? const ScannerScreen()
              : const DocumentsScreen(initialDocumentId: _id),
          fixture,
        );
        if (scanner) await _lookup(tester);
        await _show(tester, find.text('File this folder'));
        await tester.tap(find.text('File this folder'));
        await _settle(tester);
        expect(find.text('File this folder?'), findsOneWidget);
        await tester.tap(find.text('Keep active'));
        await _settle(tester);
        expect(fixture.filingWrites, isEmpty);
        await tester.tap(find.text('File this folder'));
        await _settle(tester);
        fixture.latest =
            99; // A send/return cycle ended at the same office while confirmation was open.
        await tester.tap(find.text('Confirm filing'));
        await _settle(tester);
        expect(fixture.filingWrites, [
          {'document_id': _id, 'expected_movement_id': 41},
        ]);
        await _show(
          tester,
          find.textContaining('The folder moved since you opened it.'),
          delta: -200,
        );
        expect(
          find.textContaining('The folder moved since you opened it.'),
          findsOneWidget,
        );
        expect(fixture.folder['can_file'], true);
        // The rejected action only reads fresh detail; another write needs a fresh explicit confirmation.
        await _show(tester, find.text('File this folder'));
        await tester.tap(find.text('File this folder'));
        await _settle(tester);
        expect(fixture.filingWrites, hasLength(1));
        await tester.tap(find.text('Confirm filing'));
        await _settle(tester);
        expect(fixture.filingWrites.last['expected_movement_id'], 99);
        expect(fixture.filingWrites, hasLength(2));
        expect(fixture.folder['can_file'], false);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.windows}),
    );
  }
  testWidgets(
    'exception-only Retry removes an old error and reveals the thirteenth recovered exception',
    (tester) async {
      final fixture = _Fixture()
        ..failExceptions = true
        ..exceptionCount = 15;
      await _mount(tester, const AdminReportsScreen(), fixture, role: 'admin');
      await _openExceptions(tester);
      await _show(tester, find.text('Retry exceptions'));
      expect(
        find.textContaining('Audit exceptions unavailable.'),
        findsOneWidget,
      );
      fixture.failExceptions = false;
      await tester.tap(find.text('Retry exceptions'));
      await _settle(tester);
      expect(
        find.textContaining('Audit exceptions unavailable.'),
        findsNothing,
      );
      expect(find.text('Retry exceptions'), findsNothing);
      await _show(tester, find.text('EXCEPTION-13'));
      expect(
        find.text(
          'Complete exception evidence for folder 13. Follow up on the unreceived handoff.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Analytics unavailable and stale-empty reads never claim all items met their limit',
    (tester) async {
      final fixture = _Fixture()..failAnalytics = true;
      await _mount(tester, const HeadAnalyticsScreen(), fixture, role: 'head');
      expect(find.textContaining('Analytics unavailable.'), findsOneWidget);
      expect(find.text('No slow documents'), findsNothing);
      expect(
        find.text('All processed items met the threshold this month.'),
        findsNothing,
      );
      fixture.failAnalytics = false;
      await tester.tap(find.text('Retry analytics'));
      await _settle(tester);
      await _show(tester, find.text('No slow documents'));
      expect(
        find.text('All processed items met the threshold this month.'),
        findsOneWidget,
      );
      fixture.failAnalytics = true;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await _settle(tester);
      expect(find.text('No slow documents'), findsNothing);
      await _show(
        tester,
        find.textContaining('Previously loaded analytics may be stale.'),
        delta: -250,
      );
      expect(
        find.textContaining('Previously loaded analytics may be stale.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Analytics failed refresh retains real figures with a stale warning',
    (tester) async {
      final fixture = _Fixture()..includeSlow = true;
      await _mount(tester, const HeadAnalyticsScreen(), fixture, role: 'head');
      fixture.failAnalytics = true;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await _settle(tester);
      expect(
        find.textContaining('Previously loaded analytics may be stale.'),
        findsOneWidget,
      );
      await _show(tester, find.text(_id));
      expect(find.text('90h at office · tap for history'), findsOneWidget);
      expect(
        find.text('All processed items met the threshold this month.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed report does not turn an unavailable office total into no movements',
    (tester) async {
      final fixture = _Fixture()..failReport = true;
      await _mount(tester, const AdminReportsScreen(), fixture, role: 'admin');
      expect(
        find.textContaining('Custody report unavailable.'),
        findsOneWidget,
      );
      await _show(
        tester,
        find.text('Office totals are unavailable until the report loads.'),
      );
      expect(find.text('No office totals'), findsNothing);
      expect(
        find.textContaining('No office totals for this'),
        findsNothing,
      );
      fixture.failReport = false;
      await tester.tap(find.text('Retry report'));
      await _settle(tester);
      await _show(tester, find.text('No office totals'));
      expect(find.text('No office totals for this month.'), findsOneWidget);
      fixture.failReport = true;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await _settle(tester);
      await _show(
        tester,
        find.text('Office totals are unavailable until the report loads.'),
      );
      expect(find.text('No office totals'), findsNothing);
      expect(
        find.textContaining('No office totals for this'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('all returned audit exceptions remain inspectable beyond twelve', (
    tester,
  ) async {
    final fixture = _Fixture()..exceptionCount = 15;
    await _mount(tester, const AdminReportsScreen(), fixture, role: 'admin');
    await _openExceptions(tester);
    await _show(tester, find.text('15 audit exceptions'));
    await _show(tester, find.text('EXCEPTION-15'));
    expect(
      find.text(
        'Complete exception evidence for folder 15. Follow up on the unreceived handoff.',
      ),
      findsOneWidget,
    );
    await _show(tester, find.text('EXCEPTION-13'), delta: -200);
    expect(
      find.text(
        'Complete exception evidence for folder 13. Follow up on the unreceived handoff.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
