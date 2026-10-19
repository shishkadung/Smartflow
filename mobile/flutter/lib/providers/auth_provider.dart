import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/smartflow_api.dart';

class AuthProvider extends ChangeNotifier {
  // ignore: prefer_initializing_formals -- Public injection keeps transport tests independent of a live API.
  AuthProvider({http.Client? httpClient}) : _httpClient = httpClient;
  final http.Client? _httpClient;
  static const _tokenKey = 'smartflow_token';
  static const _userKey = 'smartflow_user';

  AppUser? _user;
  String? _token;
  bool _loading = true;
  bool _loggingOut = false;
  Timer? _sessionTimer;
  bool _checkingSession = false;
  Future<void> _sessionWrites = Future<void>.value();
  int _loginAttempt = 0;
  bool _disposed = false;
  String? sessionMessage;

  /// True when [sessionMessage] reports a successful action (for example a
  /// password change) rather than a problem, so the sign-in screen can show it
  /// as a notice instead of an error.
  bool sessionMessageIsNotice = false;

  AppUser? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _user != null && _token != null && !_loggingOut;
  bool get loading => _loading;
  bool get loggingOut => _loggingOut;
  Object get sessionIdentity => (token, user?.id, user?.officeId, user?.role);

  int beginLoginAttempt() => ++_loginAttempt;

  void cancelLoginAttempt(int attempt) {
    if (_loginAttempt == attempt) _loginAttempt++;
  }

  SmartflowApi get api => SmartflowApi(
    ApiClient(
      token: _token,
      onSessionInvalid: _invalidate,
      client: _httpClient,
    ),
    movementScope: _user == null ? null : '${_user!.id}_${_user!.officeId}',
  );

  void _invalidate(String token, String message) {
    if (token != _token) return;
    _loginAttempt++;
    sessionMessageIsNotice = false;
    sessionMessage = message.toLowerCase().contains('token')
        ? 'Your session has ended. Please sign in again.'
        : message;
    // Clear identity before notifying: protected screens cannot keep stale counts.
    _token = null;
    _user = null;
    _sessionTimer?.cancel();
    notifyListeners();
    unawaited(_persistSession());
  }

  Future<void> _persistSession() {
    final token = _token;
    final user = _user;
    // Save/clear the pair in order. A newer login's write must follow any old
    // write already in progress, including the gap between two preference calls.
    final write = _sessionWrites.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (_token != token || !identical(_user, user)) return;
      await _writeSession(prefs, token, user);
    });
    _sessionWrites = write.catchError((Object _) {});
    return write;
  }

  Future<void> _writeSession(
    SharedPreferences prefs,
    String? token,
    AppUser? user,
  ) async {
    final clearing = token == null || user == null;
    final tokenSaved = clearing
        ? await prefs.remove(_tokenKey)
        : await prefs.setString(_tokenKey, token);
    final userSaved = clearing
        ? await prefs.remove(_userKey)
        : await prefs.setString(_userKey, jsonEncode(user.toJson()));
    if (!tokenSaved || !userSaved) {
      throw ApiException('Could not save this sign-in on the device.');
    }
  }

  bool isCurrentSession(String expectedToken, int expectedUserId) =>
      _token == expectedToken && _user?.id == expectedUserId;

  Future<void> checkSession() async {
    if (!isAuthenticated || _checkingSession) return;
    _checkingSession = true;
    try {
      await api.validateSession();
    } catch (_) {
    } finally {
      _checkingSession = false;
    }
  }

  void _watchSession() {
    _sessionTimer?.cancel();
    if (!isAuthenticated) return;
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => checkSession(),
    );
  }

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    if (ApiConfig.devForceLoginOnStart) {
      _token = null;
      _user = null;
      await _persistSession();
    } else {
      _token = prefs.getString(_tokenKey);
      final raw = prefs.getString(_userKey);
      if (raw != null) {
        try {
          _user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {
          _token = null;
          _user = null;
          await _persistSession();
        }
      }
    }
    await checkSession();
    _watchSession();
    _loading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password, {int? attempt}) async {
    final ownedAttempt = attempt ?? beginLoginAttempt();
    bool ownsAttempt() => !_disposed && _loginAttempt == ownedAttempt;
    if (!ownsAttempt()) return false;
    final client = ApiClient(client: _httpClient);
    late final ({String token, AppUser user}) result;
    try {
      result = await SmartflowApi(client).login(username, password);
    } catch (_) {
      if (!ownsAttempt()) return false;
      rethrow;
    }
    if (!ownsAttempt()) return false;
    var installed = false;
    final write = _sessionWrites.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!ownsAttempt()) return;
      try {
        await _writeSession(prefs, result.token, result.user);
      } catch (_) {
        await _writeSession(prefs, _token, _user);
        if (ownsAttempt()) rethrow;
        return;
      }
      if (!ownsAttempt()) {
        // Only committed identity is visible to protected callbacks. Cancelled
        // candidates restore that pair before the next queued write starts.
        await _writeSession(prefs, _token, _user);
        return;
      }
      _token = result.token;
      _user = result.user;
      sessionMessage = null;
      sessionMessageIsNotice = false;
      installed = true;
      _watchSession();
      notifyListeners();
    });
    _sessionWrites = write.catchError((Object _) {});
    await write;
    return installed && isCurrentSession(result.token, result.user.id);
  }

  Future<void> logout() async {
    if (_loggingOut || _token == null) return;
    final endingToken = _token!;
    _loginAttempt++;
    final endingApi = api;
    _sessionTimer?.cancel();
    _loggingOut = true;
    notifyListeners();
    try {
      await endingApi.logout();
      await endSession(endingToken);
    } finally {
      _loggingOut = false;
      _watchSession();
      notifyListeners();
    }
  }

  Future<void> endSession(
    String expectedToken, {
    String? message,
    bool notice = false,
  }) async {
    if (_token != expectedToken) return;
    _loginAttempt++;
    _token = null;
    _user = null;
    sessionMessage = message;
    sessionMessageIsNotice = notice && message != null;
    _sessionTimer?.cancel();
    await _persistSession();
    notifyListeners();
  }

  Future<bool> refreshUser(
    AppUser user, {
    required String expectedToken,
  }) async {
    if (!isCurrentSession(expectedToken, user.id)) return false;
    _user = user;
    await _persistSession();
    if (!isCurrentSession(expectedToken, user.id)) return false;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _loginAttempt++;
    _sessionTimer?.cancel();
    super.dispose();
  }
}
