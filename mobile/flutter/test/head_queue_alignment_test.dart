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
import 'package:smartflow/screens/head/head_shell.dart';
import 'package:smartflow/screens/head/head_widgets.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/utils/head_queue.dart';

// The phone head queue behaves like the web one (web/test/head-queue.test.mjs): the same cases, the same answers.

Map<String, dynamic> _item(
  String id,
  String status,
  num hours, {
  String lastStatus = 'IN',
  String meta = '',
}) => {
  'document_id': id,
  'title': 'Folder $id',
  'status_label': status,
  'last_status': lastStatus,
  'meta': meta,
  'hours_pending': hours,
};

final _sample = [
  _item('DOC-A', 'completed', 10),
  _item('DOC-B', 'in_office', 30),
  _item('DOC-C', 'overdue', 5),
  _item(
    'DOC-D',
    'on_time',
    12,
    lastStatus: 'OUT',
    meta: 'Forwarded from ACC · awaiting receive scan',
  ),
  _item('DOC-E', 'overdue', 70),
  _item('DOC-F', 'completed', 200),
  _item('DOC-G', 'in_office', 90),
];

List<String> _ids(Iterable<Map> list) => [
  for (final row in list) '${row['document_id']}',
];

void main() {
  group('queue rules (same cases as the web)', () {
    test(
      'the default view leaves out finished folders and puts overdue first, longest wait first',
      () {
        expect(_ids(filterQueue(_sample)), [
          'DOC-E',
          'DOC-C',
          'DOC-G',
          'DOC-B',
          'DOC-D',
        ]);
      },
    );

    test(
      'completed folders have their own view, newest first, and All still reaches everything',
      () {
        expect(_ids(filterQueue(_sample, filter: 'completed')), [
          'DOC-A',
          'DOC-F',
        ]);
        expect(filterQueue(_sample, filter: 'all'), hasLength(_sample.length));
        expect(_ids(filterQueue(_sample, filter: 'all')).sublist(5), [
          'DOC-A',
          'DOC-F',
        ]);
      },
    );

    test(
      'Overdue, In office and Awaiting receive keep their earlier meaning',
      () {
        expect(_ids(filterQueue(_sample, filter: 'overdue')), [
          'DOC-E',
          'DOC-C',
        ]);
        expect(_ids(filterQueue(_sample, filter: 'in_office')), [
          'DOC-G',
          'DOC-B',
        ]);
        expect(_ids(filterQueue(_sample, filter: 'awaiting')), ['DOC-D']);
      },
    );

    test(
      'an overdue folder that is also waiting for a receive scan stays under both filters, shown as overdue',
      () {
        final both = _item(
          'DOC-H',
          'overdue',
          8,
          lastStatus: 'OUT',
          meta: 'Document due Oct 20 · awaiting receive scan',
        );
        expect(headQueueState(both), HeadQueueState.overdue);
        expect(_ids(filterQueue([both], filter: 'overdue')), ['DOC-H']);
        expect(_ids(filterQueue([both], filter: 'awaiting')), ['DOC-H']);
      },
    );

    test('the other sort orders still work', () {
      expect(
        _ids(filterQueue(_sample, filter: 'all', sort: 'hoursDesc')).first,
        'DOC-F',
      );
      expect(
        _ids(filterQueue(_sample, filter: 'all', sort: 'hoursAsc')).first,
        'DOC-C',
      );
      expect(_ids(filterQueue(_sample, filter: 'all', sort: 'id')), [
        'DOC-A',
        'DOC-B',
        'DOC-C',
        'DOC-D',
        'DOC-E',
        'DOC-F',
        'DOC-G',
      ]);
    });

    test('folders that tie keep the order the server sent them in', () {
      final tied = [
        _item('DOC-2', 'in_office', 5),
        _item('DOC-1', 'in_office', 5),
        _item('DOC-3', 'in_office', 5),
      ];
      expect(_ids(filterQueue(tied)), ['DOC-2', 'DOC-1', 'DOC-3']);
    });

    test(
      'search matches the tracking ID or the title in the chosen view only',
      () {
        expect(_ids(filterQueue(_sample, query: 'doc-e')), ['DOC-E']);
        expect(_ids(filterQueue(_sample, query: 'DOC-F')), isEmpty);
        expect(
          _ids(filterQueue(_sample, query: 'folder doc-f', filter: 'all')),
          ['DOC-F'],
        );
      },
    );

    test('counts per view match what each view lists', () {
      final counts = queueCounts(_sample);
      expect(counts, {
        'active': 5,
        'overdue': 2,
        'in_office': 2,
        'awaiting': 1,
        'completed': 2,
        'all': 7,
      });
      for (final filter in counts.keys) {
        expect(
          filterQueue(_sample, filter: filter),
          hasLength(counts[filter]!),
        );
      }
    });

    test(
      'long waits read in days, short ones in hours, and completed folders never say "waiting"',
      () {
        expect(queueSpanLabel(0), '');
        expect(queueSpanLabel(5), '5h');
        expect(queueSpanLabel(47), '47h');
        expect(queueSpanLabel(48), '2d');
        expect(queueSpanLabel(99), '4d 3h');
        expect(queueWaitLabel(_item('X', 'in_office', 96)), '4d waiting');
        expect(queueWaitLabel(_item('X', 'in_office', 0)), 'Just recorded');
        expect(
          queueWaitLabel(_item('X', 'completed', 3888)),
          'Completed 162d ago',
        );
        expect(
          queueWaitLabel(_item('X', 'completed', 0)),
          'Completed just now',
        );
        expect(
          queueWaitLabel(_item('X', 'completed', 30)),
          isNot(contains('waiting')),
        );
      },
    );
  });

  group('the queue screen', () {
    late List<Map<String, dynamic>> rows;

    setUp(() {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      rows = List.of(_sample);
    });

    Future<void> mount(
      WidgetTester tester, {
      SfHeadQueueFilter? filter,
      double height = 2000,
    }) async {
      tester.view.physicalSize = Size(390, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = MockClient((request) async {
        expect(request.url.pathSegments.last, 'head-dashboard.php');
        return http.Response(
          jsonEncode({'queue': rows}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final auth = _Auth(SmartflowApi(ApiClient(client: client)));
      addTearDown(auth.dispose);
      final router = GoRouter(
        initialLocation: '/head/queue',
        routes: [
          GoRoute(
            path: '/head/queue',
            builder: (_, _) =>
                Scaffold(body: HeadQueueScreen(initialFilter: filter)),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp.router(
            theme: buildSmartflowTheme().copyWith(
              platform: TargetPlatform.windows,
            ),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // The view chips scroll sideways, so bring one into view before tapping it.
    Future<void> tapView(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    SfHeadQueueFilter selected(WidgetTester tester) => tester
        .widget<SfHeadQueueFilterChips>(find.byType(SfHeadQueueFilterChips))
        .selected;

    testWidgets(
      'it opens on Active, leaves out finished folders and counts every view',
      (tester) async {
        await mount(tester);
        expect(selected(tester), SfHeadQueueFilter.active);
        expect(find.text('Active documents'), findsOneWidget);
        expect(find.text('5 of 7'), findsOneWidget);
        expect(find.text('Folder DOC-E'), findsOneWidget);
        expect(find.text('Folder DOC-A'), findsNothing);
        expect(find.text('Folder DOC-F'), findsNothing);
        for (final label in [
          'Active (5)',
          'Overdue (2)',
          'In office (2)',
          'Awaiting receive (1)',
          'Completed (2)',
          'All',
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.text('All (7)'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Needs attention comes first and each card shows one state with its wait in days',
      (tester) async {
        rows = [
          _item('DOC-OK', 'in_office', 96),
          _item('DOC-LATE', 'overdue', 3),
        ];
        await mount(tester);
        final late = tester.getTopLeft(find.text('Folder DOC-LATE')).dy;
        final ok = tester.getTopLeft(find.text('Folder DOC-OK')).dy;
        expect(late, lessThan(ok), reason: 'overdue first, whatever its wait');
        expect(find.text('Overdue'), findsOneWidget);
        expect(find.text('In office'), findsWidgets);
        expect(find.text('4d waiting'), findsOneWidget);
        expect(find.text('3h waiting'), findsOneWidget);
        expect(find.text('96h'), findsNothing);
        expect(find.text('Needs attention first'), findsOneWidget);
        expect(find.text('Tracking ID'), findsOneWidget);
      },
    );

    testWidgets(
      'Completed lists finished folders, newest first, and never says waiting',
      (tester) async {
        await mount(tester);
        await tapView(tester, 'Completed (2)');
        expect(selected(tester), SfHeadQueueFilter.completed);
        expect(find.text('Completed documents'), findsOneWidget);
        expect(find.text('Folder DOC-A'), findsOneWidget);
        expect(find.text('Folder DOC-F'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Folder DOC-A')).dy,
          lessThan(tester.getTopLeft(find.text('Folder DOC-F')).dy),
        );
        expect(find.text('Completed 10h ago'), findsOneWidget);
        expect(find.text('Completed 8d 8h ago'), findsOneWidget);
        expect(find.textContaining(' waiting'), findsNothing);
        expect(find.text('Folder DOC-E'), findsNothing);
      },
    );

    testWidgets(
      'a long queue shows one page, then more on request, and starts again when the view changes',
      (tester) async {
        rows = [
          for (var i = 1; i <= 45; i++)
            _item(
              'DOC-${i.toString().padLeft(3, '0')}',
              i <= 40 ? 'in_office' : 'completed',
              i,
            ),
        ];
        await mount(tester, height: 9000);
        expect(find.text('Active (40)'), findsOneWidget);
        expect(find.text('Showing 20 of 40'), findsOneWidget);
        expect(find.text('Show 20 more'), findsOneWidget);
        expect(
          find.byType(SfHeadQueueRow, skipOffstage: false),
          findsNWidgets(20),
        );
        await tester.ensureVisible(find.text('Show 20 more'));
        await tester.tap(find.text('Show 20 more'));
        await tester.pumpAndSettle();
        expect(
          find.byType(SfHeadQueueRow, skipOffstage: false),
          findsNWidgets(40),
        );
        expect(find.textContaining('Showing'), findsNothing);
        expect(find.text('Show 20 more'), findsNothing);
        await tapView(tester, 'Completed (5)');
        expect(
          find.byType(SfHeadQueueRow, skipOffstage: false),
          findsNWidgets(5),
        );
        await tapView(tester, 'Active (40)');
        expect(find.text('Showing 20 of 40'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'with only finished folders the default view says so and points to Completed',
      (tester) async {
        rows = [_item('DOC-1', 'completed', 4)];
        await mount(tester);
        expect(find.text('No active documents'), findsOneWidget);
        expect(
          find.text('Finished folders are under Completed.'),
          findsOneWidget,
        );
        expect(find.byType(SfHeadQueueRow), findsNothing);
        await tester.ensureVisible(find.text('Show completed'));
        await tester.tap(find.text('Show completed'));
        await tester.pumpAndSettle();
        expect(selected(tester), SfHeadQueueFilter.completed);
        expect(find.text('Folder DOC-1'), findsOneWidget);
      },
    );

    testWidgets(
      'a search that misses in one view offers to search every folder',
      (tester) async {
        await mount(tester);
        await tester.enterText(find.byType(TextField), 'doc-f');
        await tester.pumpAndSettle();
        expect(find.text('No matching documents'), findsOneWidget);
        expect(
          find.text('Nothing matches “doc-f” in this view.'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Search all folders'));
        await tester.tap(find.text('Search all folders'));
        await tester.pumpAndSettle();
        expect(selected(tester), SfHeadQueueFilter.all);
        expect(find.text('Folder DOC-F'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'doc-f',
          reason: 'the search itself is kept',
        );
      },
    );

    testWidgets(
      'a deep link opens the view it names, and the old names still work',
      (tester) async {
        expect(
          HeadQueueScreen.parseFilter('forwarded'),
          SfHeadQueueFilter.forwarded,
        );
        expect(
          HeadQueueScreen.parseFilter('awaiting'),
          SfHeadQueueFilter.forwarded,
        );
        expect(
          HeadQueueScreen.parseFilter('in_office'),
          SfHeadQueueFilter.inOffice,
        );
        expect(
          HeadQueueScreen.parseFilter('overdue'),
          SfHeadQueueFilter.overdue,
        );
        expect(
          HeadQueueScreen.parseFilter('completed'),
          SfHeadQueueFilter.completed,
        );
        expect(HeadQueueScreen.parseFilter('nothing'), isNull);
        await mount(tester, filter: SfHeadQueueFilter.overdue);
        expect(selected(tester), SfHeadQueueFilter.overdue);
        expect(find.text('Overdue documents'), findsOneWidget);
        expect(find.text('Folder DOC-E'), findsOneWidget);
        expect(find.text('Folder DOC-B'), findsNothing);
      },
    );
  });
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final SmartflowApi fixture;
  @override
  SmartflowApi get api => fixture;
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get user => const AppUser(
    id: 21,
    name: 'Sample department head',
    username: 'sample.head',
    role: 'head',
    officeId: 2,
    officeName: 'Budget Office',
    officeCode: 'BUD',
  );
}
