import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/system_requirement.dart';
import '../core/constants.dart';

class SystemCheckerService extends ChangeNotifier {
  List<SystemRequirement> _requirements = [];
  bool _isChecking = false;
  int _port = AppConstants.defaultPort;

  List<SystemRequirement> get requirements => _requirements;
  bool get isChecking => _isChecking;
  bool get allMet => _requirements.every((r) => r.isMet);

  void updatePort(int port) {
    _port = port;
  }

  Future<void> checkAll({int? port}) async {
    if (port != null) _port = port;

    _isChecking = true;
    notifyListeners();

    _requirements = [
      await _checkNodeJs(),
      await _checkPortAvailable(),
      await _checkFigmaDesktop(),
      await _checkPluginInstalled(),
    ];

    _isChecking = false;
    notifyListeners();
  }

  Future<SystemRequirement> _checkNodeJs() async {
    try {
      final result = await Process.run('node', ['--version']);
      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        final versionNum =
            int.tryParse(version.replaceAll('v', '').split('.')[0]) ?? 0;

        if (versionNum >= AppConstants.minNodeVersion) {
          return SystemRequirement(
            name: 'Node.js',
            description: 'Required to run the bridge server',
            status: RequirementStatus.met,
            currentVersion: version,
          );
        } else {
          return SystemRequirement(
            name: 'Node.js',
            description: 'Required to run the bridge server',
            status: RequirementStatus.outdated,
            currentVersion: version,
            requiredVersion: '>= ${AppConstants.minNodeVersion}',
            installUrl: 'https://nodejs.org/',
          );
        }
      }
    } catch (e) {
      debugPrint('Node.js check failed: $e');
    }

    return SystemRequirement(
      name: 'Node.js',
      description: 'Required to run the bridge server',
      status: RequirementStatus.missing,
      requiredVersion: '>= ${AppConstants.minNodeVersion}',
      installUrl: 'https://nodejs.org/',
    );
  }

  Future<SystemRequirement> _checkPortAvailable() async {
    try {
      final isRunning = await _isServerRunning();
      if (isRunning) {
        return SystemRequirement(
          name: 'Port $_port',
          description: 'Bridge server is running',
          status: RequirementStatus.met,
          currentVersion: 'Server active',
        );
      }

      final socket = await ServerSocket.bind('127.0.0.1', _port);
      await socket.close();

      return SystemRequirement(
        name: 'Port $_port',
        description: 'Required for bridge server communication',
        status: RequirementStatus.met,
        currentVersion: 'Available',
      );
    } catch (e) {
      return SystemRequirement(
        name: 'Port $_port',
        description: 'Required for bridge server communication',
        status: RequirementStatus.missing,
      );
    }
  }

  Future<bool> _isServerRunning() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$_port/health'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 2),
      );
      await response.drain();
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<SystemRequirement> _checkFigmaDesktop() async {
    try {
      final result = await Process.run('pgrep', ['-f', 'Figma']);
      if (result.exitCode == 0) {
        return SystemRequirement(
          name: 'Figma Desktop',
          description: 'Required to use the bridge plugin',
          status: RequirementStatus.met,
        );
      }
    } catch (e) {
      debugPrint('Figma check failed: $e');
    }

    return SystemRequirement(
      name: 'Figma Desktop',
      description: 'Required to use the bridge plugin',
      status: RequirementStatus.missing,
      installUrl: 'https://www.figma.com/downloads/',
    );
  }

  Future<SystemRequirement> _checkPluginInstalled() async {
    try {
      // B20: Only check standard Figma Development directories, no personal paths
      final home = Platform.environment['HOME'] ?? '';
      final appData = Platform.environment['APPDATA'];

      final pluginPaths = [
        '$home/.config/figma/Development/figma-mcp-free',
        '$home/Library/Application Support/Figma/Development/figma-mcp-free',
        if (appData != null) '$appData\\Figma\\Development\\figma-mcp-free',
      ];

      for (final pluginPath in pluginPaths) {
        final manifestFile = File('$pluginPath/manifest.json');
        if (await manifestFile.exists()) {
          final content = await manifestFile.readAsString();
          if (content.contains('figma-mcp-free') ||
              content.contains('Local Bridge')) {
            return SystemRequirement(
              name: 'Figma MCP Plugin',
              description: 'Bridge plugin for Figma',
              status: RequirementStatus.met,
              currentVersion: pluginPath,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Plugin check failed: $e');
    }

    return SystemRequirement(
      name: 'Figma MCP Plugin',
      description: 'Bridge plugin for Figma',
      status: RequirementStatus.missing,
    );
  }
}
