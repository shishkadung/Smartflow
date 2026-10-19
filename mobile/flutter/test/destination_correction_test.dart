import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/widgets/destination_correction.dart';

const _action = 'Correct recorded destination';
const _confirm = 'Confirm correction';
const _newOffice = 'Accounting Office';

Map<String, dynamic> _document() => {
  'id': 'DOC-2026-000091',
  'can_correct_destination': true,
  'last_movement_id': 73,
  'destination_office_id': 2,
  'destination_office_name': 'Budget Office',
  'last_destination_correction_id': 9,
};

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  int officeReads = 0;
  bool failOffices = false;
  final writes = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? pendingWrite;

  @override
  Future<List<Map<String, dynamic>>> offices() async {
    officeReads++;
    if (failOffices) throw ApiException('Office choices unavailable');
    return [
      {'id': 1, 'name': 'Engineering Office'},
      {'id': 2, 'name': 'Budget Office'},
      {'id': 3, 'name': _newOffice},
    ];
  }

  @override
  Future<Map<String, dynamic>> correctMovementDestination(
    Map<String, dynamic> body,
  ) async {
    writes.add(Map<String, dynamic>.from(body));
    return pendingWrite == null ? {'ok': true} : await pendingWrite!.future;
  }
}

class _Auth extends AuthProvider {
  _Auth(this.api, this.role);
  @override
  final SmartflowApi api;
  final String role;
  @override
  AppUser get user => AppUser(
    id: 10,
    name: 'Test staff',
    username: 'test.staff',
    role: role,
    officeId: 1,
    officeName: 'Engineering Office',
    officeCode: 'ENG',
  );
}

Future<void> _mount(
  WidgetTester tester,
  _Api api, {
  String role = 'staff',
  Map<String, dynamic>? document,
  Future<void> Function()? onChanged,
  double textScale = 1,
}) async {
  if (textScale == 1) {
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(api, role),
      child: MaterialApp(
        theme: buildSmartflowTheme(),
        builder: (_, child) => MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: DestinationCorrectionAction(
            document: document ?? _document(),
            onChanged: onChanged ?? () async {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text(_action));
  await tester.pumpAndSettle();
}

Future<void> _chooseOffice(WidgetTester tester) async {
  final dropdown = find.byType(DropdownButtonFormField<int>);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  // The sender and already-recorded destination are not correction choices.
  expect(find.text('Engineering Office'), findsNothing);
  expect(find.text('Budget Office'), findsNothing);
  await tester.tap(find.text(_newOffice).last);
  await tester.pumpAndSettle();
}

FilledButton _confirmButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, _confirm));

Future<void> _readyToConfirm(WidgetTester tester) async {
  await _chooseOffice(tester);
  await tester.ensureVisible(find.byType(TextField));
  await tester.enterText(
    find.byType(TextField),
    'Wrong office selected in the original OUT.',
  );
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final role in ['head', 'admin']) {
    testWidgets('$role cannot open a physical destination correction', (
      tester,
    ) async {
      final api = _Api();
      await _mount(tester, api, role: role);
      expect(find.text(_action), findsNothing);
      expect(api.officeReads, 0);
      expect(api.writes, isEmpty);
    });
  }

  testWidgets(
    'staff without eligible sender evidence has no correction action',
    (tester) async {
      final api = _Api();
      await _mount(
        tester,
        api,
        document: _document()..['can_correct_destination'] = false,
      );
      expect(find.text(_action), findsNothing);
      expect(api.officeReads, 0);
      expect(api.writes, isEmpty);
    },
  );

  testWidgets(
    'correction needs office, five-character reason and explicit confirmation; submission freezes displayed evidence',
    (tester) async {
      final api = _Api();
      final document = _document();
      var changed = 0;
      await _mount(
        tester,
        api,
        document: document,
        onChanged: () async {
          changed++;
        },
      );
      await _open(tester);
      expect(api.writes, isEmpty);
      expect(_confirmButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Oops');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(_confirmButton(tester).onPressed, isNull);
      await _chooseOffice(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(_confirmButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '  Wrong destination  ');
      await tester.pumpAndSettle();
      expect(_confirmButton(tester).onPressed, isNotNull);
      expect(api.writes, isEmpty);

      // A refreshed parent object must not silently change the evidence confirmed in this dialog.
      document.addAll({
        'last_movement_id': 74,
        'destination_office_id': 4,
        'last_destination_correction_id': 10,
      });
      await tester.tap(find.text(_confirm));
      await tester.pumpAndSettle();
      expect(api.writes, [
        {
          'document_id': 'DOC-2026-000091',
          'expected_movement_id': 73,
          'expected_destination_office_id': 2,
          'expected_correction_id': 9,
          'destination_office_id': 3,
          'reason': 'Wrong destination',
          'correction_confirmed': true,
        },
      ]);
      expect(changed, 1);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('office failure is visible and retry recovers without writing', (
    tester,
  ) async {
    final api = _Api()..failOffices = true;
    await _mount(tester, api);
    await _open(tester);
    expect(find.text('Office choices unavailable'), findsOneWidget);
    expect(find.text('Retry offices'), findsOneWidget);
    expect(_confirmButton(tester).onPressed, isNull);
    expect(api.writes, isEmpty);
    api.failOffices = false;
    await tester.tap(find.text('Retry offices'));
    await tester.pumpAndSettle();
    expect(api.officeReads, 2);
    expect(find.text('Office choices unavailable'), findsNothing);
    await _chooseOffice(tester);
    expect(api.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saving locks dialog controls and cannot issue a second correction',
    (tester) async {
      final api = _Api()..pendingWrite = Completer<Map<String, dynamic>>();
      await _mount(tester, api);
      await _open(tester);
      await _readyToConfirm(tester);
      await tester.tap(find.text(_confirm));
      await tester.pump();
      expect(api.writes, hasLength(1));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Recording…'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      api.pendingWrite!.complete({'ok': true});
      await tester.pumpAndSettle();
      expect(api.writes, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    '320px with doubled text keeps correction form and confirmation reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api();
      await _mount(tester, api, textScale: 2);
      await _open(tester);
      await _readyToConfirm(tester);
      await tester.ensureVisible(find.text(_confirm));
      await tester.tap(find.text(_confirm));
      await tester.pumpAndSettle();
      expect(api.writes, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
