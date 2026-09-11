import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_update.dart';
import '../core/constants.dart';
import 'github_api.dart';

class UpdateService extends ChangeNotifier {
  AppUpdate? _latestUpdate;
  bool _isChecking = false;
  String _currentVersion = '';
  bool _noReleasesYet = false;

  AppUpdate? get latestUpdate => _latestUpdate;
  bool get isChecking => _isChecking;
  String get currentVersion => _currentVersion;
  bool get noReleasesYet => _noReleasesYet;

  bool get isUpdateEnabled =>
      AppConstants.githubOwner.isNotEmpty && AppConstants.githubRepo.isNotEmpty;

  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to get package info: $e');
      _currentVersion = '1.0.0';
    }
  }

  Future<void> checkForUpdates() async {
    if (!isUpdateEnabled) {
      debugPrint('Update checks disabled (no GitHub repo configured)');
      return;
    }

    _isChecking = true;
    _noReleasesYet = false;
    notifyListeners();

    try {
      // Ensure we have the current version
      if (_currentVersion.isEmpty) {
        await init();
      }

      final json = await GitHubApi.getJson(
        'https://api.github.com/repos/${AppConstants.githubOwner}/${AppConstants.githubRepo}/releases/latest',
      );

      if (json != null) {
        _latestUpdate = AppUpdate.fromJson(json);
      } else {
        // No releases yet (404)
        _noReleasesYet = true;
        _latestUpdate = null;
        debugPrint('No releases found for ${AppConstants.githubOwner}/${AppConstants.githubRepo}');
      }
    } catch (e) {
      debugPrint('Update check error: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  bool get hasUpdate {
    if (_latestUpdate == null || _currentVersion.isEmpty) return false;
    return _latestUpdate!.isNewerThan(_currentVersion);
  }
}
