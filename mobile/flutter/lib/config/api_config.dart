/// PHP API base URL (no trailing slash).
///
/// Android emulator → http://10.0.2.2/...
/// iOS Simulator → http://127.0.0.1/... (same machine as XAMPP)
/// Physical phone → your PC LAN IP on the same Wi‑Fi:
///   flutter run --dart-define=API_BASE=http://192.168.x.x/Smartflow/backend/backend/api
/// Production:
///   flutter run --dart-define=ENV=production
class ApiConfig {
  static const String _emulatorUrl =
      'http://10.0.2.2/Smartflow/backend/backend/api';
  static const String _iosSimulatorUrl =
      'http://127.0.0.1/Smartflow/backend/backend/api';
  static const String _physicalDeviceUrl =
      'http://10.172.240.1/Smartflow/backend/backend/api';
  static const String _productionUrl =
      'https://smartflow.urbiztondo.gov.ph/api';

  static const String env = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  static String get baseUrl {
    if (env == 'production') {
      return _productionUrl;
    }
    return const String.fromEnvironment(
      'API_BASE',
      // Android emulator default. On iOS Simulator, pass:
      // --dart-define=API_BASE=http://127.0.0.1/Smartflow/backend/backend/api
      defaultValue: _emulatorUrl,
    );
  }

  /// Kept for scripts/docs that mention physical-device / iOS simulator testing.
  static const String physicalDeviceUrlExample = _physicalDeviceUrl;
  static const String iosSimulatorUrlExample = _iosSimulatorUrl;

  /// When true, every cold start shows Login (clears saved session).
  /// Set to false for production so users stay signed in.
  static bool get devForceLoginOnStart => env != 'production';
}
