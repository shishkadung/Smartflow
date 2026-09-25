import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// PHP API base URL (no trailing slash).
///
/// Defaults by platform (override anytime with `--dart-define=API_BASE=...`):
/// - Android emulator → http://10.0.2.2/...
/// - iOS Simulator / desktop / web → http://127.0.0.1/...
/// - Physical phone (same Wi‑Fi as this PC) →
///   flutter run --dart-define=API_BASE=http://192.168.1.10/Smartflow/backend/backend/api
/// Production:
///   flutter run --dart-define=ENV=production
class ApiConfig {
  static const String _emulatorUrl =
      'http://10.0.2.2/Smartflow/backend/backend/api';
  static const String _loopbackUrl =
      'http://127.0.0.1/Smartflow/backend/backend/api';
  static const String _physicalDeviceUrl =
      'http://192.168.1.10/Smartflow/backend/backend/api';
  static const String _productionUrl =
      'https://smartflow.urbiztondo.gov.ph/api';

  static const String env = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  /// Empty unless `--dart-define=API_BASE=...` was passed at build/run time.
  static const String _apiBaseOverride = String.fromEnvironment('API_BASE');

  static String get baseUrl {
    if (env == 'production') {
      return _productionUrl;
    }
    if (_apiBaseOverride.isNotEmpty) {
      return _apiBaseOverride;
    }
    if (kIsWeb) {
      return _loopbackUrl;
    }
    if (Platform.isAndroid) {
      return _emulatorUrl;
    }
    // iOS simulator, Windows/macOS/Linux desktop
    return _loopbackUrl;
  }

  /// Kept for scripts/docs that mention physical-device / iOS simulator testing.
  static const String physicalDeviceUrlExample = _physicalDeviceUrl;
  static const String iosSimulatorUrlExample = _loopbackUrl;

  /// When true, every cold start shows Login (clears saved session).
  /// Set to false for production so users stay signed in.
  static bool get devForceLoginOnStart => env != 'production';
}
