import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';

class PluginManagerService extends ChangeNotifier {
  bool _isInstalled = false;
  String? _pluginPath;

  bool get isInstalled => _isInstalled;
  String? get pluginPath => _pluginPath;

  Future<void> checkInstallation() async {
    try {
      final pluginDir = await _findFigmaPluginDirectory();
      if (pluginDir != null) {
        final manifestFile = File(
          '${pluginDir.path}/figma-mcp-free/manifest.json',
        );
        _isInstalled = await manifestFile.exists();
        _pluginPath = _isInstalled ? '${pluginDir.path}/figma-mcp-free' : null;
      } else {
        _isInstalled = false;
        _pluginPath = null;
      }
    } catch (e) {
      debugPrint('Plugin check failed: $e');
      _isInstalled = false;
      _pluginPath = null;
    }
    notifyListeners();
  }

  Future<void> installPlugin({int port = AppConstants.defaultPort}) async {
    try {
      final pluginDir = await _findFigmaPluginDirectory();
      if (pluginDir == null) {
        throw Exception('Figma development directory not found');
      }

      final targetDir = Directory('${pluginDir.path}/figma-mcp-free');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // B11: Use rootBundle to load assets from Flutter bundle
      await _copyAsset('assets/plugins/code.js', '${targetDir.path}/code.js');
      await _copyAsset('assets/plugins/ui.html', '${targetDir.path}/ui.html');

      // B12: Make manifest port-aware
      await _copyManifestWithPort('${targetDir.path}/manifest.json', port);

      _isInstalled = true;
      _pluginPath = targetDir.path;
      notifyListeners();
    } catch (e) {
      debugPrint('Plugin install failed: $e');
      rethrow;
    }
  }

  Future<void> uninstallPlugin() async {
    try {
      if (_pluginPath != null) {
        final dir = Directory(_pluginPath!);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }

      _isInstalled = false;
      _pluginPath = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Plugin uninstall failed: $e');
      rethrow;
    }
  }

  Future<void> openPluginFolder() async {
    if (_pluginPath != null) {
      final dir = Directory(_pluginPath!);
      if (await dir.exists()) {
        if (Platform.isLinux) {
          await Process.run('xdg-open', [_pluginPath!]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [_pluginPath!]);
        } else if (Platform.isWindows) {
          await Process.run('explorer', [_pluginPath!]);
        }
      }
    }
  }

  Future<void> _copyAsset(String assetPath, String targetPath) async {
    try {
      // B11: Use rootBundle to load from Flutter assets
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await File(targetPath).writeAsBytes(bytes);
      debugPrint('Copied asset: $assetPath -> $targetPath');
    } catch (e) {
      debugPrint('Failed to copy asset $assetPath: $e');
      rethrow;
    }
  }

  Future<void> _copyManifestWithPort(String targetPath, int port) async {
    try {
      // B12: Load manifest template and rewrite devAllowedDomains with configured port
      final data = await rootBundle.load('assets/plugins/manifest.json');
      final content = utf8.decode(data.buffer.asUint8List());
      final manifest = jsonDecode(content) as Map<String, dynamic>;

      // Update devAllowedDomains to use the configured port. This lives
      // under `networkAccess`, not `api` (which is just an API-version
      // string like "1.0.0") - Figma rejects the plugin's dev-mode
      // fetches to any origin not listed here, so this must match the
      // bridge server's actual port or the plugin can never connect.
      if (manifest['networkAccess'] is Map) {
        final networkAccess = manifest['networkAccess'] as Map<String, dynamic>;
        networkAccess['devAllowedDomains'] = [
          'http://127.0.0.1:$port',
          'http://localhost:$port',
        ];
      }

      // Write updated manifest
      await File(
        targetPath,
      ).writeAsString(const JsonEncoder.withIndent('    ').convert(manifest));
      debugPrint('Wrote manifest with port $port to $targetPath');
    } catch (e) {
      debugPrint('Failed to write manifest: $e');
      rethrow;
    }
  }

  Future<Directory?> _findFigmaPluginDirectory() async {
    final home = Platform.environment['HOME'] ?? '';
    final appData = Platform.environment['APPDATA'];

    final paths = [
      '$home/.config/figma/Development',
      '$home/Library/Application Support/Figma/Development',
      if (appData != null) '$appData\\Figma\\Development',
    ];

    for (final path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        return dir;
      }
    }

    return null;
  }
}
