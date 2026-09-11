import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/utils.dart';

class RuntimeManifest {
  final int schema;
  final String upstreamRepo;
  final String upstreamSha;
  final String? upstreamCommittedAt;
  final String? builtAt;
  final String? builtBy;
  final String? esbuildVersion;
  final String? nodeTarget;
  final Map<String, String> files;

  RuntimeManifest({
    this.schema = 1,
    required this.upstreamRepo,
    required this.upstreamSha,
    this.upstreamCommittedAt,
    this.builtAt,
    this.builtBy,
    this.esbuildVersion,
    this.nodeTarget,
    this.files = const {},
  });

  factory RuntimeManifest.fromJson(Map<String, dynamic> json) {
    final filesMap = <String, String>{};
    if (json['files'] is Map) {
      (json['files'] as Map).forEach((key, value) {
        filesMap[key.toString()] = value.toString();
      });
    }

    return RuntimeManifest(
      schema: json['schema'] ?? 1,
      upstreamRepo: json['upstreamRepo'] ?? '',
      upstreamSha: json['upstreamSha'] ?? '',
      upstreamCommittedAt: json['upstreamCommittedAt'],
      builtAt: json['builtAt'],
      builtBy: json['builtBy'],
      esbuildVersion: json['esbuildVersion'],
      nodeTarget: json['nodeTarget'],
      files: filesMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema': schema,
      'upstreamRepo': upstreamRepo,
      'upstreamSha': upstreamSha,
      if (upstreamCommittedAt != null) 'upstreamCommittedAt': upstreamCommittedAt,
      if (builtAt != null) 'builtAt': builtAt,
      if (builtBy != null) 'builtBy': builtBy,
      if (esbuildVersion != null) 'esbuildVersion': esbuildVersion,
      if (nodeTarget != null) 'nodeTarget': nodeTarget,
      'files': files,
    };
  }
}

class RuntimeInstaller {
  static const String _versionFile = 'VERSION';
  static const String _manifestFile = 'runtime.json';
  static const String _mcpServerFile = 'mcp-server.cjs';
  static const String _bridgeCliFile = 'bridge-cli.cjs';
  static const String _pluginDir = 'plugin';
  static const String _pluginCode = 'code.js';
  static const String _pluginUi = 'ui.html';
  static const String _pluginManifest = 'manifest.template.json';

  static Future<Directory> _getRuntimeDir() async {
    final appDir = await AppUtils.getAppDirectory();
    return Directory('${appDir.path}/runtime');
  }

  /// Where a caller should stage a runtime update before calling
  /// [stageAndSwap]. Deliberately a SIBLING of the runtime directory, not a
  /// child of it: stageAndSwap renames the live runtime directory out of
  /// the way as its first step, and renaming a directory carries its
  /// children with it - staging inside runtime/ would move the staged
  /// files to runtime.previous/ along with it and make the swap's second
  /// rename fail with "no such file or directory".
  static Future<String> getStagingPath() async {
    final appDir = await AppUtils.getAppDirectory();
    return '${appDir.path}/runtime-staging';
  }

  // Serializes ensureInstalled/stageAndSwap/forceReinstall/rollback so two
  // concurrent callers (e.g. BootstrapService's runtimeReady step racing an
  // auto-started BridgeService resolving its server path) never write into
  // the runtime directory at the same time and tear a file.
  static Future<void>? _opLock;

  static Future<T> _withLock<T>(Future<T> Function() action) async {
    while (_opLock != null) {
      try {
        await _opLock;
      } catch (_) {
        // Ignore a previous operation's failure; we only wait for it to
        // finish so our own write doesn't race it.
      }
    }
    final completer = Completer<void>();
    _opLock = completer.future;
    try {
      return await action();
    } finally {
      completer.complete();
      _opLock = null;
    }
  }

  static Future<String> ensureInstalled() => _withLock(_ensureInstalledLocked);

  static Future<String> _ensureInstalledLocked() async {
    final runtimeDir = await _getRuntimeDir();

    if (!await runtimeDir.exists()) {
      await runtimeDir.create(recursive: true);
    }

    final manifestFile = File('${runtimeDir.path}/$_manifestFile');
    final versionFile = File('${runtimeDir.path}/$_versionFile');
    final needsUpdate = await _needsUpdate(runtimeDir, manifestFile, versionFile);

    if (needsUpdate) {
      debugPrint('Installing runtime from bundled seed...');
      await _copyBundledFiles(runtimeDir);
    }

    return runtimeDir.path;
  }

  // Only seeds from the app-bundled runtime the first time (nothing
  // installed yet), or self-heals if the installed runtime is missing its
  // core files. It deliberately does NOT reinstall just because the bundled
  // seed's upstreamSha differs from what's installed: the installed runtime
  // may be strictly newer than the bundled seed (applied via
  // RuntimeUpdateService, whose SHA this app build was never rebuilt to
  // match), and upstream SHAs aren't ordered, so "different" doesn't mean
  // "bundled is newer". Overwriting on every mismatch previously reverted
  // every runtime update on the very next launch.
  static Future<bool> _needsUpdate(
    Directory runtimeDir,
    File manifestFile,
    File versionFile,
  ) async {
    final hasManifest = await manifestFile.exists();
    final hasLegacyVersion = await versionFile.exists();

    if (!hasManifest && !hasLegacyVersion) {
      return true; // Nothing installed yet.
    }

    // Something is already installed. Self-heal only if the core files are
    // actually missing (e.g. an interrupted previous install).
    final mcpServer = File('${runtimeDir.path}/$_mcpServerFile');
    final bridgeCli = File('${runtimeDir.path}/$_bridgeCliFile');
    if (!await mcpServer.exists() || !await bridgeCli.exists()) {
      debugPrint('Installed runtime is missing core files, reinstalling from bundled seed');
      return true;
    }

    return false;
  }

  static Future<void> _copyBundledFiles(Directory runtimeDir) async {
    // Copy core runtime files
    final coreFiles = [_mcpServerFile, _bridgeCliFile, _versionFile];
    for (final file in coreFiles) {
      try {
        final data = await rootBundle.load('assets/bundled/$file');
        final bytes = data.buffer.asUint8List();
        await File('${runtimeDir.path}/$file').writeAsBytes(bytes);
        debugPrint('Copied: assets/bundled/$file -> ${runtimeDir.path}/$file');
      } catch (e) {
        debugPrint('Failed to copy $file: $e');
        rethrow;
      }
    }

    // Copy runtime.json if bundled
    try {
      final data = await rootBundle.load('assets/bundled/$_manifestFile');
      final bytes = data.buffer.asUint8List();
      await File('${runtimeDir.path}/$_manifestFile').writeAsBytes(bytes);
    } catch (_) {
      // runtime.json may not exist in bundled assets for legacy builds
    }

    // Copy plugin files to runtime directory
    final pluginDir = Directory('${runtimeDir.path}/$_pluginDir');
    if (!await pluginDir.exists()) {
      await pluginDir.create(recursive: true);
    }

    final pluginFiles = [_pluginCode, _pluginUi, _pluginManifest];
    for (final file in pluginFiles) {
      try {
        final data = await rootBundle.load('assets/plugins/$file');
        final bytes = data.buffer.asUint8List();
        await File('${pluginDir.path}/$file').writeAsBytes(bytes);
        debugPrint('Copied: assets/plugins/$file -> ${pluginDir.path}/$file');
      } catch (e) {
        debugPrint('Failed to copy plugin file $file: $e');
      }
    }

    debugPrint('Runtime installed to: ${runtimeDir.path}');
  }

  static Future<String> getMcpServerPath() async {
    final runtimePath = await ensureInstalled();
    final path = '$runtimePath/$_mcpServerFile';

    if (!await File(path).exists()) {
      throw Exception('MCP server not found at: $path');
    }

    return path;
  }

  static Future<String> getBridgeCliPath() async {
    final runtimePath = await ensureInstalled();
    final path = '$runtimePath/$_bridgeCliFile';

    if (!await File(path).exists()) {
      throw Exception('Bridge CLI not found at: $path');
    }

    return path;
  }

  static Future<String> getPluginDir() async {
    final runtimePath = await ensureInstalled();
    return '$runtimePath/$_pluginDir';
  }

  static Future<RuntimeManifest?> getInstalledManifest() async {
    final runtimeDir = await _getRuntimeDir();
    final manifestFile = File('${runtimeDir.path}/$_manifestFile');

    if (await manifestFile.exists()) {
      try {
        final content = await manifestFile.readAsString();
        return RuntimeManifest.fromJson(jsonDecode(content));
      } catch (_) {}
    }

    // Try legacy VERSION
    final versionFile = File('${runtimeDir.path}/$_versionFile');
    if (await versionFile.exists()) {
      try {
        final sha = await versionFile.readAsString();
        return RuntimeManifest(
          upstreamRepo: 'superdoccimo/figma-mcp-free',
          upstreamSha: sha.trim(),
        );
      } catch (_) {}
    }

    return null;
  }

  static Future<void> stageAndSwap(Directory staged) =>
      _withLock(() => _stageAndSwapLocked(staged));

  static Future<void> _stageAndSwapLocked(Directory staged) async {
    final runtimeDir = await _getRuntimeDir();
    final previousDir = Directory('${runtimeDir.path}.previous');
    final manifestFile = File('${staged.path}/$_manifestFile');

    // Verify files against manifest if present
    if (await manifestFile.exists()) {
      final content = await manifestFile.readAsString();
      final manifest = RuntimeManifest.fromJson(jsonDecode(content));

      for (final entry in manifest.files.entries) {
        final file = File('${staged.path}/${entry.key}');
        if (!await file.exists()) {
          throw Exception('Staged file missing: ${entry.key}');
        }
        final digest = await AppUtils.sha256OfFile(file.path);
        if (digest != entry.value) {
          throw Exception(
            'SHA-256 mismatch for ${entry.key}:\n'
            'Expected: ${entry.value}\n'
            'Got: $digest',
          );
        }
      }
    }

    // Swap: keep previous for rollback
    if (await runtimeDir.exists()) {
      if (await previousDir.exists()) {
        await previousDir.delete(recursive: true);
      }
      await runtimeDir.rename(previousDir.path);
    }

    await staged.rename(runtimeDir.path);
    debugPrint('Runtime swapped: ${runtimeDir.path}');
  }

  static Future<void> rollback() => _withLock(_rollbackLocked);

  static Future<void> _rollbackLocked() async {
    final runtimeDir = await _getRuntimeDir();
    final previousDir = Directory('${runtimeDir.path}.previous');

    if (!await previousDir.exists()) {
      throw Exception('No previous runtime available for rollback');
    }

    if (await runtimeDir.exists()) {
      await runtimeDir.delete(recursive: true);
    }

    await previousDir.rename(runtimeDir.path);
    debugPrint('Runtime rolled back');
  }

  static Future<bool> hasRollbackAvailable() async {
    final previousDir = Directory('${(await _getRuntimeDir()).path}.previous');
    return previousDir.exists();
  }

  static Future<void> forceReinstall() => _withLock(() async {
    final runtimeDir = await _getRuntimeDir();

    if (await runtimeDir.exists()) {
      await runtimeDir.delete(recursive: true);
    }

    await _ensureInstalledLocked();
  });

  static Future<bool> isHealthy() async {
    try {
      final runtimeDir = await _getRuntimeDir();
      final mcpServer = File('${runtimeDir.path}/$_mcpServerFile');
      final bridgeCli = File('${runtimeDir.path}/$_bridgeCliFile');

      return await mcpServer.exists() && await bridgeCli.exists();
    } catch (e) {
      return false;
    }
  }

  static Future<String> getRuntimePath() async {
    final runtimeDir = await _getRuntimeDir();
    return runtimeDir.path;
  }
}
