import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/bridge_config.dart';
import 'runtime_installer.dart';
import 'node_runtime_service.dart';

enum McpStatus { stopped, starting, running, stopping, error }

class McpState {
  final McpStatus status;
  final String? errorMessage;
  final List<String> logs;

  McpState({
    this.status = McpStatus.stopped,
    this.errorMessage,
    this.logs = const [],
  });

  bool get isRunning => status == McpStatus.running;
  bool get isStopped => status == McpStatus.stopped;
  bool get isStarting => status == McpStatus.starting;
  bool get isError => status == McpStatus.error;

  McpState copyWith({
    McpStatus? status,
    String? errorMessage,
    bool clearError = false,
    List<String>? logs,
  }) {
    return McpState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      logs: logs ?? this.logs,
    );
  }
}

class McpService extends ChangeNotifier {
  Process? _mcpProcess;
  McpState _state = McpState();
  final StreamController<String> _stdoutController =
      StreamController<String>.broadcast();
  final StreamController<String> _stderrController =
      StreamController<String>.broadcast();
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  bool _disposed = false;
  NodeRuntimeService? _nodeRuntimeService;

  McpState get state => _state;
  Stream<String> get stdout => _stdoutController.stream;
  Stream<String> get stderr => _stderrController.stream;

  bool get isRunning => _mcpProcess != null && _mcpProcess!.pid > 0;

  void setNodeRuntimeService(NodeRuntimeService service) {
    _nodeRuntimeService = service;
  }

  Future<void> start(BridgeConfig config) async {
    if (isRunning) {
      debugPrint('MCP server already running');
      return;
    }

    _state = McpState(status: McpStatus.starting);
    notifyListeners();

    try {
      final serverPath = await _findMcpServerPath(config.mcpServerPath);

      if (!await File(serverPath).exists()) {
        throw Exception('MCP server not found at: $serverPath');
      }

      final nodeExecutable = _nodeRuntimeService?.resolveExecutable(config) ??
          (config.nodePath ?? 'node');

      final env = Map<String, String>.from(Platform.environment);
      env['FIGMA_PLUGIN_BRIDGE_TOKEN'] = config.password;
      env['FIGMA_PLUGIN_BRIDGE_URL'] = 'http://127.0.0.1:${config.port}';

      if (config.figmaToken != null && config.figmaToken!.isNotEmpty) {
        env['FIGMA_TOKEN'] = config.figmaToken!;
      }

      _mcpProcess = await Process.start(
        nodeExecutable,
        [serverPath],
        environment: env,
        mode: ProcessStartMode.normal,
      );

      _stdoutSub = _mcpProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (!_disposed) {
              _stdoutController.add(line);
              _addLog(line);
            }
          });

      _stderrSub = _mcpProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (!_disposed) {
              _stderrController.add(line);
              _addLog('[ERROR] $line');
            }
          });

      _mcpProcess!.exitCode.then((code) {
        _mcpProcess = null;
        if (!_disposed) {
          _state = _state.copyWith(status: McpStatus.stopped, clearError: true);
          notifyListeners();
        }
      });

      _state = _state.copyWith(status: McpStatus.running, clearError: true);
      notifyListeners();

      debugPrint('MCP server started: $serverPath');
    } catch (e) {
      _state = _state.copyWith(
        status: McpStatus.error,
        errorMessage: 'Failed to start MCP server: $e',
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!isRunning) return;

    _state = _state.copyWith(status: McpStatus.stopping);
    notifyListeners();

    try {
      _mcpProcess?.kill(ProcessSignal.sigterm);
      await _mcpProcess?.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _mcpProcess?.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (e) {
      _mcpProcess?.kill(ProcessSignal.sigkill);
    } finally {
      _mcpProcess = null;
      _state = McpState(status: McpStatus.stopped);
      notifyListeners();
    }
  }

  void _addLog(String log) {
    if (_disposed) return;
    final logs = List<String>.from(_state.logs);
    logs.add(log);
    if (logs.length > 100) {
      logs.removeAt(0);
    }
    _state = _state.copyWith(logs: logs);
    notifyListeners();
  }

  Future<String> findMcpServerPath(String? configuredPath) =>
      _findMcpServerPath(configuredPath);

  Future<String> _findMcpServerPath(String? configuredPath) async {
    if (configuredPath != null && configuredPath.isNotEmpty) {
      if (await File(configuredPath).exists()) {
        return configuredPath;
      }
    }

    try {
      return await RuntimeInstaller.getMcpServerPath();
    } catch (e) {
      debugPrint('Runtime installer failed: $e');
    }

    const devPath = 'assets/bundled/mcp-server.cjs';
    if (await File(devPath).exists()) {
      return devPath;
    }

    throw Exception(
      'MCP server not found. Install figma-mcp-free or set path in settings.\n'
      'Expected at: ~/.local/share/figma_local_mcp_gui/runtime/mcp-server.cjs',
    );
  }

  /// Resolve the opencode config directory, cross-platform.
  static Future<Directory> _getOpenCodeConfigDir() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData == null) {
        throw Exception('APPDATA environment variable not set');
      }
      return Directory('$appData\\opencode');
    }

    // Respect XDG_CONFIG_HOME on Linux, fall back to ~/.config
    if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_CONFIG_HOME'];
      if (xdg != null && xdg.isNotEmpty) {
        return Directory('$xdg/opencode');
      }
    }

    final home = Platform.environment['HOME'];
    if (home == null) throw Exception('HOME environment variable not set');
    return Directory('$home/.config/opencode');
  }

  static Map<String, dynamic> generateOpenCodeConfig({
    required String mcpServerPath,
    required String bridgeToken,
    required int bridgePort,
    String? figmaToken,
    String? nodePath,
  }) {
    final environment = <String, String>{
      'FIGMA_PLUGIN_BRIDGE_TOKEN': bridgeToken,
      'FIGMA_PLUGIN_BRIDGE_URL': 'http://127.0.0.1:$bridgePort',
    };

    if (figmaToken != null && figmaToken.isNotEmpty) {
      environment['FIGMA_TOKEN'] = figmaToken;
    }

    final command = <String>[
      nodePath ?? 'node',
      mcpServerPath,
    ];

    return {
      '\$schema': 'https://opencode.ai/config.json',
      'mcp': {
        'figma-mcp-free': {
          'type': 'local',
          'command': command,
          'environment': environment,
          'enabled': true,
        },
      },
    };
  }

  static Future<void> saveOpenCodeConfig(Map<String, dynamic> config) async {
    final configDir = await _getOpenCodeConfigDir();
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    final configFile = File('${configDir.path}/opencode.json');
    final backupFile = File('${configDir.path}/opencode.json.bak');
    final tempFile = File('${configDir.path}/opencode.json.tmp');

    if (await configFile.exists()) {
      await configFile.copy(backupFile.path);
    }

    Map<String, dynamic> existingConfig = {};
    if (await configFile.exists()) {
      final content = await configFile.readAsString();
      existingConfig = jsonDecode(content);
    }

    if (!existingConfig.containsKey('\$schema')) {
      existingConfig['\$schema'] = 'https://opencode.ai/config.json';
    }

    final existingMcp = existingConfig['mcp'] as Map<String, dynamic>? ?? {};
    final newMcp = config['mcp'] as Map<String, dynamic>;

    for (final entry in newMcp.entries) {
      if (existingMcp.containsKey(entry.key)) {
        existingMcp.remove(entry.key);
      }
      existingMcp[entry.key] = entry.value;
    }

    existingConfig['mcp'] = existingMcp;

    await tempFile.writeAsString(
      const JsonEncoder.withIndent('    ').convert(existingConfig),
    );
    await tempFile.rename(configFile.path);

    debugPrint('Saved opencode config to: ${configFile.path}');
  }

  @override
  void dispose() {
    _disposed = true;
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    stop().then((_) {
      _stdoutController.close();
      _stderrController.close();
    });
    super.dispose();
  }
}
