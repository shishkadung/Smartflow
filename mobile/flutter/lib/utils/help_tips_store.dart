import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the post-login role tip was shown for a username.
class HelpTipsStore {
  HelpTipsStore._();

  static String _key(String username) =>
      'sf_role_tip_seen_v2_${username.trim().toLowerCase()}';

  static Future<bool> hasSeenRoleTip(String username) async {
    if (username.trim().isEmpty) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(username)) ?? false;
  }

  static Future<void> markRoleTipSeen(String username) async {
    if (username.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(username), true);
  }

  /// Profile → “Show tips again”.
  static Future<void> resetRoleTip(String username) async {
    if (username.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(username));
  }
}
