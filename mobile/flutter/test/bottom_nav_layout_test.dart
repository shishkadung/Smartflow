import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/widgets/sf_page.dart';

void main() {
  testWidgets('phone navigation stays readable and operable at large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 740);
      for (final scale in [1.0, 1.25, 2.0]) {
        var destination = -1;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              bottomNavigationBar: SfBottomNav(
                currentIndex: 0,
                onTap: (index) => destination = index,
                tabs: const [
                  SfNavTab(icon: Icons.home_outlined, label: 'Home'),
                  SfNavTab(icon: Icons.folder_outlined, label: 'Documents'),
                  SfNavTab(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan',
                    elevated: true,
                  ),
                  SfNavTab(icon: Icons.notifications_outlined, label: 'Alerts'),
                  SfNavTab(icon: Icons.apps_rounded, label: 'Menu'),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        final visibleLabel = scale == 1 ? 'Documents' : 'Docs';
        expect(find.text(visibleLabel), findsOneWidget);
        expect(find.bySemanticsLabel('Documents'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final target = find.ancestor(
          of: find.text(visibleLabel),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(visibleLabel),
            matching: find.byType(RichText),
          ),
        );
        final lines = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: visibleLabel.length),
            )
            .map((box) => box.top)
            .toSet();
        expect(lines.length, 1);
        expect(find.byTooltip('Documents'), findsOneWidget);
        await tester.tap(find.text(visibleLabel));
        expect(destination, 1);
      }
    }
    semantics.dispose();
  });
}
