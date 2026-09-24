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
    return 'Cannot connect to the municipal portal right now. Please try again shortly.';
  }
  if (text.contains('timeout')) {
    return 'The portal is taking too long to respond. Please try again in a moment.';
  }
  return 'Something went wrong. Please try again.';
}
