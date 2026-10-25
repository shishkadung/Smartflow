import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_connectivity.dart';

class ApiException implements Exception {
  ApiException(
    this.message, [
    this.statusCode = 0,
    this.scanError,
    this.qrError,
  ]);

  final String message;
  final int statusCode;
  final String? scanError;
  final String? qrError;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.token, this.onSessionInvalid, http.Client? client})
    // ignore: prefer_initializing_formals -- Keep the public client injection used by transport tests.
    : _client = client;

  final void Function(String token, String message)? onSessionInvalid;
  final http.Client? _client;

  void _checkSession(http.Response res, bool auth) {
    if (!auth || token == null) return;
    String message = 'Your session has ended. Please sign in again.';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    if (res.statusCode == 401 ||
        (res.statusCode == 403 &&
            message.toLowerCase().contains('deactivated'))) {
      onSessionInvalid?.call(token!, message);
    }
  }

  static const Duration _timeout = Duration(seconds: 30);

  String? token;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final clean = path.replaceFirst(RegExp(r'^/+'), '');
    final merged = <String, String>{...?query};
    return Uri.parse(
      '$base/$clean',
    ).replace(queryParameters: merged.isEmpty ? null : merged);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    return _decode(
      await _send(
        () => (_client?.get ?? http.get)(
          _uri(path, query),
          headers: _headers(auth),
        ),
      ),
      path,
      auth,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final payload = body == null ? null : Map<String, dynamic>.from(body);
    return _decode(
      await _send(
        () => (_client?.post ?? http.post)(
          _uri(path),
          headers: _headers(auth, json: payload != null),
          body: payload == null ? null : jsonEncode(payload),
        ),
      ),
      path,
      auth,
    );
  }

  /// Multipart POST (profile photo). [filePath] optional for field-only posts.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    String? fileField,
    String? filePath,
    String? filename,
    bool auth = true,
  }) async {
    final uri = _uri(path);
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(_headers(auth));
    req.fields.addAll(fields);
    if (fileField != null && filePath != null && filePath.isNotEmpty) {
      req.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          filePath,
          filename: filename,
        ),
      );
    }
    final streamed = await _send(() async {
      final res = await (_client?.send(req) ?? req.send()).timeout(_timeout);
      return http.Response.fromStream(res);
    });
    return _decode(streamed, path, auth);
  }

  /// Plain-text GET (CSV export, etc.).
  Future<String> getText(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final res = await _send(
      () => (_client?.get ?? http.get)(
        _uri(path, query),
        headers: _headers(auth),
      ),
    );
    _checkSession(res, auth);
    if (res.statusCode >= 400) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          throw ApiException(
            decoded['message']?.toString() ?? 'Request failed',
            res.statusCode,
            decoded['scan_error']?.toString(),
            decoded['qr_error']?.toString(),
          );
        }
      } catch (e) {
        if (e is ApiException) rethrow;
      }
      throw ApiException(
        res.statusCode == 404
            ? 'API not found ($path). Sync backend to XAMPP.'
            : 'Export failed (${res.statusCode})',
        res.statusCode,
      );
    }
    return res.body;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_timeout);
      ApiConnectivity.instance.report(
        response.statusCode >= 500,
        successful: response.statusCode >= 200 && response.statusCode < 300,
      );
      return response;
    } on TimeoutException {
      ApiConnectivity.instance.report(true);
      throw ApiException(
        'The connection timed out. Refresh to check whether your action was recorded before submitting it again.',
        0,
      );
    } on SocketException {
      ApiConnectivity.instance.report(true);
      throw ApiException(
        'Cannot connect to the municipal portal right now. Confirm the office network service is running, then try again.',
        0,
      );
    } on HttpException {
      ApiConnectivity.instance.report(true);
      throw ApiException('Network error — please try again.', 0);
    } on http.ClientException {
      ApiConnectivity.instance.report(true);
      throw ApiException(
        'Connection interrupted. Refresh to check whether your action was recorded before submitting it again.',
        0,
      );
    }
  }

  Map<String, String> _headers(bool auth, {bool json = false}) {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json';
    if (auth && token != null && token!.isNotEmpty) {
      // Multiple headers: Apache/CGI often drops Authorization alone.
      h['Authorization'] = 'Bearer $token';
      h['X-Authorization'] = 'Bearer $token';
      h['X-Smartflow-Token'] = token!;
    }
    return h;
  }

  Map<String, dynamic> _decode(http.Response res, String path, bool auth) {
    _checkSession(res, auth);
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('not a JSON object');
      }
      data = decoded;
    } catch (_) {
      final body = res.body.trimLeft();
      if (body.startsWith('<!') || body.startsWith('<html')) {
        if (res.statusCode == 404) {
          throw ApiException(
            'Portal service was not found. Please contact the system administrator.',
            res.statusCode,
          );
        }
        throw ApiException(
          'Unexpected server response. Please try again or contact support.',
          res.statusCode,
        );
      }
      throw ApiException(
        res.statusCode == 0
            ? 'Cannot connect to the municipal portal right now. Please try again shortly.'
            : 'Invalid server response (not JSON)',
        res.statusCode,
      );
    }
    if (res.statusCode >= 400 || data['success'] == false) {
      throw ApiException(
        data['message']?.toString() ?? 'Request failed',
        res.statusCode,
        data['scan_error']?.toString(),
        data['qr_error']?.toString(),
      );
    }
    return data;
  }
}
