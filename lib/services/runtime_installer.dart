import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/utils.dart';

/// Manages copying bundled runtime files to the app data directory.
/// Re-copies when the bundled VERSION differs from the installed one.
class RuntimeInstaller {
  static const String _versionFile = 'VERSION';
  static const String _mcpServerFile = 'mcp-server.cjs';
  static const String _bridgeCliFile = 'bridge-cli.cjs';

  /// Ensure runtime is installed in the app data directory.
  /// Returns the path to the runtime directory.
  static Future<String> ensureInstalled() async {
    final appDir = await AppUtils.getAppDirectory();
    final runtimeDir = Directory('${appDir.path}/runtime');

    // Create runtime directory if it doesn't exist
    if (!await runtimeDir.exists()) {
      await runtimeDir.create(recursive: true);
    }

    // Check if we need to update
    final installedVersionFile = File('${runtimeDir.path}/$_versionFile');
    final needsUpdate = await _needsUpdate(installedVersionFile);

    if (needsUpdate) {
      debugPrint('Installing/updating runtime...');
      await _copyBundledFiles(runtimeDir);
    }

    return runtimeDir.path;
  }

  /// Check if the installed version differs from bundled
  static Future<bool> _needsUpdate(File installedVersionFile) async {
    if (!await installedVersionFile.exists()) {
      return true; // Not installed yet
    }

    try {
      final installedVersion = await installedVersionFile.readAsString();
      final bundledVersion = await _loadBundledVersion();
      return installedVersion.trim() != bundledVersion.trim();
    } catch (e) {
      debugPrint('Error checking version: $e');
      return true;
    }
  }

  /// Load bundled VERSION from Flutter assets
  static Future<String> _loadBundledVersion() async {
    try {
      final data = await rootBundle.load('assets/bundled/$_versionFile');
      return String.fromCharCodes(data.buffer.asUint8List()).trim();
    } catch (e) {
      debugPrint('Bundled VERSION not found, using "unknown": $e');
      return 'unknown';
    }
  }

  /// Copy all bundled files to the runtime directory
  static Future<void> _copyBundledFiles(Directory runtimeDir) async {
    final files = [_mcpServerFile, _bridgeCliFile, _versionFile];

    for (final file in files) {
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

    debugPrint('Runtime installed to: ${runtimeDir.path}');
  }

  /// Get the path to the MCP server executable
  static Future<String> getMcpServerPath() async {
    final runtimeDir = await ensureInstalled();
    final path = '$runtimeDir/$_mcpServerFile';

    if (!await File(path).exists()) {
      throw Exception('MCP server not found at: $path');
    }

    return path;
  }

  /// Get the path to the bridge CLI executable
  static Future<String> getBridgeCliPath() async {
    final runtimeDir = await ensureInstalled();
    final path = '$runtimeDir/$_bridgeCliFile';

    if (!await File(path).exists()) {
      throw Exception('Bridge CLI not found at: $path');
    }

    return path;
  }

  /// Force reinstall (for debugging or recovery)
  static Future<void> forceReinstall() async {
    final appDir = await AppUtils.getAppDirectory();
    final runtimeDir = Directory('${appDir.path}/runtime');

    if (await runtimeDir.exists()) {
      await runtimeDir.delete(recursive: true);
    }

    await ensureInstalled();
  }

  /// Check if runtime is installed and healthy
  static Future<bool> isHealthy() async {
    try {
      final runtimeDir = await ensureInstalled();
      final mcpServer = File('$runtimeDir/$_mcpServerFile');
      final bridgeCli = File('$runtimeDir/$_bridgeCliFile');

      return await mcpServer.exists() && await bridgeCli.exists();
    } catch (e) {
      return false;
    }
  }
}
