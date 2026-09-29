import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/main.dart';

void main() {
  testWidgets('SmartflowApp builds', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SmartflowApp());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Smart'), findsWidgets);
    expect(find.text('Flow'), findsWidgets);
  });
}
