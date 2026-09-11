import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/bridge_config.dart';
import '../models/system_requirement.dart';

enum NodeProvisionStatus {
  checking,
  ready,
  downloading,
  error,
  notAvailable,
}

class NodeRuntimeService extends ChangeNotifier {
  NodeProvisionStatus _status = NodeProvisionStatus.checking;
  String? _nodePath;
  String? _errorMessage;
  double _downloadProgress = 0;
  String? _currentVersion;

  NodeProvisionStatus get status => _status;
  String? get nodePath => _nodePath;
  String? get errorMessage => _errorMessage;
  double get downloadProgress => _downloadProgress;
  String? get currentVersion => _currentVersion;
  bool get isReady => _status == NodeProvisionStatus.ready && _nodePath != null;

  Future<String> ensureNode({String? overrideNodePath}) async {
    _status = NodeProvisionStatus.checking;
    notifyListeners();

    // 1. Explicit user override
    if (overrideNodePath != null && overrideNodePath.isNotEmpty) {
      final version = await _probeNode(overrideNodePath);
      if (version != null) return _commit(overrideNodePath, version);
    }

    // 2. Managed node in app data
    final managedPath = await _managedNodePath();
    if (managedPath != null) {
      final version = await _probeNode(managedPath);
      if (version != null) return _commit(managedPath, version);
    }

    // 3. System node (only as override when user opted in)
    final systemNode = await _findSystemNode();
    if (systemNode != null) {
      final version = await _probeNode(systemNode);
      if (version != null) return _commit(systemNode, version);
    }

    // 4. Download and install
    try {
      await _downloadAndInstall();
      final installedPath = await _managedNodePath();
      final version = installedPath == null ? null : await _probeNode(installedPath);
      if (installedPath != null && version != null) {
        return _commit(installedPath, version);
      }
    } catch (e) {
      _errorMessage = 'Failed to install Node.js: $e';
      _status = NodeProvisionStatus.error;
      notifyListeners();
      rethrow;
    }

    _status = NodeProvisionStatus.notAvailable;
    _errorMessage = 'Node.js not available';
    notifyListeners();
    throw Exception('Node.js not available');
  }

  /// Resolves the Node executable to use for a given config, without
  /// re-running provisioning: the ready managed/override/system path if
  /// available, else the config's own override, else a bare 'node' as a
  /// last resort. Shared by BridgeService and McpService so the precedence
  /// rules live in exactly one place.
  String resolveExecutable(BridgeConfig config) {
    if (isReady) return nodePath!;
    return config.nodePath ?? 'node';
  }

  String _commit(String path, String version) {
    _nodePath = path;
    _status = NodeProvisionStatus.ready;
    _currentVersion = version;
    notifyListeners();
    return path;
  }

  /// Builds a SystemRequirement describing the managed Node's current
  /// state, so SystemCheckerService doesn't need its own copy of this
  /// status->requirement mapping.
  SystemRequirement buildRequirement() {
    switch (_status) {
      case NodeProvisionStatus.downloading:
        return SystemRequirement(
          name: 'Node.js',
          description: 'Downloading managed Node.js...',
          status: RequirementStatus.checking,
          currentVersion: '${(_downloadProgress * 100).toStringAsFixed(0)}%',
        );
      case NodeProvisionStatus.ready:
        return SystemRequirement(
          name: 'Node.js',
          description: 'Managed runtime',
          status: RequirementStatus.met,
          currentVersion: _currentVersion ?? 'installed',
        );
      case NodeProvisionStatus.error:
        return SystemRequirement(
          name: 'Node.js',
          description: 'Failed to provision managed Node.js',
          status: RequirementStatus.error,
          currentVersion: _errorMessage,
        );
      case NodeProvisionStatus.checking:
      case NodeProvisionStatus.notAvailable:
        return SystemRequirement(
          name: 'Node.js',
          description: 'Required to run the bridge server',
          status: RequirementStatus.missing,
          requiredVersion: '>= ${AppConstants.minNodeVersion}',
          installUrl: 'https://nodejs.org/',
        );
    }
  }

  Future<String?> _managedNodePath() async {
    final appDir = await AppUtils.getAppDirectory();
    const version = AppConstants.pinnedNodeVersion;

    if (Platform.isWindows) {
      final path = '${appDir.path}/node/$version/node.exe';
      if (await File(path).exists()) return path;
    } else {
      final path = '${appDir.path}/node/$version/bin/node';
      if (await File(path).exists()) return path;
    }
    return null;
  }

  /// Runs `<path> --version` once and returns the version string if it's a
  /// working Node binary meeting the minimum version floor, else null.
  /// Combined into one probe (rather than a separate test-then-fetch-version
  /// pair) so each candidate path only spawns one process instead of two.
  Future<String?> _probeNode(String path) async {
    try {
      final result = await Process.run(path, ['--version']);
      if (result.exitCode != 0) return null;

      final version = result.stdout.toString().trim();
      if (!version.startsWith('v')) return null;

      // Reject a working but too-old Node - the bundles are built with
      // `--target=node18` and can fail at runtime on anything older.
      final major = int.tryParse(version.substring(1).split('.').first);
      if (major == null || major < AppConstants.minNodeVersion) return null;

      return version;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _findSystemNode() async {
    final List<String> candidates;

    if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      candidates = [
        '/usr/local/bin/node',
        '/usr/bin/node',
        '$home/.nvm/versions/node/*/bin/node',
        '$home/.local/share/fnm/node-versions/*/installation/bin/node',
        '$home/.volta/bin/node',
        '$home/.asdf/shims/node',
      ];
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      candidates = [
        '/opt/homebrew/bin/node',
        '/usr/local/bin/node',
        '$home/.nvm/versions/node/*/bin/node',
        '$home/.local/share/fnm/node-versions/*/installation/bin/node',
        '$home/.volta/bin/node',
        '$home/.asdf/shims/node',
      ];
    } else if (Platform.isWindows) {
      candidates = [
        'C:\\Program Files\\nodejs\\node.exe',
        '${Platform.environment['LOCALAPPDATA']}\\fnm\\multishells\\*\\node.exe',
      ];
    } else {
      return null;
    }

    for (final candidate in candidates) {
      if (candidate.contains('*')) {
        // Handle glob patterns
        final parent = Directory(candidate.split('*')[0]);
        if (await parent.exists()) {
          await for (final entity in parent.list()) {
            if (entity is Directory) {
              final fullPath = '${entity.path}${candidate.split('*')[1]}';
              if (await File(fullPath).exists()) {
                return fullPath;
              }
            }
          }
        }
      } else {
        if (await File(candidate).exists()) {
          return candidate;
        }
      }
    }

    // Fall back to PATH
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['node'],
      );
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().trim().split('\n');
        if (lines.isNotEmpty) {
          return lines.first.trim();
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _downloadAndInstall() async {
    final appDir = await AppUtils.getAppDirectory();
    final arch = await AppConstants.getArch();
    final archiveName = await AppConstants.nodeArchiveNameFor(arch);
    final downloadUrl = '${AppConstants.nodeDistBase}/$archiveName';

    _status = NodeProvisionStatus.downloading;
    _downloadProgress = 0;
    _errorMessage = null;
    notifyListeners();

    debugPrint('Downloading Node.js from: $downloadUrl');

    // Create temp directory
    final tmpDir = Directory('${appDir.path}/node/.tmp-${Random().nextInt(999999)}');
    await tmpDir.create(recursive: true);

    try {
      // Download archive
      final archivePath = '${tmpDir.path}/$archiveName';
      await AppUtils.downloadFile(
        downloadUrl,
        archivePath,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      // Verify SHA-256
      debugPrint('Verifying SHA-256 checksum...');
      await _verifyChecksum(archivePath, archiveName);

      // Extract
      debugPrint('Extracting Node.js...');
      const version = AppConstants.pinnedNodeVersion;
      final targetDir = Directory('${appDir.path}/node/$version');
      await _extractNode(archivePath, archiveName, tmpDir, targetDir);

      debugPrint('Node.js installed to: ${targetDir.path}');
    } finally {
      // Cleanup temp directory
      try {
        if (await tmpDir.exists()) {
          await tmpDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('Warning: Failed to clean up temp dir: $e');
      }
    }
  }

  Future<void> _verifyChecksum(String archivePath, String archiveName) async {
    final shasumsUrl = '${AppConstants.nodeDistBase}/SHASUMS256.txt';
    final response = await http.get(Uri.parse(shasumsUrl));

    if (response.statusCode != 200) {
      debugPrint('Warning: Could not fetch SHASUMS256.txt, skipping verification');
      return;
    }

    final expectedHash = response.body
        .split('\n')
        .where((line) => line.contains(archiveName))
        .map((line) => line.split(RegExp(r'\s+'))[0])
        .firstOrNull;

    if (expectedHash == null) {
      debugPrint('Warning: Could not find checksum for $archiveName, skipping verification');
      return;
    }

    final digest = await AppUtils.sha256OfFile(archivePath);

    if (digest != expectedHash) {
      throw Exception(
        'SHA-256 verification failed for $archiveName.\n'
        'Expected: $expectedHash\n'
        'Got: $digest',
      );
    }

    debugPrint('SHA-256 verification passed');
  }

  Future<void> _extractNode(
    String archivePath,
    String archiveName,
    Directory tmpDir,
    Directory targetDir,
  ) async {
    final bytes = await File(archivePath).readAsBytes();

    Archive archive;
    if (archiveName.endsWith('.tar.xz')) {
      final decompressed = XZDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(decompressed);
    } else if (archiveName.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes);
    } else if (archiveName.endsWith('.tar.gz')) {
      final decompressed = const GZipDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(decompressed);
    } else {
      throw Exception('Unsupported archive format: $archiveName');
    }

    // Create target directory
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // Extract only the node executable
    for (final file in archive) {
      final filename = file.name;

      // Look for the node executable in the archive
      if (Platform.isWindows) {
        // On Windows, we need <root>/node.exe at the archive root
        if (filename.endsWith('node.exe') && !filename.contains('/')) {
          final targetPath = '${targetDir.path}/node.exe';
          await File(targetPath).writeAsBytes(file.content as List<int>);
          debugPrint('Extracted: $targetPath');
          return;
        }
      } else {
        // On POSIX, we need <root>/bin/node
        if (filename.endsWith('/bin/node') && !filename.contains('../')) {
          // Create bin directory
          final binDir = Directory('${targetDir.path}/bin');
          if (!await binDir.exists()) {
            await binDir.create(recursive: true);
          }

          final targetPath = '${targetDir.path}/bin/node';
          await File(targetPath).writeAsBytes(file.content as List<int>);

          // Make executable
          await Process.run('chmod', ['755', targetPath]);
          debugPrint('Extracted: $targetPath');
          return;
        }
      }
    }

    throw Exception('Node executable not found in archive');
  }
}
