import 'package:flutter/material.dart';

import 'storage_service.dart';

/// Holds the app's live theme mode and persists changes.
///
/// Previously, `StorageService.saveThemeMode` was never called anywhere -
/// the app loaded a persisted theme once at startup but had no UI control
/// that ever wrote one back, so the theme could only ever be "system".
/// This service is the single source of truth for the current theme mode:
/// `SettingsScreen` calls [setMode] and the top-level `MaterialApp` (via a
/// `Consumer` in `app.dart`) rebuilds immediately when it changes.
class ThemeService extends ChangeNotifier {
  final StorageService _storage = StorageService();
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    final saved = await _storage.loadThemeMode();
    _mode = _fromString(saved);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _storage.saveThemeMode(_toString(mode));
  }

  static ThemeMode _fromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
