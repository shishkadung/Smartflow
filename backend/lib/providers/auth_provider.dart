import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/smartflow_api.dart';

class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'smartflow_token';
  static const _userKey = 'smartflow_user';

  AppUser? _user;
  String? _token;
  bool _loading = true;

  AppUser? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _user != null && _token != null;
  bool get loading => _loading;

  SmartflowApi get api => SmartflowApi(ApiClient(token: _token));

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    if (ApiConfig.devForceLoginOnStart) {
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      _token = null;
      _user = null;
    } else {
      _token = prefs.getString(_tokenKey);
      final raw = prefs.getString(_userKey);
      if (raw != null) {
        _user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final client = ApiClient();
    final result = await SmartflowApi(client).login(username, password);
    _token = result.token;
    _user = result.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }
}
