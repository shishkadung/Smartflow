/// PHP API base URL (no trailing slash).
///
/// Android emulator → host machine: http://10.0.2.2/...
/// Physical device → your PC LAN IP on the same Wi‑Fi.
///
/// Override at run time:
///   flutter run --dart-define=API_BASE=http://192.168.1.10/smartflow/api
class ApiConfig {
  // For physical device testing, use your PC's IP (found via ipconfig)
  // Change this to your PC's IP when testing on physical device
  static const String _emulatorUrl = 'http://10.0.2.2/Smartflow/backend/backend/api';
  static const String _physicalDeviceUrl = 'http://10.172.240.1/Smartflow/backend/backend/api';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    // Change to _emulatorUrl for Android emulator, _physicalDeviceUrl for physical device
    defaultValue: _physicalDeviceUrl,
  );

  /// When true, every cold start shows Login (clears saved session).
  /// Set to false for production so users stay signed in.
  static const bool devForceLoginOnStart = true;
}
