import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/widgets/folder_contents.dart';
import 'package:smartflow/widgets/sf_qr_display.dart';

const inventory = <String, dynamic>{
  'total_pages': 8,
  'status': 'complete',
  'items': [
    {'id': 'main', 'name': 'Main document', 'pages': 2, 'required': true},
    {
      'id': 'attachment-1',
      'name': 'Supporting document',
      'pages': 6,
      'required': true,
    },
  ],
};
Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> enter(WidgetTester tester, String label, String value) async {
  final target = field(label);
  await tester.ensureVisible(target);
  await tester.enterText(target, value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Registration counts physical pages and declares missing attachments',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey<FolderInventoryEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: FolderInventoryEditor(key: key)),
          ),
        ),
      );
      expect(key.currentState!.validateAndRead(), isNull);
      await tester.pumpAndSettle();
      await enter(tester, 'Main document pages', '2');
      await tester.tap(find.text('Add attachment'));
      await tester.pumpAndSettle();
      await enter(tester, 'Attachment name', 'Supporting document');
      await enter(tester, 'Attachment pages', '0');
      final hold = find.text(
        'I physically hold this folder and counted its contents.',
      );
      expect(key.currentState!.validateAndRead(), isNull);
      await tester.pumpAndSettle();
      await tester.ensureVisible(hold);
      await tester.tap(hold);
      await tester.pumpAndSettle();
      final saved = key.currentState!.validateAndRead()!;
      expect(saved['count_confirmed'], isTrue);
      expect(saved['items'][1]['pages'], 0);
      expect(saved['items'][1]['required'], isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Missing contents require actual counts, confirmation and a reason',
    (tester) async {
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showFolderReceiptDialog(context, {
                    'id': 'DOC-2026-000001',
                    'folder_inventory': inventory,
                  });
                },
                child: const Text('Receive'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Receive'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(field('Main document — received pages'))
            .controller!
            .text,
        isEmpty,
      );
      await enter(tester, 'Main document — received pages', '2');
      await enter(tester, 'Supporting document — received pages', '0');
      final confirm = find.text(
        'I physically received this folder and checked its reference and contents.',
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Receive incomplete folder'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(
        find.text('Describe the discrepancy (at least 5 characters).'),
        findsOneWidget,
      );
      await enter(
        tester,
        'Discrepancy / missing item details',
        'Supporting document did not arrive',
      );
      await tester.tap(find.text('Receive incomplete folder'));
      await tester.pumpAndSettle();
      expect(saved!['items'][1]['pages'], 0);
      expect(saved!['reason'], 'Supporting document did not arrive');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Cancel receipt does not save a movement', (tester) async {
    var resolved = false;
    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showFolderReceiptDialog(context, {
                  'id': 'DOC-2026-000001',
                });
                resolved = true;
              },
              child: const Text('Receive'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Receive'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No inventory was recorded'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(resolved, isTrue);
    expect(result, isNull);
  });
  test(
    'Flow Dots renders phone and export PNGs with the actual Flutter painter',
    () async {
      final payload =
          'SF1.eyJkIjoiRE9DLTIwMjYtMDAwMDA2IiwiaSI6MTc5MDgwNDAwMCwiZSI6MTgwNjM1NjAwMH0.${'A' * 43}';
      for (final size in [220, 600]) {
        final recorder = ui.PictureRecorder();
        SfFlowQrPainter(
          payload,
        ).paint(Canvas(recorder), Size.square(size.toDouble()));
        final picture = recorder.endRecording();
        final image = await picture.toImage(size, size);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(data, isNotNull);
        // Optional evidence for the independent ZXing PNG decoder.
        final output = Platform.environment['SMARTFLOW_QR_TEST_OUTPUT'];
        if (output != null) {
          Directory(output).createSync(recursive: true);
          File(
            '$output/flutter-flow-dots-$size.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          File(
            '$output/flutter-flow-dots-payload.txt',
          ).writeAsStringSync(payload);
        }
        image.dispose();
        picture.dispose();
      }
    },
  );
}
