import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

// The phone Custody reports page has the same parts, wording and honesty rules as the web page.

Map<String, dynamic> _cell(
  String month,
  int visits,
  int forwarded,
  num? avg,
  int late, {
  bool slow = false,
}) => {
  'month': month,
  'visits': visits,
  'forwarded': forwarded,
  'avg_hours': avg,
  'late': late,
  'late_percent': visits == 0 ? null : (late * 1000 / visits).round() / 10,
  'slow': slow,
};

Map<String, dynamic> _totals(int visits, num? avg, int late) => {
  'visits': visits,
  'avg_hours': avg,
  'late': late,
  'late_percent': visits == 0 ? null : (late * 1000 / visits).round() / 10,
};

Map<String, dynamic> _performance(int months) => {
  'success': true,
  'window': {
    'months': months,
    'start_month': '2026-05',
    'end_month': '2026-10',
  },
  'rules': {
    'slow_month_late_percent': 25,
    'recurring_slow_months': 3,
    'default_desk_limit_hours': 24,
  },
  'basis':
      'A visit is one IN at an office. A month is slow when it has at least 3 visits and at least 25% of them were late.',
  'municipal': {'totals': _totals(27, 15.3, 8)},
  'bottlenecks': [
    {
      'office_id': 5,
      'office_code': 'TRE',
      'office_name': 'Treasury Office',
      'slow_months': 4,
      'active_months': 6,
      'late_percent': 42.3,
    },
  ],
  'offices': [
    {
      'office_id': 1,
      'office_code': 'ENG',
      'office_name': 'Engineering Office',
      'totals': _totals(9, 12.5, 0),
      'trend': {
        'direction': 'steady',
        'earlier_avg_hours': 12,
        'later_avg_hours': 12.9,
        'change_hours': 0.9,
      },
      'bottleneck': {'recurring': false},
      'months': [
        _cell('2026-05', 3, 3, 12, 0),
        _cell('2026-06', 3, 3, 13, 0),
        _cell('2026-07', 3, 3, 12.5, 0),
      ],
      'types': [],
    },
    {
      'office_id': 5,
      'office_code': 'TRE',
      'office_name': 'Treasury Office',
      'totals': _totals(13, 61.4, 8),
      'trend': {
        'direction': 'slower',
        'earlier_avg_hours': 40,
        'later_avg_hours': 72.5,
        'change_hours': 32.5,
      },
      'bottleneck': {'recurring': true},
      'months': [
        _cell('2026-05', 4, 4, 55, 3, slow: true),
        _cell('2026-06', 5, 5, 62, 3, slow: true),
        _cell('2026-07', 4, 4, 70, 2, slow: true),
      ],
      'types': [
        {'type': 'Disbursement Voucher', 'visits': 9, 'late': 5},
      ],
    },
    {
      'office_id': 2,
      'office_code': 'HR',
      'office_name': 'Human Resources',
      'totals': _totals(0, null, 0),
      'trend': {'direction': 'insufficient'},
      'bottleneck': {'recurring': false},
      'months': [
        _cell('2026-05', 0, 0, null, 0),
        _cell('2026-06', 0, 0, null, 0),
        _cell('2026-07', 0, 0, null, 0),
      ],
      'types': [],
    },
  ],
};

Map<String, dynamic> _register() => {
  'period_label': 'October 2026',
  'as_of': '2026-10-23 10:00:00',
  'timezone': 'Asia/Manila',
  'page': 1,
  'total_pages': 1,
  'total': 0,
  'documents': [],
};

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  bool unknownFigures = false;
  bool failDepartments = false;
  final registerQueries = <Map<String, String>>[];
  final departmentMonths = <int>[];
  int exceptionCalls = 0;

  @override
  Future<Map<String, dynamic>> reportsSummary(
    int officeId,
    String month,
  ) async => {
    'office_id': 4,
    'period': 'month',
    'month': month,
    'export_allowed': true,
    'period_start': '2026-10-01 00:00:00',
    'generated_at': '2026-10-23 10:00:00',
    'as_of': '2026-10-23 10:00:00',
    'movement_watermark': 77,
    'correction_watermark': 3,
    'timezone': 'Asia/Manila',
    'scope': 'Municipal',
    'prepared_by': 'Accounting administrator',
    'totals': unknownFigures ? {} : {'documents_in_period': 4},
    'outstanding_transfers': 1,
    'carried_forward_transfers': unknownFigures ? null : 1,
    'compliance': unknownFigures
        ? {
            'on_time': {'percent': null, 'count': null},
            'unforwarded': {'percent': null, 'count': null},
            'delayed': {'percent': null, 'count': null},
          }
        : {
            'on_time': {'percent': 50, 'count': 2},
            'unforwarded': {'percent': 25, 'count': 1},
            'delayed': {'percent': 25, 'count': 1},
          },
    if (!unknownFigures) ...{
      'completion': {
        'percent': 75,
        'completed': 3,
        'of': 4,
        'basis':
            'Completion counts folders filed or routed to the end of their trail.',
      },
      'processing_time': {
        'average_hours': 60,
        'forwarded_stays': 5,
        'open_stays': 2,
        'basis': 'Time at an office runs from receipt to forwarding.',
      },
    },
    'office_totals': [
      {
        'office_id': 4,
        'office_code': 'ACC',
        'office_name': 'Accounting Office',
        'docs_processed': 4,
        'forwarded_stays': 5,
        'avg_hours_at_office': 5,
      },
      {
        'office_id': 5,
        'office_code': 'TRE',
        'office_name': 'Treasury Office',
        'docs_processed': 3,
        'forwarded_stays': 0,
        'avg_hours_at_office': null,
      },
      {
        'office_id': 2,
        'office_code': 'HR',
        'office_name': 'Human Resources',
        'docs_processed': 2,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> reportsRegister(
    Map<String, String> query,
  ) async {
    registerQueries.add(Map.of(query));
    return _register();
  }

  @override
  Future<Map<String, dynamic>> auditExceptions({
    int hours = 24,
    Map<String, String> period = const {},
  }) async {
    exceptionCalls++;
    return {
      'exceptions': [
        {
          'document_id': 'DOC-2026-000077',
          'exception_type': 'unforwarded',
          'detail': 'Unreceived transfer evidence',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> departmentPerformance({int months = 6}) async {
    departmentMonths.add(months);
    if (failDepartments) throw ApiException('Controlled department failure');
    return _performance(months);
  }
}

class _Auth extends AuthProvider {
  _Auth(this.fixture, this.officeCode);
  final _Api fixture;
  final String officeCode;
  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => AppUser(
    id: 101,
    name: 'Report reviewer',
    username: 'report.reviewer',
    role: 'admin',
    officeId: 4,
    officeName: '$officeCode Office',
    officeCode: officeCode,
  );
}

Future<void> _mount(
  WidgetTester tester,
  _Api api, {
  String office = 'ACC',
  double width = 400,
  double scale = 1,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth(api, office);
  final router = GoRouter(
    initialLocation: '/admin/reports',
    routes: [
      GoRoute(
        path: '/admin/reports',
        builder: (_, _) => const Scaffold(body: AdminReportsScreen()),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildSmartflowTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _chip(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is ChoiceChip &&
      widget.label is Text &&
      ((widget.label as Text).data ?? '').startsWith(label),
);

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 100,
  );
  await tester.ensureVisible(finder);
  await tester.pump();
}

Future<void> _open(WidgetTester tester, String section) async {
  final chip = _chip(section);
  await _show(tester, chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(_chip(label)).selected;

void main() {
  testWidgets(
    'the page has the same parts as the web: Overview, Departments, Register and Exceptions',
    (tester) async {
      await _mount(tester, _Api());
      await _show(tester, _chip('Overview'));
      expect(_selected(tester, 'Overview'), isTrue);
      expect(_chip('Departments'), findsOneWidget);
      expect(_chip('Register'), findsOneWidget);
      expect(_chip('Exceptions'), findsOneWidget);
      expect(find.text('Compliance rates'), findsOneWidget);
      expect(find.text('On time / in process'), findsOneWidget);
      expect(find.text('Awaiting receipt'), findsOneWidget);
      expect(find.text('Late receipt'), findsOneWidget);
      expect(find.text('Delayed'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('figures the report did not provide are dashes, never zero', (
    tester,
  ) async {
    await _mount(tester, _Api()..unknownFigures = true);
    expect(find.text('Activity count not verified'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('0%'), findsNothing);
    expect(find.textContaining('0 documents with activity'), findsNothing);
    expect(
      find.textContaining(
        'outstanding transfers at cutoff · — sent before this period',
      ),
      findsOneWidget,
    );
    // Without completion and timing data the card is not drawn at all (an older API).
    expect(find.text('Completion and time at offices'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Overview shows completion, time at offices and the counting note in the web wording',
    (tester) async {
      await _mount(tester, _Api());
      expect(
        find.text('4 documents with activity · municipal system'),
        findsOneWidget,
      );
      expect(
        find.text(
          '1 outstanding transfers at cutoff · 1 sent before this period',
        ),
        findsOneWidget,
      );
      await _show(tester, find.text('Completion and time at offices'));
      expect(find.text('Trail completion'), findsOneWidget);
      expect(find.text('3 of 4 folders · 75%'), findsOneWidget);
      expect(find.text('Average time at an office'), findsOneWidget);
      expect(
        find.text(
          '60 h (2.5 days) before forwarding · 5 forwarded, 2 still at the office',
        ),
        findsOneWidget,
      );
      await _show(tester, find.text('By office'));
      expect(find.text('Office totals'), findsNothing);
      expect(
        find.text('4 folders with activity · avg 5 h before forwarding'),
        findsOneWidget,
      );
      expect(
        find.text('3 folders with activity · none forwarded'),
        findsOneWidget,
      );
      expect(find.text('2 folders with activity'), findsOneWidget);
      expect(find.textContaining('documents with movement'), findsNothing);
      await _show(tester, find.text('How these numbers are counted'));
      await tester.tap(find.text('How these numbers are counted'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('72 calendar hours after sending'),
        findsOneWidget,
      );
      expect(
        find.textContaining('missing receipts after 24 hours'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a summary tile opens the folder register on that classification', (
    tester,
  ) async {
    final api = _Api();
    await _mount(tester, api);
    expect(api.registerQueries.last['classification'], 'all');
    await _show(tester, find.text('Awaiting receipt'));
    await tester.tap(find.text('Awaiting receipt'));
    await tester.pumpAndSettle();
    expect(_selected(tester, 'Register'), isTrue);
    expect(api.registerQueries.last['classification'], 'unforwarded');
    expect(api.registerQueries.last['scope'], 'activity');
    expect(find.text('Folder register'), findsOneWidget);
    expect(find.text('Awaiting receipt'), findsWidgets);
    // Opening it from another tile replaces the earlier choice instead of stacking filters.
    await _show(tester, _chip('Overview'));
    await tester.tap(_chip('Overview'));
    await tester.pumpAndSettle();
    await _show(tester, find.text('Late receipt'));
    await tester.tap(find.text('Late receipt'));
    await tester.pumpAndSettle();
    expect(api.registerQueries.last['classification'], 'delayed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('only an Accounting administrator sees Exceptions', (
    tester,
  ) async {
    final other = _Api();
    await _mount(tester, other, office: 'BUD');
    await _show(tester, _chip('Overview'));
    expect(_chip('Exceptions'), findsNothing);
    expect(find.textContaining('Audit exceptions'), findsNothing);
    expect(other.exceptionCalls, 0);

    final accounting = _Api();
    await _mount(tester, accounting, office: 'ACC');
    await _open(tester, 'Exceptions');
    expect(accounting.exceptionCalls, 1);
    expect(find.textContaining('Audit exceptions ·'), findsOneWidget);
    expect(
      find.textContaining('incomplete DV contents'),
      findsOneWidget,
      reason: 'the explanation matches the web wording',
    );
    expect(find.text('Unforwarded OUT'), findsOneWidget);
    expect(find.text('Unreceived transfer evidence'), findsOneWidget);
    expect(find.textContaining('skipped Budget/Accounting'), findsNothing);
  });

  testWidgets(
    'Departments is read only when opened, and shows the same comparison as the web',
    (tester) async {
      final api = _Api();
      await _mount(tester, api);
      expect(
        api.departmentMonths,
        isEmpty,
        reason: 'nothing is requested until the part is opened',
      );
      await _open(tester, 'Departments');
      expect(api.departmentMonths, [6]);
      expect(find.text('Department performance'), findsOneWidget);
      expect(
        find.textContaining(
          'May 2026 to October 2026 · each month is measured at its own end · 27 office visits in total',
        ),
        findsOneWidget,
      );
      expect(find.text('Recurring bottleneck'), findsWidgets);
      expect(
        find.textContaining(
          'Treasury Office (TRE): slow in 4 of 6 months · 42.3% of visits late',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('The dashed line is the 24 h default desk limit'),
        findsOneWidget,
      );
      expect(find.text('All offices'), findsOneWidget);
      expect(
        find.text(
          '15.3 h on average before forwarding · 27 visits · 8 late (29.6%)',
        ),
        findsOneWidget,
      );
      // Slowest office first (the one with a recurring bottleneck), then by average, empty offices last.
      final order = [
        'Treasury Office',
        'Engineering Office',
        'Human Resources',
      ].map((name) => tester.getTopLeft(find.text(name)).dy).toList();
      expect(order, [...order]..sort());
      expect(find.text('No folder forwarded yet'), findsNothing);
      expect(find.text('No office visits in this window'), findsOneWidget);
      expect(find.text('Slower by 32.5 h (40 h → 72.5 h)'), findsOneWidget);
      expect(
        find.text('Not enough forwarded folders to show a trend'),
        findsOneWidget,
      );
      await tester.tap(find.text('12 months'));
      await tester.pumpAndSettle();
      expect(api.departmentMonths, [6, 12]);
      // Leaving and coming back keeps what was read; it is not requested again.
      await _open(tester, 'Overview');
      await _open(tester, 'Departments');
      expect(api.departmentMonths, [6, 12]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed department read never claims a comparison it could not verify',
    (tester) async {
      final api = _Api();
      await _mount(tester, api);
      await _open(tester, 'Departments');
      expect(find.text('Treasury Office'), findsWidgets);
      api.failDepartments = true;
      // The same window refreshes: the earlier view stays, labelled as possibly out of date.
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      await _open(tester, 'Departments');
      expect(
        find.textContaining('Department performance refresh failed.'),
        findsOneWidget,
      );
      expect(find.textContaining('it may be out of date'), findsOneWidget);
      expect(find.text('Treasury Office'), findsWidgets);
      // Another window is never shown from an earlier read: it is unavailable with a working retry.
      await tester.tap(find.text('3 months'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Department performance unavailable.'),
        findsOneWidget,
      );
      expect(find.textContaining('could not be verified'), findsOneWidget);
      expect(find.text('Treasury Office'), findsNothing);
      expect(find.text('No office visits in this window'), findsNothing);
      api.failDepartments = false;
      await tester.tap(find.text('Retry department performance'));
      await tester.pumpAndSettle();
      expect(find.text('Treasury Office'), findsWidgets);
      expect(find.textContaining('unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the department bars fit 320px with doubled text', (
    tester,
  ) async {
    final api = _Api();
    await _mount(tester, api, width: 320, scale: 2);
    await _open(tester, 'Departments');
    await _show(tester, find.text('Treasury Office'));
    expect(find.text('Treasury Office'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
