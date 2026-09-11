import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_update.dart';
import '../core/constants.dart';

class UpdateService extends ChangeNotifier {
  AppUpdate? _latestUpdate;
  bool _isChecking = false;

  AppUpdate? get latestUpdate => _latestUpdate;
  bool get isChecking => _isChecking;

  /// False until AppConstants.githubOwner/githubRepo point at a real repo.
  /// Checking against the placeholder repo would just 404 every time.
  bool get isUpdateEnabled =>
      AppConstants.githubOwner.isNotEmpty && AppConstants.githubRepo.isNotEmpty;

  Future<void> checkForUpdates() async {
    if (!isUpdateEnabled) {
      debugPrint('Update checks disabled (no GitHub repo configured)');
      return;
    }

    _isChecking = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        'https://api.github.com/repos/${AppConstants.githubOwner}/${AppConstants.githubRepo}/releases/latest',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _latestUpdate = AppUpdate.fromJson(json);
      } else {
        debugPrint('Failed to check for updates: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Update check error: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  bool hasUpdate() {
    if (_latestUpdate == null) return false;
    return _latestUpdate!.isNewerThan(AppConstants.appVersion);
  }
}
