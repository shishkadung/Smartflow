import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/main.dart';

void main() {
  testWidgets('SmartflowApp builds', (tester) async {
    await tester.pumpWidget(const SmartflowApp());
    expect(find.text('SmartFlow'), findsWidgets);
  });
}
