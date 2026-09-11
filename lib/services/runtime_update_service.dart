import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/utils.dart';
import 'github_api.dart';
import 'runtime_installer.dart';

class RuntimeUpdateInfo {
  final String upstreamSha;
  final String upstreamRepo;
  final String? publishedAt;
  final String downloadUrl;
  final RuntimeManifest? manifest;

  RuntimeUpdateInfo({
    required this.upstreamSha,
    required this.upstreamRepo,
    this.publishedAt,
    required this.downloadUrl,
    this.manifest,
  });
}

class RuntimeUpdateService extends ChangeNotifier {
  RuntimeUpdateInfo? _availableUpdate;
  RuntimeManifest? _installedManifest;
  String? _latestUpstreamSha;
  bool _isChecking = false;
  bool _isApplying = false;
  String? _error;

  RuntimeUpdateInfo? get availableUpdate => _availableUpdate;
  RuntimeManifest? get installedManifest => _installedManifest;
  String? get latestUpstreamSha => _latestUpstreamSha;
  bool get isChecking => _isChecking;
  bool get isApplying => _isApplying;
  String? get error => _error;

  bool get hasUpdate => _availableUpdate != null;
  bool get upstreamMovedButNotBuilt =>
      _latestUpstreamSha != null &&
      _installedManifest != null &&
      _latestUpstreamSha != _installedManifest!.upstreamSha &&
      _availableUpdate == null;

  Future<void> checkForRuntimeUpdate() async {
    _isChecking = true;
    _error = null;
    notifyListeners();

    try {
      _installedManifest = await RuntimeInstaller.getInstalledManifest();

      // The published-release check and the upstream-SHA check hit two
      // unrelated GitHub endpoints - run them concurrently instead of
      // back-to-back so a slow response from one doesn't add its full
      // timeout on top of the other's.
      await Future.wait([
        _checkPublishedRelease(),
        _checkUpstreamSha(),
      ]);
    } catch (e) {
      _error = 'Failed to check for runtime update: $e';
      debugPrint(_error);
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> _checkPublishedRelease() async {
    final json = await GitHubApi.getJson(
      'https://api.github.com/repos/${AppConstants.githubOwner}/${AppConstants.githubRepo}/releases/tags/${AppConstants.runtimeReleaseTag}',
    );

    if (json == null) {
      // No releases published yet.
      _availableUpdate = null;
      return;
    }

    final assets = json['assets'] as List<dynamic>? ?? [];

    RuntimeManifest? publishedManifest;
    String? downloadUrl;

    for (final asset in assets) {
      if (asset['name'] == 'runtime.json') {
        final manifestJson = await GitHubApi.getJson(
          asset['browser_download_url'],
        );
        if (manifestJson != null) {
          publishedManifest = RuntimeManifest.fromJson(manifestJson);
        }
      }
      if (asset['name']?.toString().endsWith('.zip') == true &&
          asset['name']?.toString().startsWith('runtime-') == true) {
        downloadUrl = asset['browser_download_url'];
      }
    }

    if (publishedManifest != null &&
        _installedManifest != null &&
        publishedManifest.upstreamSha != _installedManifest!.upstreamSha &&
        downloadUrl != null) {
      _availableUpdate = RuntimeUpdateInfo(
        upstreamSha: publishedManifest.upstreamSha,
        upstreamRepo: publishedManifest.upstreamRepo,
        publishedAt: json['published_at'],
        downloadUrl: downloadUrl,
        manifest: publishedManifest,
      );
    } else {
      _availableUpdate = null;
    }
  }

  Future<void> _checkUpstreamSha() async {
    try {
      final json = await GitHubApi.getJson(
        'https://api.github.com/repos/${AppConstants.upstreamOwner}/${AppConstants.upstreamRepo}/commits/main',
      );
      if (json != null) {
        _latestUpstreamSha = json['sha'];
      }
    } catch (e) {
      // Informational only - never let this fail the overall check.
      debugPrint('Failed to check upstream SHA: $e');
    }
  }

  /// Downloads, verifies, and installs the available runtime update.
  ///
  /// The caller is responsible for checking whether the bridge/MCP process
  /// is running and stopping it (with user confirmation) before calling
  /// this - swapping the runtime directory while either process has the
  /// old files open can leave things in a broken state on some platforms.
  Future<bool> applyRuntimeUpdate() async {
    if (_availableUpdate == null) return false;

    _isApplying = true;
    _error = null;
    notifyListeners();

    try {
      final update = _availableUpdate!;
      // Must be a sibling of the runtime directory, not nested inside it -
      // see getStagingPath()'s doc comment for why.
      final stagingDir = Directory(await RuntimeInstaller.getStagingPath());

      // Clean up any previous staging
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
      await stagingDir.create(recursive: true);

      // Download runtime zip
      debugPrint('Downloading runtime update: ${update.upstreamSha}');
      final zipPath = '${stagingDir.path}/runtime.zip';
      await AppUtils.downloadFile(update.downloadUrl, zipPath);

      // Verify SHA-256 if checksum file available
      try {
        final checksumUrl = '${update.downloadUrl}.sha256';
        final checksumResponse = await http.get(Uri.parse(checksumUrl));
        if (checksumResponse.statusCode == 200) {
          final expectedHash = checksumResponse.body.trim().split(' ')[0];
          final digest = await AppUtils.sha256OfFile(zipPath);
          if (digest != expectedHash) {
            throw Exception('SHA-256 verification failed for runtime update');
          }
        }
      } catch (e) {
        debugPrint('Warning: Could not verify checksum: $e');
      }

      // Extract zip
      debugPrint('Extracting runtime update...');
      await _extractZip(zipPath, stagingDir);

      // Verify extracted files against manifest
      if (update.manifest != null) {
        for (final entry in update.manifest!.files.entries) {
          final file = File('${stagingDir.path}/${entry.key}');
          if (!await file.exists()) {
            throw Exception('Extracted file missing: ${entry.key}');
          }
          final digest = await AppUtils.sha256OfFile(file.path);
          if (digest != entry.value) {
            throw Exception('SHA-256 mismatch for ${entry.key}');
          }
        }
      }

      // Stage and swap
      await RuntimeInstaller.stageAndSwap(stagingDir);

      // Clean up staging
      try {
        if (await stagingDir.exists()) {
          await stagingDir.delete(recursive: true);
        }
      } catch (_) {}

      _availableUpdate = null;
      _installedManifest = update.manifest;
      debugPrint('Runtime update applied successfully');
      return true;
    } catch (e) {
      _error = 'Failed to apply runtime update: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  Future<void> _extractZip(String zipPath, Directory targetDir) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // The runtime-sync workflow builds this zip with `zip -r ../file.zip .`
    // from inside the bundle directory, so entries are already relative to
    // the bundle root (e.g. "mcp-server.cjs", "plugin/code.js") with no
    // wrapping top-level directory to strip - unlike a GitHub source
    // zipball. Stripping a path segment here would flatten plugin/*.
    for (final file in archive) {
      final filename = file.name;
      if (filename.isEmpty || filename.contains('..')) continue;

      final outPath = '${targetDir.path}/$filename';

      if (file.isDirectory) {
        await Directory(outPath).create(recursive: true);
      } else {
        await File(outPath).create(recursive: true);
        await File(outPath).writeAsBytes(file.content as List<int>);
      }
    }
  }
}
