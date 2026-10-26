import 'dart:async';

import 'package:smartflow/widgets/sf_motion.dart';

/// Runs before every test file. Entrance animations are switched off so one pump shows the finished screen; tests of the
/// motion itself (motion_test.dart) switch it back on for their own cases.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SfMotion.enabled = false;
  await testMain();
}
