import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/utils/office_rules.dart';

// The phone Offices and Alert time limits pages read the same limits as the web Offices and Thresholds pages.

Map<String, dynamic> _offices() => {
  'offices': [
    {
      'office_id': 1,
      'office_name': 'Engineering Office',
      'office_code': 'ENG',
      'thresholds': [],
    },
    {
      'office_id': 4,
      'office_name': 'Accounting Office',
      'office_code': 'ACC',
      'thresholds': [
        // An older rule saved before receipt limits existed: the key is there, the value is not.
        {
          'document_type': 'Approved Budget',
          'max_hours': 72,
          'out_unconfirmed_hours': null,
        },
        {
          'document_type': 'Disbursement Voucher',
          'max_hours': 48,
          'out_unconfirmed_hours': 12,
        },
      ],
    },
    {
      'office_id': 5,
      'office_name': 'Treasury Office',
      'office_code': 'TRE',
      // And one that never had the key at all.
      'thresholds': [
        {'document_type': 'Others: Folder', 'max_hours': 36},
      ],
    },
  ],
};

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  bool fail = false;
  bool empty = false;
  int reads = 0;

  @override
  Future<Map<String, dynamic>> adminOffices() async {
    reads++;
    if (fail) throw ApiException('Sample offices read failure');
    return empty ? {'offices': []} : _offices();
  }
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final _Api fixture;
  @override
  SmartflowApi get api => fixture;
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get user => const AppUser(
    id: 101,
    name: 'Report reviewer',
    username: 'report.reviewer',
    role: 'admin',
    officeId: 4,
    officeName: 'Accounting Office',
    officeCode: 'ACC',
  );
}

Future<GoRouter> _mount(
  WidgetTester tester,
  _Api api, {
  double width = 390,
  double scale = 1,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth(api);
  addTearDown(auth.dispose);
  final router = GoRouter(
    initialLocation: '/admin/offices',
    routes: [
      GoRoute(
        path: '/admin/offices',
        builder: (_, _) => const Scaffold(body: AdminOfficesScreen()),
      ),
      GoRoute(
        path: '/admin/thresholds',
        builder: (_, state) => Scaffold(
          body: AdminThresholdsScreen(
            initialOfficeId: int.tryParse(
              state.uri.queryParameters['office'] ?? '',
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
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
  return router;
}

Future<void> _refresh(WidgetTester tester) async {
  await tester
      .widget<RefreshIndicator>(find.byType(RefreshIndicator))
      .onRefresh();
  await tester.pumpAndSettle();
}

void main() {
  test('a rule without a receipt limit uses the 24 hour default', () {
    expect(ruleReceiptHours({'out_unconfirmed_hours': 12}), 12);
    expect(ruleReceiptHours({'out_unconfirmed_hours': '36'}), 36);
    expect(ruleReceiptHours({'out_unconfirmed_hours': null}), 24);
    expect(ruleReceiptHours({'max_hours': 48}), 24);
    expect(
      ruleSummary({'max_hours': 48, 'out_unconfirmed_hours': null}),
      '48 hours at the office · 24 hours to record receipt after sending',
    );
  });

  testWidgets('Offices words every limit in full and never prints "null"', (
    tester,
  ) async {
    await _mount(tester, _Api());
    expect(find.text('Engineering Office'), findsOneWidget);
    expect(find.text('No custom alert rules configured.'), findsOneWidget);
    expect(
      find.text(
        '72 hours at the office · 24 hours to record receipt after sending',
      ),
      findsOneWidget,
      reason: 'a saved rule with no receipt limit uses the 24 hour default',
    );
    expect(
      find.text(
        '48 hours at the office · 12 hours to record receipt after sending',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '36 hours at the office · 24 hours to record receipt after sending',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('null'), findsNothing);
    expect(find.textContaining('awaiting receipt'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'each office has Edit limits or Add limits, and opens its own limits',
    (tester) async {
      final router = await _mount(tester, _Api());
      expect(find.text('Add limits'), findsOneWidget);
      expect(find.text('Edit limits'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('Add limits for Engineering Office'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Edit limits for Treasury Office'),
        findsOneWidget,
      );
      await tester.tap(find.text('Edit limits').last);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/admin/thresholds?office=5');
      expect(find.text('Alert time limits'), findsOneWidget);
      // The Treasury Office is the one selected, with its rule and the default receipt limit filled in.
      expect(find.text('Treasury Office (TRE)'), findsOneWidget);
      expect(find.text('Engineering Office (ENG)'), findsNothing);
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Document type'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((f) => f.controller!.text),
        ['Others: Folder', '36', '24'],
      );
      expect(find.textContaining('null'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an unknown office in the link falls back to the first office', (
    tester,
  ) async {
    final router = await _mount(tester, _Api());
    router.go('/admin/thresholds?office=999');
    await tester.pumpAndSettle();
    expect(find.text('Engineering Office (ENG)'), findsOneWidget);
    router.go('/admin/thresholds');
    await tester.pumpAndSettle();
    expect(find.text('Engineering Office (ENG)'), findsOneWidget);
  });

  testWidgets(
    'Refresh offices reads again and says when the rules were last read',
    (tester) async {
      final api = _Api();
      await _mount(tester, api);
      expect(api.reads, 1);
      expect(find.textContaining('Updated Just now'), findsOneWidget);
      await tester.tap(find.text('Refresh offices'));
      await tester.pumpAndSettle();
      expect(api.reads, 2);
      expect(find.textContaining('Updated Just now'), findsOneWidget);
      expect(find.text('Engineering Office'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed refresh keeps the earlier rules, labelled as possibly out of date, until Retry works',
    (tester) async {
      final api = _Api();
      await _mount(tester, api);
      api.fail = true;
      await _refresh(tester);
      expect(find.textContaining('Office refresh failed.'), findsOneWidget);
      expect(
        find.textContaining(
          'Previously loaded office rules may be out of date.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Last successful update'), findsOneWidget);
      expect(find.text('Engineering Office'), findsOneWidget);
      expect(find.text('No offices configured'), findsNothing);
      api.fail = false;
      await tester.tap(find.text('Retry offices'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Office refresh failed.'), findsNothing);
      expect(find.textContaining('Last successful update'), findsNothing);
      expect(find.textContaining('Updated Just now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a first read that fails is unavailable, never an empty list of offices',
    (tester) async {
      final api = _Api()..fail = true;
      await _mount(tester, api);
      expect(find.textContaining('Offices unavailable.'), findsOneWidget);
      expect(find.text('Retry offices'), findsOneWidget);
      expect(find.text('No offices configured'), findsNothing);
      expect(find.text('Edit limits'), findsNothing);
      api.fail = false;
      await tester.tap(find.text('Retry offices'));
      await tester.pumpAndSettle();
      expect(find.text('Engineering Office'), findsOneWidget);
    },
  );

  testWidgets(
    'office cards and their Edit limits fit 320px with doubled text',
    (tester) async {
      await _mount(tester, _Api(), width: 320, scale: 2);
      expect(find.text('Edit limits'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Treasury Office'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a verified empty list says no offices are configured', (
    tester,
  ) async {
    await _mount(tester, _Api()..empty = true);
    expect(find.text('No offices configured'), findsOneWidget);
    expect(find.textContaining('Offices unavailable.'), findsNothing);
  });
}
