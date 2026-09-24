import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

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
  ApiClient({this.token});

  static const Duration _timeout = Duration(seconds: 30);

  String? token;

  Uri _uri(String path, [Map<String, String>? query, bool withAccessToken = true]) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final clean = path.replaceFirst(RegExp(r'^/+'), '');
    final merged = <String, String>{...?query};
    // Apache / CGI often strips Authorization — mirror web client fallbacks.
    if (withAccessToken && token != null && token!.isNotEmpty) {
      merged.putIfAbsent('access_token', () => token!);
    }
    return Uri.parse('$base/$clean').replace(
      queryParameters: merged.isEmpty ? null : merged,
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    return _decode(
      await _send(() => http.get(
            _uri(path, query, auth),
            headers: _headers(auth),
          )),
      path,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final payload = body == null ? null : Map<String, dynamic>.from(body);
    if (auth && token != null && token!.isNotEmpty && payload != null) {
      payload.putIfAbsent('access_token', () => token);
    }
    return _decode(
      await _send(() => http.post(
            _uri(path, null, auth),
            headers: _headers(auth, json: payload != null),
            body: payload == null ? null : jsonEncode(payload),
          )),
      path,
    );
  }

  /// Plain-text GET (CSV export, etc.).
  Future<String> getText(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final res = await _send(() => http.get(
          _uri(path, query, auth),
          headers: _headers(auth),
        ));
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
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'The portal is taking too long to respond. Please try again in a moment.',
        0,
      );
    } on SocketException {
      throw ApiException(
        'Cannot connect to the municipal portal right now. Confirm the office network service is running, then try again.',
        0,
      );
    } on HttpException {
      throw ApiException('Network error — please try again.', 0);
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

  Map<String, dynamic> _decode(http.Response res, String path) {
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
