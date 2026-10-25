import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/shared/document_register_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:smartflow/widgets/folder_contents.dart';
import 'package:smartflow/widgets/sf_widgets.dart';

class _PolishApi extends SmartflowApi {
  _PolishApi() : super(ApiClient());
  final saved = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> checklists = [];
  @override
  Future<Map<String, dynamic>> folderChecklists() async => {
    'checklists': checklists,
  };

  @override
  Future<List<Map<String, dynamic>>> offices() async => [
    {'id': 1, 'name': 'Engineering Office', 'code': 'ENG'},
  ];

  @override
  Future<Map<String, dynamic>> findByReference(String reference) async => {
    'matches': [],
  };

  @override
  Future<Map<String, dynamic>> createDocument({
    required String title,
    required String type,
    required int originOfficeId,
    String? description,
    String? dueAt,
    String? referenceNo,
    String? payee,
    String? fundSource,
    int? receivedFromOfficeId,
    Map<String, dynamic>? folderInventory,
    int? requestId,
  }) async {
    saved.add({
      'title': title,
      'reference': referenceNo,
      'payee': payee,
      'fund': fundSource,
      'sender': receivedFromOfficeId,
      'request_id': ?requestId,
    });
    return {
      'document': {
        'id': 'DOC-2026-000201',
        'title': title,
        'type': type,
        'reference_no': referenceNo,
        'initial_in_recorded': true,
      },
    };
  }
}

class _PolishAuth extends AuthProvider {
  _PolishAuth(this.fixture, this.officeCode, this.accountId);
  final _PolishApi fixture;
  final String officeCode;
  final int accountId;
  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => AppUser(
    id: accountId,
    name: 'Test clerk',
    username: 'test.clerk',
    role: 'staff',
    officeId: officeCode == 'ACC' ? 4 : 1,
    officeName: officeCode == 'ACC'
        ? 'Accounting Office'
        : 'Engineering Office',
    officeCode: officeCode,
  );
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _enter(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(
    find.widgetWithText(SfPrimaryButton, 'Register folder'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(SfPrimaryButton, 'Register folder'));
  await tester.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester tester,
  _PolishApi api,
  String office, {
  int accountId = 201,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/staff/register',
    routes: [
      GoRoute(
        path: '/staff/register',
        builder: (_, _) =>
            const Scaffold(body: DocumentRegisterScreen(homeRoute: '/staff')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _PolishAuth(api, office, accountId),
      child: MaterialApp.router(
        theme: buildSmartflowTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Next does not submit; field errors focus and valid DV saves once',
    (tester) async {
      final api = _PolishApi();
      await _mount(tester, api, 'ENG');
      final title = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'e.g. Road repair — Phase 1',
      );
      await _enter(tester, title, 'Road repair folder');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(api.saved, isEmpty);
      expect(
        find.text('Enter the reference number from the logbook.'),
        findsNothing,
      );
      await _submit(tester);
      expect(api.saved, isEmpty);
      final reference = _field('Reference / DV no. (required)');
      expect(
        tester.widget<TextField>(reference).decoration!.errorText,
        'Enter the reference number from the logbook.',
      );
      expect(tester.widget<TextField>(reference).focusNode!.hasFocus, isTrue);
      await _enter(tester, reference, 'DV-201');
      expect(tester.widget<TextField>(reference).decoration!.errorText, isNull);
      await _enter(tester, _field('Payee (required)'), 'Test supplier');
      await _enter(tester, _field('Fund source (required)'), 'MOOE');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.saved, isEmpty);
      await _enter(tester, _field('Main document pages'), '8');
      final confirmed = find.text(
        'I physically hold this folder and counted its contents.',
      );
      await tester.ensureVisible(confirmed);
      await tester.tap(confirmed);
      await _submit(tester);
      expect(api.saved.single, {
        'title': 'Road repair folder',
        'reference': 'DV-201',
        'payee': 'Test supplier',
        'fund': 'MOOE',
        'sender': null,
      });
      expect(find.text('Document registered'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'sf_registration_draft_v1_201_1',
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Accounting requires sender before saving a DV', (tester) async {
    final api = _PolishApi();
    await _mount(tester, api, 'ACC');
    await _submit(tester);
    expect(api.saved, isEmpty);
    expect(
      find.text('Choose the office that sent this folder.'),
      findsOneWidget,
    );
    expect(
      find.text('Enter a title between 3 and 200 characters.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Corrupt draft rows do not crash registration', (tester) async {
    SharedPreferences.setMockInitialValues({
      'sf_registration_draft_v1_201_1': jsonEncode({
        'inventory': {
          'items': ['corrupt row'],
        },
      }),
    });
    await _mount(tester, _PolishApi(), 'ENG');
    expect(
      find.text(
        'Draft could not be restored. Registration is still available.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Drafts are isolated between two accounts at the same office', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sf_registration_draft_v1_201_1': jsonEncode({
        'title': 'First account folder',
      }),
      'sf_registration_draft_v1_202_1': jsonEncode({
        'title': 'Second account folder',
      }),
    });
    await _mount(tester, _PolishApi(), 'ENG', accountId: 202);
    final title = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'e.g. Road repair — Phase 1',
    );
    expect(
      tester.widget<TextField>(title).controller!.text,
      'Second account folder',
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        'sf_registration_draft_v1_201_1',
      ),
      contains('First account folder'),
    );
  });

  testWidgets(
    'Draft survives navigation with attachments and never restores physical confirmation',
    (tester) async {
      final api = _PolishApi();
      await _mount(tester, api, 'ENG');
      final title = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'e.g. Road repair — Phase 1',
      );
      await _enter(tester, title, 'Unfinished folder');
      await _enter(tester, _field('Main document pages'), '2');
      await tester.ensureVisible(find.text('Add attachment'));
      await tester.tap(find.text('Add attachment'));
      await tester.pump();
      await _enter(tester, _field('Attachment name'), 'Supporting sheet');
      await _enter(tester, _field('Attachment pages'), '6');
      await tester.ensureVisible(
        find.text('I physically hold this folder and counted its contents.'),
      );
      await tester.tap(
        find.text('I physically hold this folder and counted its contents.'),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('sf_registration_draft_v1_201_1');
      expect(raw, isNotNull);
      expect(
        (jsonDecode(raw!) as Map)['inventory']['items'][1]['name'],
        'Supporting sheet',
      );
      await _mount(tester, api, 'ENG');
      expect(
        tester.widget<TextField>(title).controller!.text,
        'Unfinished folder',
      );
      final inventory = find.byType(FolderInventoryEditor);
      final state = tester.state<FolderInventoryEditorState>(inventory);
      expect(state.draft['items'][1]['pages'], '6');
      expect(state.validateAndRead(), isNull);
      await tester.pumpAndSettle();
      expect(
        find.text('Confirm you hold the folder and counted its contents.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await _mount(tester, api, 'ACC');
      expect(tester.widget<TextField>(title).controller!.text, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'Office checklist supplies required names with blank actual counts',
    (tester) async {
      final api = _PolishApi()
        ..checklists = [
          {
            'id': 1,
            'name': 'Office supporting requirements',
            'document_type': 'Disbursement Voucher',
            'items': [
              {'name': 'Approved supporting sheet', 'required': true},
            ],
          },
        ];
      await _mount(tester, api, 'ENG');
      final button = find.text('Use Office supporting requirements');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      final state = tester.state<FolderInventoryEditorState>(
        find.byType(FolderInventoryEditor),
      );
      expect(state.draft['items'][1], {
        'name': 'Approved supporting sheet',
        'pages': '',
        'required': true,
      });
      expect(state.draft['items'][0]['pages'], '');
      expect(find.text('Publish attachments as checklist'), findsNothing);
      expect(state.validateAndRead(), isNull);
      await tester.pump();
      await tester.ensureVisible(find.text('Clear form'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear form'));
      await tester.pumpAndSettle();
      expect(state.draft['items'].length, 1);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'sf_registration_draft_v1_201_1',
        ),
        isNull,
      );
    },
  );
}
