import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

/// Everything that should survive closing the app: the sign-in token, a
/// cached copy of the user (so the app opens instantly, even offline), the
/// chosen theme and the last-used city.
class SessionStorage {
  SessionStorage._();

  static const _tokenKey = 'session.token';
  static const _userKey = 'session.user';
  static const _themeKey = 'settings.theme'; // system | light | dark
  static const _cityKey = 'settings.city';

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null; // storage unavailable: the app still works, just doesn't remember
    }
  }

  static Future<String?> readToken() async => (await _prefs())?.getString(_tokenKey);

  static Future<AppUser?> readUser() async {
    final raw = (await _prefs())?.getString(_userKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSession(String token, AppUser user) async {
    final prefs = await _prefs();
    await prefs?.setString(_tokenKey, token);
    await prefs?.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> saveUser(AppUser user) async {
    await (await _prefs())?.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> clearSession() async {
    final prefs = await _prefs();
    await prefs?.remove(_tokenKey);
    await prefs?.remove(_userKey);
  }

  static Future<String?> readTheme() async => (await _prefs())?.getString(_themeKey);
  static Future<void> saveTheme(String value) async => (await _prefs())?.setString(_themeKey, value);

  static Future<String?> readCity() async => (await _prefs())?.getString(_cityKey);
  static Future<void> saveCity(String? city) async {
    final prefs = await _prefs();
    if (city == null) {
      await prefs?.remove(_cityKey);
    } else {
      await prefs?.setString(_cityKey, city);
    }
  }
}
