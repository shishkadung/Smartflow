import 'package:flutter/foundation.dart';

class ApiConnectivity extends ChangeNotifier {
  ApiConnectivity._();
  static final instance = ApiConnectivity._();
  final retries = ValueNotifier<int>(0);
  bool unavailable = false;
  DateTime? lastSuccess;

  void report(bool failed, {bool successful = false}) {
    unavailable = failed;
    if (successful) lastSuccess = DateTime.now();
    notifyListeners();
  }

  void refresh() => retries.value++;
}
