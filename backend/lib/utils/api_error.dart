import '../services/api_client.dart';

/// User-facing message for any API/network failure.
String apiErrorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  final text = error.toString().toLowerCase();
  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('failed host lookup')) {
    return 'Cannot reach server — start XAMPP (Apache + MySQL) and check API URL (emulator: 10.0.2.2).';
  }
  if (text.contains('timeout')) {
    return 'Request timed out — is Apache running?';
  }
  return 'Something went wrong — pull to refresh or try again.';
}
