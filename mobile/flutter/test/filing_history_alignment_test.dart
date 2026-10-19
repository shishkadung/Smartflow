import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/staff/clerk_widgets.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/widgets/document_journey.dart';
import 'package:smartflow/widgets/folder_contents.dart';

const _receipt = {
  'status': 'incomplete',
  'registered_total_pages': 8,
  'total_pages': 7,
  'reason': 'The signed appendix was missing at this receipt.',
};

const _movements = [
  {
    'id': 92,
    'status': 'IN',
    'office_name': 'Records Office',
    'user_name': 'Synthetic receiver',
    'scanned_at': '2026-10-18 11:00:00',
    'contents_receipt': _receipt,
  },
  {
    'id': 91,
    'status': 'OUT',
    'office_name': 'Engineering Office',
    'destination_office_name': 'Records Office',
    'user_name': 'Synthetic sender',
    'scanned_at': '2026-10-18 10:00:00',
    'destination_corrections': [
      {
        'id': 6,
        'corrected_at': '2026-10-18 10:05:00',
        'previous_destination_office_name': 'Budget Office',
        'destination_office_name': 'Records Office',
        'corrected_by_name': 'Synthetic sender',
        'corrected_by_office_name': 'Engineering Office',
        'reason': 'Corrected the receiving office recording.',
      },
    ],
  },
];

Map<String, dynamic> _document({Object? filed}) => {
  'id': 'DOC-2026-000999',
  'title': 'Synthetic filing history folder',
  'type': 'Others: Records',
  'current_status': 'IN',
  'current_office_name': 'Records Office',
  'trail_complete': filed != null,
  'filed_by': filed,
  'registered_by': {
    'registered_at': '2026-10-18 08:00:00',
    'name': 'Synthetic registrar',
    'office_name': 'Engineering Office',
  },
  'linked_requests': [
    {
      'id': 17,
      'created_at': '2026-10-18 07:00:00',
      'user_name': 'Synthetic requester',
      'office_name': 'Records Office',
      'purpose':
          'Retain the full request purpose in the chronological history.',
    },
  ],
};

const _filing = {
  'filed_at': '2026-10-18 11:30:00',
  'user_id': 25,
  'name': 'Synthetic filing staff',
  'office_name': 'Records Office',
};

class _HistoryApi extends SmartflowApi {
  _HistoryApi(this.document, {this.movements = _movements})
    : super(
        ApiClient(
          client: MockClient((_) async {
            throw StateError('Unexpected HTTP in isolated History fixture');
          }),
        ),
      );

  final Map<String, dynamic> document;
  final List<Map<String, dynamic>> movements;

  @override
  Future<Map<String, dynamic>> documentShow(String id) async => {
    'document': document,
  };

  @override
  Future<Map<String, dynamic>> documentMovements(String id) async => {
    'movements': movements,
  };

  @override
  Future<Map<String, dynamic>> officeMovements(
    int officeId, {
    String? date,
    String? status,
    int page = 1,
    int pageSize = 25,
  }) async => {
    'movements': [],
    'stats': {'total': 0, 'in_flow': 0, 'out_flow': 0},
    'total': 0,
    'page': 1,
    'page_size': 25,
    'has_more': false,
  };
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final _HistoryApi fixture;

  @override
  SmartflowApi get api => fixture;

  @override
  bool get isAuthenticated => true;

  @override
  AppUser get user => AppUser(
    id: 25,
    username: 'synthetic-history-reviewer',
    name: 'Synthetic filing staff',
    role: 'staff',
    officeId: 7,
    officeCode: 'REC',
    officeName: 'Records Office',
  );
}

final _captureKey = GlobalKey();
const _capture = bool.fromEnvironment('CAPTURE_MOBILE_FLOW_HISTORY');

Future<void> _mountHistory(
  WidgetTester tester,
  Map<String, dynamic> document, {
  List<Map<String, dynamic>> movements = _movements,
  double width = 390,
  double height = 2400,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: StaffHistoryScreen(
            initialDocumentId: 'DOC-2026-000999',
            monitorOnly: true,
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  var theme = buildSmartflowTheme();
  if (_capture) {
    final data = ByteData.sublistView(
      File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
    );
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
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'ReviewSans'),
    );
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(_HistoryApi(document, movements: movements)),
      child: RepaintBoundary(
        key: _captureKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: theme,
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

Future<void> _captureHistory(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '../../.runtime/mobile-flow-alignment-2026-10-19/history-$name.png',
    );
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
    'filing joins the chronological history without adding scans or receipts',
    (tester) async {
      await _mountHistory(tester, _document(filed: _filing));
      final stops = tester
          .widgetList<SfTrailStop>(find.byType(SfTrailStop))
          .toList();
      expect(stops.map((event) => event.title), [
        'Retain the full request purpose in the chronological history.',
        'Registered at Engineering Office',
        'Sent to Records Office',
        'Destination corrected: Budget Office → Records Office',
        'Received at Records Office',
        'Filed at Records Office',
      ]);
      expect(stops.last.personName, 'Synthetic filing staff');
      expect(stops.last.when, '11:30 AM');
      expect(stops.last.note, 'Folder filed. The route is finished.');
      expect(stops.last.isLast, isTrue);
      expect(find.text('2 scans'), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.byType(FolderReceiptSummary), findsOneWidget);
      expect(find.text(_receipt['reason'] as String), findsOneWidget);
      expect(
        find.text('8 registered pages · 7 received pages'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filing uses its recorded time rather than always appending to history',
    (tester) async {
      await _mountHistory(
        tester,
        _document(filed: {..._filing, 'filed_at': '2026-10-18 10:15:00'}),
      );
      final stops = tester
          .widgetList<SfTrailStop>(find.byType(SfTrailStop))
          .toList();
      expect(stops[4].title, 'Filed at Records Office');
      expect(stops[4].when, '10:15 AM');
      expect(stops.last.title, 'Received at Records Office');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy filing keeps the timestamp and honestly names the unknown filer',
    (tester) async {
      await _mountHistory(
        tester,
        _document(
          filed: {
            'filed_at': '2026-10-18 11:30:00',
            'user_id': null,
            'name': null,
            'office_name': null,
          },
        ),
      );
      expect(find.text('Filed'), findsOneWidget);
      expect(find.text('Staff (name not recorded)'), findsOneWidget);
      final filed = tester
          .widgetList<SfTrailStop>(find.byType(SfTrailStop))
          .last;
      expect(filed.when, '11:30 AM');
      expect(filed.avatarUrl, isNull);
      expect(filed.personDetail, isNull);
      expect(find.text('2 scans'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final completed in [false, true]) {
    testWidgets(
      'no filing event is invented for ${completed ? 'computed DV completion' : 'an active folder'}',
      (tester) async {
        await _mountHistory(tester, {
          ..._document(),
          'type': completed ? 'Disbursement Voucher' : 'Others: Records',
          'trail_complete': completed,
          'tray': completed ? 'completed' : 'in_office',
        });
        expect(find.textContaining('Filed'), findsNothing);
        expect(find.text('Folder filed. The route is finished.'), findsNothing);
        expect(find.byType(SfTrailStop), findsNWidgets(5));
        expect(find.text('2 scans'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a partial filing identity without a recorded filing time adds no event',
    (tester) async {
      await _mountHistory(
        tester,
        _document(
          filed: {
            'name': 'Synthetic filing staff',
            'office_name': 'Records Office',
            'filed_at': '   ',
          },
        ),
      );
      expect(find.textContaining('Filed'), findsNothing);
      expect(find.byType(SfTrailStop), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'movement filters still select scans alone and All restores filing',
    (tester) async {
      await _mountHistory(tester, _document(filed: _filing));
      await tester.tap(find.widgetWithText(FilterChip, 'Received (1)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Filed'), findsNothing);
      expect(find.byType(SfTrailStop), findsOneWidget);
      expect(find.text('Received at Records Office'), findsOneWidget);
      expect(find.byType(FolderReceiptSummary), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Sent (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Sent (1)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Filed'), findsNothing);
      expect(find.byType(FolderReceiptSummary), findsNothing);
      expect(find.text('Sent to Records Office'), findsOneWidget);
      expect(
        find.text('Corrected the receiving office recording.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'All (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'All (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Filed at Records Office'), findsOneWidget);
      expect(find.text('2 scans'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final sample in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'long filing identity remains usable at ${sample.$1.toInt()}px and ${sample.$2}x text',
      (tester) async {
        const office = 'Municipal Records and Inter-office Coordination Office';
        const person = 'Synthetic Alexandra Longname Records Reviewer';
        await _mountHistory(
          tester,
          {
            ..._document(
              filed: {..._filing, 'name': person, 'office_name': office},
            ),
            'registered_by': null,
            'linked_requests': [],
            'title': 'Synthetic municipal filing history',
            'current_office_name': office,
          },
          movements: [_movements.first],
          width: sample.$1,
          height: 844,
          scale: sample.$2,
        );
        final filed = find.widgetWithText(SfTrailStop, 'Filed at $office');
        await tester.scrollUntilVisible(
          filed,
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(filed);
        await tester.pumpAndSettle();
        expect(find.text(person), findsOneWidget);
        expect(
          find.text('Folder filed. The route is finished.'),
          findsOneWidget,
        );
        expect(
          tester.getRect(find.text('Filed at $office')).right,
          lessThanOrEqualTo(sample.$1),
        );
        expect(tester.takeException(), isNull);
        await _captureHistory(
          tester,
          '${sample.$1.toInt()}-${sample.$2.toInt()}x',
        );
      },
    );
  }

  testWidgets(
    'completed DV journey does not imply an explicit filing event or ongoing timer',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DocumentJourney(
                document: {
                  'tray': 'completed',
                  'type': 'Disbursement Voucher',
                  'current_status': 'IN',
                  'current_office_name': 'Treasury Office',
                  'journey': [
                    {
                      'id': 34,
                      'status': 'IN',
                      'office_name': 'Treasury Office',
                      'user_name': 'Synthetic Treasury receiver',
                      'scanned_at': '2026-10-18 11:00:00',
                      'elapsed_hours': 5,
                      'duration_kind': 'at_office',
                      'is_current': true,
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Journey complete'), findsOneWidget);
      expect(find.textContaining('Filed'), findsNothing);
      expect(find.textContaining('ongoing'), findsNothing);
      expect(
        find.text('Contents not recorded for this receipt.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
