import 'package:flutter/material.dart';

import 'session_storage.dart';

/// App-wide preferences: theme and the city shown on the home screen.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  ThemeMode themeMode = ThemeMode.system;
  String? city; // null = all cities

  Future<void> load() async {
    switch (await SessionStorage.readTheme()) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      default:
        themeMode = ThemeMode.system;
    }
    city = await SessionStorage.readCity();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final value = mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system');
    await SessionStorage.saveTheme(value);
  }

  Future<void> setCity(String? value) async {
    city = value;
    notifyListeners();
    await SessionStorage.saveCity(value);
  }
}
