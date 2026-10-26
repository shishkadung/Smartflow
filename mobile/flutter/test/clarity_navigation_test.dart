import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/screens/head/head_shell.dart';
import 'package:smartflow/screens/staff/clerk_widgets.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/widgets/document_summary.dart';
import 'package:smartflow/widgets/sf_widgets.dart';

class _ClarityApi extends SmartflowApi {
  _ClarityApi() : super(ApiClient());
  Map<String, dynamic>? saved;
  bool failAlerts = false;
  bool failLimits = false;
  String alertKind = 'due_soon';
  @override
  Future<Map<String, dynamic>> adminOffices() async {
    if (failLimits) throw ApiException('Sample time limits read failure');
    return {
      'offices': [
        {
          'office_id': 4,
          'office_name': 'Accounting Office',
          'office_code': 'ACC',
          'thresholds': [
            {
              'document_type': 'Approved Budget',
              'max_hours': 72,
              'out_unconfirmed_hours': 36,
            },
            {
              'document_type': 'Disbursement Voucher',
              'max_hours': 48,
              'out_unconfirmed_hours': 12,
            },
          ],
        },
      ],
    };
  }

  @override
  Future<void> updateThreshold({
    required int officeId,
    required String documentType,
    required int maxHours,
    int outHours = 24,
  }) async {
    saved = {
      'office': officeId,
      'type': documentType,
      'processing': maxHours,
      'receipt': outHours,
    };
  }

  @override
  Future<Map<String, dynamic>> alerts(int officeId) => accountantAlerts();
  @override
  Future<Map<String, dynamic>> accountantAlerts() async {
    if (failAlerts) throw ApiException('Sample connection failure');
    return {
      'alerts': [
        {
          'document_id': 'DOC-2026-000001',
          'document_title': 'Bridge repair folder',
          'kind': alertKind,
          'last_status': 'OUT',
          'last_office_name': 'Accounting Office',
          'hours_pending': 72,
          'days_pending': 0,
          'is_manual_due': true,
          'detail': 'Manual folder deadline requires follow-up',
          'due_at': '2026-10-16 23:59:59',
          'threshold_rule': 'Due date set on document',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> officeMovements(
    int officeId, {
    String? date,
    String? status,
    int page = 1,
    int pageSize = 25,
  }) async => {
    'movements': [],
    'stats': {'total': 0},
  };
}

class _Auth extends AuthProvider {
  _Auth(this.fixture, this.role);
  final _ClarityApi fixture;
  final String role;
  @override
  bool get isAuthenticated => true;
  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => AppUser(
    id: 44,
    username: 'clarity-sample',
    name: 'Sample reviewer',
    role: role,
    officeId: 4,
    officeCode: 'ACC',
    officeName: 'Accounting Office',
  );
}

final _captureKey = GlobalKey();
Future<void> _mount(
  WidgetTester tester,
  Widget page,
  _ClarityApi api, {
  double width = 390,
  double scale = 1,
  String role = 'admin',
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('SmartFlow · Sample data')),
          body: page,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  var theme = buildSmartflowTheme();
  if (const bool.fromEnvironment('CAPTURE_CLARITY')) {
    // Read-only local fonts make optional sample captures readable; normal regressions use the test font.
    final fontPath = const String.fromEnvironment('REVIEW_FONT');
    final iconPath = const String.fromEnvironment('REVIEW_ICONS');
    if (fontPath.isNotEmpty) {
      final data = ByteData.sublistView(File(fontPath).readAsBytesSync());
      for (final family in [
        'ReviewSans',
        'Roboto',
        'Ahem',
        'SourceSans3',
        'SourceSans3_regular',
        'SourceSans3_500',
        'SourceSans3_600',
        'SourceSans3_700',
      ]) {
        await (FontLoader(family)..addFont(Future.value(data))).load();
      }
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'ReviewSans'),
        primaryTextTheme: theme.primaryTextTheme.apply(
          fontFamily: 'ReviewSans',
        ),
      );
    }
    if (iconPath.isNotEmpty) {
      final data = ByteData.sublistView(File(iconPath).readAsBytesSync());
      await (FontLoader('MaterialIcons')..addFont(Future.value(data))).load();
    }
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(api, role),
      child: RepaintBoundary(
        key: _captureKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: theme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_CLARITY')) return;
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../../.runtime/clarity/mobile-$name-sample.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'time limits prefill and preserve both existing values when saving',
    (tester) async {
      final api = _ClarityApi();
      await _mount(tester, const AdminThresholdsScreen(), api);
      expect(find.text('Alert time limits'), findsOneWidget);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.map((f) => f.controller!.text), [
        'Approved Budget',
        '72',
        '36',
      ]);
      await tester.scrollUntilVisible(
        find.text('Save time limits'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save time limits'));
      await tester.pumpAndSettle();
      expect(api.saved, {
        'office': 4,
        'type': 'Approved Budget',
        'processing': 72,
        'receipt': 36,
      });
      await tester.scrollUntilVisible(
        find.text('Disbursement Voucher').first,
        -240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disbursement Voucher').first);
      await tester.pumpAndSettle();
      expect(fields.map((f) => f.controller!.text), [
        'Disbursement Voucher',
        '48',
        '12',
      ]);
      await tester.pump(const Duration(seconds: 4));
      await _capture(tester, 'time-limits-fields');
      await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
      await tester.pumpAndSettle();
      await _capture(tester, 'time-limits');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid time limits can be corrected without losing the draft', (
    tester,
  ) async {
    final api = _ClarityApi();
    await _mount(
      tester,
      const AdminThresholdsScreen(),
      api,
      width: 320,
      scale: 2,
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Processing time limit (hours)'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '721');
    await tester.scrollUntilVisible(
      find.text('Save time limits'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save time limits'));
    await tester.pumpAndSettle();
    expect(api.saved, isNull);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Processing time limit (hours)'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '96');
    await tester.scrollUntilVisible(
      find.text('Save time limits'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save time limits'));
    await tester.pumpAndSettle();
    expect(api.saved?['processing'], 96);
    expect(api.saved?['receipt'], 36);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed time limit refresh disables editing and saving until successful retry',
    (tester) async {
      final api = _ClarityApi();
      await _mount(tester, const AdminThresholdsScreen(), api);
      api.failLimits = true;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Previously loaded rules may be stale.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Save time limits'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        false,
      );
      expect(
        tester.widget<SfPrimaryButton>(find.byType(SfPrimaryButton)).onPressed,
        isNull,
      );
      expect(api.saved, isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
      await tester.pumpAndSettle();
      await _capture(tester, 'time-limits-stale');
      api.failLimits = false;
      await tester.scrollUntilVisible(
        find.text('Retry'),
        -240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save time limits'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save time limits'));
      await tester.pumpAndSettle();
      expect(api.saved?['receipt'], 36);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width: width, scale: scale) in [
    (width: 390.0, scale: 1.0),
    (width: 320.0, scale: 2.0),
  ]) {
    testWidgets(
      'alert filter chips carry no counts and none is pushed off a ${width.toInt()}px phone at ${scale}x text',
      (tester) async {
        await _mount(
          tester,
          const StaffAlertsScreen(municipal: true),
          _ClarityApi(),
          width: width,
          scale: scale,
        );
        // Large text pushes the chips below the first screen of a lazy list.
        await tester.scrollUntilVisible(
          find.widgetWithText(FilterChip, 'Receipt not recorded'),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        final chips = find.byType(FilterChip);
        expect(chips, findsNWidgets(4));
        final labels = <String>[];
        for (var i = 0; i < 4; i++) {
          final chip = tester.widget<FilterChip>(chips.at(i));
          labels.add((chip.label as Text).data!);
          final rect = tester.getRect(chips.at(i));
          expect(rect.left, greaterThanOrEqualTo(0), reason: labels.last);
          expect(rect.right, lessThanOrEqualTo(width), reason: labels.last);
        }
        expect(labels, ['All', 'Overdue', 'Due soon', 'Receipt not recorded']);
        expect(labels.any((label) => label.contains('(')), isFalse);
        // The per-kind counts remain in the summary strip.
        expect(find.text('Receipt not recorded'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'OUT deadline alert describes sending and missing receipt, not a desk',
    (tester) async {
      await _mount(
        tester,
        const StaffAlertsScreen(municipal: true),
        _ClarityApi(),
      );
      expect(find.text('Receipt not recorded'), findsWidgets);
      expect(find.textContaining('3 days since sending'), findsOneWidget);
      expect(find.text('Due soon'), findsWidgets);
      expect(
        find.textContaining('Manual folder deadline requires follow-up'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Deadline: 2026-10-16 23:59:59'),
        findsOneWidget,
      );
      expect(find.textContaining('Still on your desk'), findsNothing);
      expect(find.textContaining('hours at this desk'), findsNothing);
      await _capture(tester, 'alerts');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'outgoing overdue manual deadline keeps both deadline and receipt states',
    (tester) async {
      final api = _ClarityApi()..alertKind = 'delayed';
      await _mount(tester, const StaffAlertsScreen(municipal: true), api);
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Receipt not recorded'), findsWidgets);
      expect(
        find.textContaining('Manual folder deadline requires follow-up'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Deadline: 2026-10-16 23:59:59'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'alerts distinguish unavailable reads and stale retained data with retry',
    (tester) async {
      final api = _ClarityApi()..failAlerts = true;
      await _mount(tester, const StaffAlertsScreen(municipal: true), api);
      expect(find.textContaining('Alerts unavailable.'), findsOneWidget);
      expect(find.text('No alerts right now'), findsNothing);
      api.failAlerts = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Bridge repair folder'), findsOneWidget);
      api.failAlerts = true;
      await tester.drag(find.byType(ListView).first, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Previously loaded alerts may be stale.'),
        findsOneWidget,
      );
      expect(find.text('Bridge repair folder'), findsOneWidget);
      await _capture(tester, 'alerts-stale');
      expect(tester.takeException(), isNull);
    },
  );

  for (final role in ['admin', 'head']) {
    testWidgets(
      '$role failed refresh of hidden alerts never reports healthy all-clear',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'sf_alert_actions_v1_snooze': jsonEncode({
            'DOC-2026-000001::due_soon': DateTime.now()
                .add(const Duration(days: 1))
                .toIso8601String(),
          }),
        });
        final api = _ClarityApi();
        await _mount(
          tester,
          role == 'admin'
              ? const StaffAlertsScreen(municipal: true)
              : const HeadAlertsScreen(),
          api,
          role: role,
        );
        api.failAlerts = true;
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Previously loaded reminders are hidden. Retry to verify current alerts.',
          ),
          findsOneWidget,
        );
        expect(find.byType(SfAlertsHealthyEmptyPanel), findsNothing);
        expect(
          find.textContaining('Previously loaded alerts may be stale.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'admin menu groups infrequent tools and remains usable with large text',
    (tester) async {
      await _mount(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showSfRoleMoreSheet(context, pendingSignups: 3),
            child: const Text('Open menu'),
          ),
        ),
        _ClarityApi(),
        width: 320,
        scale: 2,
      );
      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();
      expect(find.text('Administration'), findsOneWidget);
      expect(find.text('Users'), findsNothing);
      await _capture(tester, 'menu');
      await tester.tap(find.text('Administration'));
      await tester.pumpAndSettle();
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Alert time limits'), findsOneWidget);
      await _capture(tester, 'administration');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'folder summary keeps long identity, location and deadline readable',
    (tester) async {
      await _mount(
        tester,
        const SingleChildScrollView(
          padding: EdgeInsets.all(18),
          child: DocumentSummary(
            document: {
              'id': 'DOC-2026-000001',
              'title':
                  'Bridge repair with complete supporting engineering documents',
              'current_status': 'OUT',
              'current_office_name': 'Accounting Office',
              'destination_office_name':
                  'Municipal Engineering and Public Works Office',
              'due_at_display': 'Oct 16, 2026 11:59 PM',
              'tray': 'forwarded',
              'type': 'Disbursement Voucher',
              'origin_office_name': 'Engineering Office',
            },
          ),
        ),
        _ClarityApi(),
        width: 320,
        scale: 2,
      );
      expect(find.textContaining('receipt not recorded'), findsOneWidget);
      await _capture(tester, 'folder-detail');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history starts with folder lookup and makes daily activity an explicit view',
    (tester) async {
      await _mount(
        tester,
        const StaffHistoryScreen(monitorOnly: true),
        _ClarityApi(),
      );
      expect(find.text('Tracking ID'), findsOneWidget);
      expect(find.text('No office activity in this filter'), findsNothing);
      await _capture(tester, 'folder-history');
      await tester.tap(find.text('Office activity'));
      await tester.pumpAndSettle();
      expect(find.text('Tracking ID'), findsNothing);
      expect(find.text('No office activity in this filter'), findsOneWidget);
      await _capture(tester, 'office-activity');
      expect(tester.takeException(), isNull);
    },
  );
}
