import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/server_status.dart';
import '../models/bridge_config.dart';
import 'process_manager.dart';
import 'runtime_installer.dart';
import 'node_runtime_service.dart';

class BridgeService extends ChangeNotifier {
  static const List<String> validHosts = ['127.0.0.1', 'localhost', '::1'];

  final ProcessManagerService _processManager = ProcessManagerService();
  ServerState _state = ServerState();
  BridgeConfig _config = BridgeConfig();
  NodeRuntimeService? _nodeRuntimeService;
  Timer? _uptimeTimer;
  bool _intentionalStop = false;
  bool _disposed = false;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  StreamSubscription<int>? _exitCodeSub;

  ServerState get state => _state;
  BridgeConfig get config => _config;

  BridgeService() {
    _stdoutSub = _processManager.stdout.listen(_onStdout);
    _stderrSub = _processManager.stderr.listen(_onStderr);
    _exitCodeSub = _processManager.exitCode.listen(_onExitCode);
  }

  void setNodeRuntimeService(NodeRuntimeService service) {
    _nodeRuntimeService = service;
  }

  void _onStdout(String line) {
    if (_disposed) return;
    debugPrint('[Bridge] $line');
    _addLog(line);

    if (line.contains('Session:')) {
      final sessionMatch = RegExp(r'Session:\s*(\S+)').firstMatch(line);
      if (sessionMatch != null) {
        _state = _state.copyWith(sessionId: sessionMatch.group(1));
        notifyListeners();
      }
    }
  }

  void _onStderr(String line) {
    if (_disposed) return;
    debugPrint('[Bridge Error] $line');
    _addLog('[ERROR] $line');
  }

  void _onExitCode(int code) {
    if (_disposed) return;
    final isCleanStop = _intentionalStop || code == 0 || code == -15;

    _state = _state.copyWith(
      status: isCleanStop ? ServerStatus.stopped : ServerStatus.error,
      errorMessage: isCleanStop ? null : 'Process exited with code $code',
      clearError: isCleanStop,
    );
    _intentionalStop = false;
    _stopUptimeTimer();
    notifyListeners();
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

  void _startUptimeTimer() {
    _uptimeTimer?.cancel();
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopUptimeTimer() {
    _uptimeTimer?.cancel();
    _uptimeTimer = null;
  }

  Future<void> killOrphanedProcesses() async {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final lsofResult = await Process.run('lsof', [
          '-i',
          ':${_config.port}',
          '-t',
        ]);
        if (lsofResult.exitCode == 0) {
          final pids = lsofResult.stdout.toString().trim().split('\n');
          for (final pid in pids) {
            if (pid.trim().isEmpty) continue;
            final pidNum = pid.trim();

            if (Platform.isLinux) {
              final cmdlineResult = await Process.run('cat', [
                '/proc/$pidNum/cmdline',
              ]);
              if (cmdlineResult.exitCode == 0 &&
                  cmdlineResult.stdout.toString().contains('bridge-cli')) {
                debugPrint('Killing orphaned bridge process $pidNum');
                await Process.run('kill', [pidNum]);
                await Future.delayed(const Duration(milliseconds: 200));
              }
            } else {
              // macOS has no /proc; verify via `ps` instead so we don't
              // kill an unrelated process that merely happens to be bound
              // to the configured port.
              final psResult = await Process.run('ps', [
                '-p',
                pidNum,
                '-o',
                'command=',
              ]);
              if (psResult.exitCode == 0 &&
                  psResult.stdout.toString().contains('bridge-cli')) {
                debugPrint('Killing orphaned bridge process $pidNum');
                await Process.run('kill', [pidNum]);
                await Future.delayed(const Duration(milliseconds: 200));
              }
            }
          }
        }
      } else if (Platform.isWindows) {
        final netstatResult = await Process.run('netstat', ['-ano', '-p', 'TCP']);
        if (netstatResult.exitCode == 0) {
          final lines = netstatResult.stdout.toString().split('\n');
          for (final line in lines) {
            if (line.contains(':${_config.port}') &&
                line.contains('LISTENING')) {
              final parts = line.trim().split(RegExp(r'\s+'));
              if (parts.isNotEmpty) {
                final pid = parts.last;
                // netstat only gives the PID, not the command line; ask
                // WMI for it so we don't force-kill an unrelated process
                // that happens to be listening on this port.
                final cmdResult = await Process.run('powershell', [
                  '-NoProfile',
                  '-Command',
                  '(Get-CimInstance Win32_Process -Filter "ProcessId=$pid").CommandLine',
                ]);
                if (cmdResult.exitCode == 0 &&
                    cmdResult.stdout.toString().contains('bridge-cli')) {
                  debugPrint('Killing orphaned bridge process $pid');
                  await Process.run('taskkill', ['/PID', pid, '/F']);
                  await Future.delayed(const Duration(milliseconds: 200));
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking orphaned processes: $e');
    }
  }

  Future<void> startServer({
    BridgeConfig? config,
    bool killExisting = true,
  }) async {
    if (_processManager.isRunning) {
      debugPrint('Server already running');
      return;
    }

    _config = config ?? _config;
    _state = ServerState(
      status: ServerStatus.starting,
      host: _config.host,
      port: _config.port,
      logs: [],
    );
    notifyListeners();

    try {
      if (killExisting) {
        await killOrphanedProcesses();
      }

      final serverPath = await _findServerPath();

      final nodeExecutable = _nodeRuntimeService?.resolveExecutable(_config) ??
          (_config.nodePath ?? 'node');

      final env = Map<String, String>.from(Platform.environment);
      env['FIGMA_PLUGIN_BRIDGE_TOKEN'] = _config.password;

      final host = validHosts.contains(_config.host)
          ? _config.host
          : '127.0.0.1';

      final args = [
        serverPath,
        'serve',
        '--host',
        host,
        '--port',
        _config.port.toString(),
      ];

      await _processManager.startProcess(nodeExecutable, args, environment: env);

      _state = _state.copyWith(
        status: ServerStatus.running,
        token: _config.password,
        startedAt: DateTime.now(),
      );
      _startUptimeTimer();
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Failed to start server: $e',
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopServer() async {
    _intentionalStop = true;
    _state = _state.copyWith(status: ServerStatus.stopping);
    notifyListeners();

    try {
      if (_processManager.isRunning) {
        await _processManager.stopProcess();
      }

      await killOrphanedProcesses();

      _state = ServerState(status: ServerStatus.stopped);
      _stopUptimeTimer();
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Failed to stop server: $e',
      );
      notifyListeners();
    } finally {
      _intentionalStop = false;
    }
  }

  Future<void> restartServer() async {
    await stopServer();
    await Future.delayed(const Duration(seconds: 1));
    await startServer();
  }

  Future<String> _findServerPath() async {
    try {
      return await RuntimeInstaller.getBridgeCliPath();
    } catch (e) {
      debugPrint('Runtime installer failed: $e');
    }

    const devPath = 'assets/bundled/bridge-cli.cjs';
    if (await File(devPath).exists()) {
      return devPath;
    }

    throw Exception(
      'Bridge server not found. Install figma-mcp-free or set path in settings.\n'
      'Expected at: ~/.local/share/figma_local_mcp_gui/runtime/bridge-cli.cjs',
    );
  }

  void updateConfig(BridgeConfig config) {
    _config = config;
    notifyListeners();
  }

  void setRunningManually(String token, String sessionId) {
    _state = _state.copyWith(
      token: token,
      sessionId: sessionId,
      status: ServerStatus.running,
      host: _config.host,
      port: _config.port,
      startedAt: DateTime.now(),
    );
    _startUptimeTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _uptimeTimer?.cancel();
    _intentionalStop = true;
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _exitCodeSub?.cancel();
    _processManager.stopProcess();
    super.dispose();
  }
}
