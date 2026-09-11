import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bridge_config.dart';

class StorageService {
  static const String _configKey = 'bridge_config';
  static const String _themeKey = 'theme_mode';

  Future<BridgeConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(_configKey);

    if (configJson != null) {
      try {
        final json = jsonDecode(configJson);
        return BridgeConfig.fromJson(json);
      } catch (e) {
        return BridgeConfig();
      }
    }

    return BridgeConfig(password: BridgeConfig.defaultPassword);
  }

  Future<void> saveConfig(BridgeConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = jsonEncode(config.toJson());
    await prefs.setString(_configKey, configJson);
  }

  Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }
}
