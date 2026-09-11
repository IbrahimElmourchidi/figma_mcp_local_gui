import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/bridge_config.dart';
import 'runtime_installer.dart';

class PluginManagerService extends ChangeNotifier {
  bool _isInstalled = false;
  String? _pluginPath;
  String? _installedBundleSha;

  bool get isInstalled => _isInstalled;
  String? get pluginPath => _pluginPath;
  String? get installedBundleSha => _installedBundleSha;

  Future<void> checkInstallation() async {
    try {
      final pluginDir = await _findFigmaPluginDirectory();
      if (pluginDir != null) {
        final manifestFile = File(
          '${pluginDir.path}/figma-mcp-free/manifest.json',
        );
        _isInstalled = await manifestFile.exists();
        _pluginPath = _isInstalled ? '${pluginDir.path}/figma-mcp-free' : null;

        // Record installed bundle SHA for staleness detection
        if (_isInstalled) {
          _installedBundleSha = await _computeInstalledSha(pluginDir.path);
        }
      } else {
        _isInstalled = false;
        _pluginPath = null;
        _installedBundleSha = null;
      }
    } catch (e) {
      debugPrint('Plugin check failed: $e');
      _isInstalled = false;
      _pluginPath = null;
      _installedBundleSha = null;
    }
    notifyListeners();
  }

  Future<String?> _computeInstalledSha(String pluginBasePath) async {
    try {
      final pluginDir = Directory('$pluginBasePath/figma-mcp-free');
      if (!await pluginDir.exists()) return null;

      final files = ['code.js', 'ui.html', 'manifest.json'];
      final bytes = <int>[];

      for (final file in files) {
        final f = File('${pluginDir.path}/$file');
        if (await f.exists()) {
          bytes.addAll(await f.readAsBytes());
        }
      }

      if (bytes.isEmpty) return null;
      return AppUtils.sha256OfBytes(bytes);
    } catch (e) {
      return null;
    }
  }

  Future<bool> isStale() async {
    if (!_isInstalled) return false;

    try {
      // Get SHA of bundled plugin files
      final bundledSha = await _computeBundledSha();
      if (bundledSha == null) return false;

      return _installedBundleSha != bundledSha;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _computeBundledSha() async {
    try {
      final files = ['code.js', 'ui.html', 'manifest.json'];
      final bytes = <int>[];

      for (final file in files) {
        try {
          final data = await rootBundle.load('assets/plugins/$file');
          bytes.addAll(data.buffer.asUint8List());
        } catch (_) {
          // File may not exist in bundle
        }
      }

      if (bytes.isEmpty) return null;
      return AppUtils.sha256OfBytes(bytes);
    } catch (e) {
      return null;
    }
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

      // Prefer sourcing each file from the runtime directory (which travels
      // with runtime updates), falling back to the bundled asset per file -
      // rather than one shared flag for all three files, so a runtime dir
      // that's missing just one file (e.g. an older or partially-staged
      // runtime) doesn't silently skip the fallback for the others and
      // install an incomplete plugin.
      String? runtimePluginDir;
      try {
        final dir = await RuntimeInstaller.getPluginDir();
        if (await Directory(dir).exists()) {
          runtimePluginDir = dir;
        }
      } catch (e) {
        debugPrint('Runtime plugin dir not available: $e');
      }

      // code.js
      final runtimeCodeJs = runtimePluginDir == null
          ? null
          : File('$runtimePluginDir/code.js');
      if (runtimeCodeJs != null && await runtimeCodeJs.exists()) {
        await runtimeCodeJs.copy('${targetDir.path}/code.js');
      } else {
        await _copyAsset('assets/plugins/code.js', '${targetDir.path}/code.js');
      }

      // manifest.json (from manifest.template.json + port/id substitution)
      final runtimeManifestTemplate = runtimePluginDir == null
          ? null
          : File('$runtimePluginDir/manifest.template.json');
      if (runtimeManifestTemplate != null && await runtimeManifestTemplate.exists()) {
        await _installManifestFromTemplate(
          runtimeManifestTemplate.path,
          '${targetDir.path}/manifest.json',
          port,
        );
      } else {
        await _copyManifestWithPort('${targetDir.path}/manifest.json', port);
      }

      // ui.html (with port substitution either way - this used to be a
      // byte-for-byte copy in the bundled-asset fallback, leaving the
      // pairing URL field hardcoded to 3845 on a non-default port)
      final runtimeUiHtml = runtimePluginDir == null
          ? null
          : File('$runtimePluginDir/ui.html');
      if (runtimeUiHtml != null && await runtimeUiHtml.exists()) {
        await _installUiHtmlWithPort(
          runtimeUiHtml.path,
          '${targetDir.path}/ui.html',
          port,
        );
      } else {
        await _installBundledUiHtmlWithPort('${targetDir.path}/ui.html', port);
      }

      _isInstalled = true;
      _pluginPath = targetDir.path;
      _installedBundleSha = await _computeInstalledSha(pluginDir.path);
      notifyListeners();
    } catch (e) {
      debugPrint('Plugin install failed: $e');
      rethrow;
    }
  }

  Future<void> _installManifestFromTemplate(
    String templatePath,
    String targetPath,
    int port,
  ) async {
    final content = await File(templatePath).readAsString();
    final manifest = jsonDecode(content) as Map<String, dynamic>;

    // Replace placeholder plugin ID if needed
    final config = await _loadConfig();
    if (config.figmaPluginId != null && config.figmaPluginId!.isNotEmpty) {
      manifest['id'] = config.figmaPluginId;
    }

    if (manifest['networkAccess'] is Map) {
      final networkAccess = manifest['networkAccess'] as Map<String, dynamic>;
      networkAccess['devAllowedDomains'] = [
        'http://127.0.0.1:$port',
        'http://localhost:$port',
      ];
    }

    await File(targetPath).writeAsString(
      const JsonEncoder.withIndent('    ').convert(manifest),
    );
  }

  Future<void> _installUiHtmlWithPort(
    String sourcePath,
    String targetPath,
    int port,
  ) async {
    var content = await File(sourcePath).readAsString();

    // Replace the hardcoded port in the URL field
    // The template has value="http://127.0.0.1:3845"
    content = content.replaceAll(
      RegExp(r'value="http://127\.0\.0\.1:\d+"'),
      'value="http://127.0.0.1:$port"',
    );

    // Also replace any other hardcoded port references
    content = content.replaceAll(':3845', ':$port');

    await File(targetPath).writeAsString(content);
  }

  Future<void> _installBundledUiHtmlWithPort(String targetPath, int port) async {
    final data = await rootBundle.load('assets/plugins/ui.html');
    var content = utf8.decode(data.buffer.asUint8List());

    content = content.replaceAll(
      RegExp(r'value="http://127\.0\.0\.1:\d+"'),
      'value="http://127.0.0.1:$port"',
    );
    content = content.replaceAll(':3845', ':$port');

    await File(targetPath).writeAsString(content);
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
      _installedBundleSha = null;
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
      final data = await rootBundle.load('assets/plugins/manifest.json');
      final content = utf8.decode(data.buffer.asUint8List());
      final manifest = jsonDecode(content) as Map<String, dynamic>;

      // Replace hardcoded plugin ID with user's if configured
      final config = await _loadConfig();
      if (config.figmaPluginId != null && config.figmaPluginId!.isNotEmpty) {
        manifest['id'] = config.figmaPluginId;
      }

      if (manifest['networkAccess'] is Map) {
        final networkAccess = manifest['networkAccess'] as Map<String, dynamic>;
        networkAccess['devAllowedDomains'] = [
          'http://127.0.0.1:$port',
          'http://localhost:$port',
        ];
      }

      await File(targetPath).writeAsString(
        const JsonEncoder.withIndent('    ').convert(manifest),
      );
      debugPrint('Wrote manifest with port $port to $targetPath');
    } catch (e) {
      debugPrint('Failed to write manifest: $e');
      rethrow;
    }
  }

  Future<BridgeConfig> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('bridge_config');
      if (configJson != null) {
        return BridgeConfig.fromJson(jsonDecode(configJson));
      }
    } catch (_) {}
    return BridgeConfig();
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
