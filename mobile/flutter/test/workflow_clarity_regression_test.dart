import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/auth/forced_password_change_screen.dart';
import 'package:smartflow/screens/shared/documents_screen.dart';
import 'package:smartflow/screens/shared/office_checklists_screen.dart';
import 'package:smartflow/screens/staff/clerk_widgets.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/utils/recent_docs.dart';

const _first = 'DOC-2026-000801';
const _second = 'DOC-2026-000802';
const _capture = bool.fromEnvironment('CAPTURE_WORKFLOW_CLARITY');
final _captureKey = GlobalKey();
const _emptyChecklist =
    'No published checklist for this document type. Define approved attachment requirements below.';

class _Api extends SmartflowApi {
  _Api()
    : super(
        ApiClient(
          client: MockClient((_) async => throw StateError('HTTP blocked')),
        ),
      );

  final pendingDetails = Completer<Map<String, dynamic>>();
  final pendingMovements = Completer<Map<String, dynamic>>();
  bool deferDetails = false;
  bool deferMovements = false;
  bool emptyDocuments = false;
  bool failChecklists = false;
  String checklistError = 'Synthetic checklist unavailable';
  String? folderTitle;
  String? filedAt;
  final shown = <String>[];
  List<Map<String, dynamic>> checklists = [];

  Map<String, dynamic> folder(String id) => {
    'id': id,
    'title': folderTitle ?? (id == _first ? 'First folder' : 'Second folder'),
    'type': 'Approved Budget',
    'current_status': 'IN',
    'current_office_id': 4,
    'current_office_name': 'Accounting Office',
    'origin_office_name': 'Budget Office',
    'last_movement_id': 80,
    'tray': 'completed',
    'trail_complete': true,
    'filed_at': filedAt,
    'filed_by': null,
    'is_overdue': false,
    'journey': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> documentShow(String id) async {
    shown.add(id);
    if (deferDetails && id == _first) return pendingDetails.future;
    return {'document': folder(id)};
  }

  @override
  Future<Map<String, dynamic>> documentMovements(String id) async {
    if (deferMovements && id == _first) return pendingMovements.future;
    return {
      'movements': [
        {
          'id': 80,
          'document_id': id,
          'status': 'IN',
          'office_name': 'Accounting Office',
          'user_name': 'Synthetic receiver',
          'scanned_at': '2026-10-24 08:00:00',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> officeDocumentPage({
    String tray = 'incoming',
    String search = '',
    String sort = 'urgency',
    bool overdue = false,
    int limit = 50,
    int offset = 0,
  }) async => {
    'documents': emptyDocuments ? [] : [folder(_first)],
    'total': emptyDocuments ? 0 : 1,
    'has_more': false,
    'overdue_count': 0,
    'tray_counts': {
      'completed': emptyDocuments ? 0 : 1,
      'incoming': 0,
      'in_office': 0,
      'forwarded': 0,
    },
  };

  @override
  Future<Map<String, dynamic>> officeMovements(
    int officeId, {
    String? date,
    String? status,
    int page = 1,
    int pageSize = 25,
  }) async => {
    'movements': [
      {
        'id': 82,
        'document_id': _second,
        'title': 'Second folder',
        'status': 'IN',
        'scanned_at': '2026-10-24 08:00:00',
      },
    ],
    'stats': {'total': 1, 'in_flow': 1, 'out_flow': 0},
    'total': 1,
    'page': 1,
    'page_size': 25,
    'has_more': false,
  };

  @override
  Future<Map<String, dynamic>> folderChecklists() async {
    if (failChecklists) throw ApiException(checklistError);
    return {'checklists': checklists};
  }
}

class _Auth extends AuthProvider {
  _Auth(this.api, {this.head = false});
  @override
  final SmartflowApi api;
  final bool head;
  Object identity = Object();
  Future<void> Function()? onLogout;

  @override
  Object get sessionIdentity => identity;
  @override
  bool get isAuthenticated => true;
  @override
  Future<void> logout() async => onLogout?.call();
  @override
  AppUser get user => AppUser(
    id: 901,
    name: 'Synthetic reviewer',
    username: 'synthetic.reviewer',
    role: head ? 'head' : 'staff',
    officeId: 4,
    officeCode: 'ACC',
    officeName: 'Accounting Office',
  );
}

Future<_Auth> _mount(
  WidgetTester tester,
  _Api api,
  Widget screen, {
  bool head = false,
  double width = 900,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth(api, head: head);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => screen is ForcedPasswordChangeScreen
            ? screen
            : Scaffold(body: screen),
      ),
      GoRoute(path: '/login', builder: (_, _) => const Text('Login')),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    router.dispose();
    auth.dispose();
  });
  var theme = buildSmartflowTheme();
  if (_capture) {
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
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
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
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
  return auth;
}

Future<void> _captureScreen(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '../../.runtime/system-fixes-2026-10-25/mobile-$name.png',
    );
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

Future<void> _show(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 50,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _startFirst(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), _first);
  await tester.tap(find.text('Look up document'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _selectSecond(WidgetTester tester) async {
  await tester.tap(find.text('Office activity').first);
  await tester.pump();
  await _show(tester, find.text(_second));
  await tester.tap(find.text(_second));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<SfHistoryDocumentSummary>(find.byType(SfHistoryDocumentSummary))
        .doc['id'],
    _second,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final fails in [false, true]) {
    testWidgets(
      'late History ${fails ? 'failure' : 'success'} cannot replace a newer selection or its recents',
      (tester) async {
        final api = _Api()..deferDetails = true;
        await _mount(tester, api, const StaffHistoryScreen());
        await _startFirst(tester);
        await _selectSecond(tester);
        if (fails) {
          api.pendingDetails.completeError(ApiException('Old lookup failed'));
        } else {
          api.pendingDetails.complete({'document': api.folder(_first)});
        }
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SfHistoryDocumentSummary>(
                find.byType(SfHistoryDocumentSummary),
              )
              .doc['id'],
          _second,
        );
        expect(find.textContaining('Old lookup failed'), findsNothing);
        expect((await RecentDocsStore.load()).map((row) => row.id), [_second]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('superseded movement response does not dispatch a detail read', (
    tester,
  ) async {
    final api = _Api()..deferMovements = true;
    await _mount(tester, api, const StaffHistoryScreen());
    await _startFirst(tester);
    await _selectSecond(tester);
    api.pendingMovements.complete({'movements': []});
    await tester.pumpAndSettle();
    expect(api.shown, [_second]);
    expect((await RecentDocsStore.load()).map((row) => row.id), [_second]);
  });

  testWidgets('Look up another cancels a retained-folder refresh', (
    tester,
  ) async {
    final api = _Api();
    await _mount(
      tester,
      api,
      const StaffHistoryScreen(initialDocumentId: _first),
    );
    await RecentDocsStore.clear();
    api.deferDetails = true;
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final pendingRefresh = refresh.onRefresh();
    await tester.pump();
    await tester.ensureVisible(find.text('Look up another'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Look up another'));
    api.pendingDetails.complete({'document': api.folder(_first)});
    await pendingRefresh;
    await tester.pumpAndSettle();
    expect(find.byType(SfHistoryDocumentSummary), findsNothing);
    expect(find.text('Look up document'), findsOneWidget);
    expect(await RecentDocsStore.load(), isEmpty);
  });

  testWidgets(
    'a replaced login cannot publish History or save its late result',
    (tester) async {
      final api = _Api()..deferDetails = true;
      final auth = await _mount(tester, api, const StaffHistoryScreen());
      await _startFirst(tester);
      auth.identity = Object();
      api.pendingDetails.complete({'document': api.folder(_first)});
      await tester.pump();
      expect(find.byType(SfHistoryDocumentSummary), findsNothing);
      expect(await RecentDocsStore.load(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'a recents add invalidated during initialization does not persist',
    () async {
      var current = true;
      final pending = RecentDocsStore.add(_first, isCurrent: () => current);
      current = false;
      await pending;
      expect(await RecentDocsStore.load(), isEmpty);
      await RecentDocsStore.add(_second, title: 'Still per-device');
      expect((await RecentDocsStore.load()).single.title, 'Still per-device');
    },
  );

  for (final filedAt in [null, '2026-10-24 09:00:00']) {
    testWidgets(
      'completed list ${filedAt == null ? 'requires' : 'retains'} explicit filing evidence',
      (tester) async {
        final api = _Api()..filedAt = filedAt;
        await _mount(
          tester,
          api,
          const DocumentsScreen(initialTray: 'completed'),
        );
        expect(find.text('Completed'), findsWidgets);
        expect(
          find.text('Filed'),
          filedAt == null ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Route complete'),
          filedAt == null ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  testWidgets('empty completed tray does not imply every folder was filed', (
    tester,
  ) async {
    final api = _Api()..emptyDocuments = true;
    await _mount(tester, api, const DocumentsScreen(initialTray: 'completed'));
    expect(
      find.text(
        'Completed folders remain here with their QR and movement history.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Filed folders'), findsNothing);
  });

  testWidgets(
    'unavailable checklists are not empty and Retry verifies absence',
    (tester) async {
      final api = _Api()..failChecklists = true;
      await _mount(tester, api, const OfficeChecklistsScreen(), head: true);
      expect(find.textContaining('Checklists unavailable.'), findsOneWidget);
      expect(find.text(_emptyChecklist), findsNothing);
      final publish = find.widgetWithText(
        TextButton,
        'Publish attachments as checklist',
      );
      expect(tester.widget<TextButton>(publish).onPressed, isNull);
      api.failChecklists = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text(_emptyChecklist), findsOneWidget);
      expect(find.textContaining('Checklists unavailable.'), findsNothing);
      expect(tester.widget<TextButton>(publish).onPressed, isNotNull);
    },
  );

  for (final populated in [false, true]) {
    testWidgets(
      'failed checklist refresh qualifies retained ${populated ? 'rows' : 'empty data'} and Retry recovers',
      (tester) async {
        final api = _Api();
        if (populated) {
          api.checklists = [
            {
              'id': 1,
              'name': 'Approved packet',
              'document_type': 'Disbursement Voucher',
              'items': [],
            },
          ];
        }
        await _mount(tester, api, const OfficeChecklistsScreen(), head: true);
        api.failChecklists = true;
        await _show(tester, find.text('Refresh checklists'));
        await tester.tap(find.text('Refresh checklists'));
        await tester.pumpAndSettle();
        expect(find.textContaining('may be out of date'), findsOneWidget);
        expect(find.text(_emptyChecklist), findsNothing);
        if (populated) {
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, 'Use Approved packet'),
                )
                .onPressed,
            isNull,
          );
        }
        api.failChecklists = false;
        await _show(tester, find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.textContaining('may be out of date'), findsNothing);
        if (populated) {
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, 'Use Approved packet'),
                )
                .onPressed,
            isNotNull,
          );
        } else {
          expect(find.text(_emptyChecklist), findsOneWidget);
        }
      },
    );
  }

  testWidgets('late sign-out failure does not notify a replacement login', (
    tester,
  ) async {
    final auth = await _mount(
      tester,
      _Api(),
      const ForcedPasswordChangeScreen(),
    );
    final pending = Completer<void>();
    auth.onLogout = () => pending.future;
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    auth.identity = Object();
    pending.completeError(ApiException('Old logout failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not sign out'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  if (_capture) {
    for (final viewport in [(390.0, 1.0), (320.0, 2.0)]) {
      final (width, scale) = viewport;
      final suffix = '${width.toInt()}-${scale.toInt()}x';
      testWidgets('renderer completed list $suffix', (tester) async {
        final api = _Api()
          ..folderTitle =
              'Approved Budget supporting folder for drainage and road rehabilitation with a long descriptive title';
        await _mount(
          tester,
          api,
          const DocumentsScreen(initialTray: 'completed'),
          width: width,
          scale: scale,
        );
        expect(find.text('Filed'), findsNothing);
        expect(tester.takeException(), isNull);
        await _captureScreen(tester, 'completed-$suffix');
      });
      testWidgets('renderer unavailable checklist $suffix', (tester) async {
        final api = _Api()
          ..failChecklists = true
          ..checklistError =
              'Connection interrupted while checking your office requirements. Check the connection and retry to verify the published attachment names.';
        await _mount(
          tester,
          api,
          const OfficeChecklistsScreen(),
          head: true,
          width: width,
          scale: scale,
        );
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text(_emptyChecklist), findsNothing);
        expect(tester.takeException(), isNull);
        await _captureScreen(tester, 'checklist-$suffix');
      });
      testWidgets('renderer forced-password logout failure $suffix', (
        tester,
      ) async {
        final auth = await _mount(
          tester,
          _Api(),
          const ForcedPasswordChangeScreen(),
          width: width,
          scale: scale,
        );
        auth.onLogout = () async {
          throw ApiException(
            'Connection interrupted. Your sign-out could not be confirmed; try again when the connection returns.',
          );
        };
        await tester.ensureVisible(find.text('Sign out'));
        await tester.tap(find.text('Sign out'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Could not sign out.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _captureScreen(tester, 'logout-$suffix');
      });
    }
  }
}
