import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/server_status.dart';
import '../models/bridge_config.dart';
import 'process_manager.dart';
import 'runtime_installer.dart';

class BridgeService extends ChangeNotifier {
  /// Loopback hosts the vendored bridge-cli's `--host` flag accepts.
  static const List<String> validHosts = ['127.0.0.1', 'localhost', '::1'];

  final ProcessManagerService _processManager = ProcessManagerService();
  ServerState _state = ServerState();
  BridgeConfig _config = BridgeConfig();
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

  void _onStdout(String line) {
    if (_disposed) return;
    debugPrint('[Bridge] $line');
    _addLog(line);

    // Parse session ID
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
    // B9: Treat SIGTERM (-15) as clean stop if intentional
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

  /// Kill orphaned server processes using the configured port
  Future<void> killOrphanedProcesses() async {
    try {
      // Check if any node process is listening on our port
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

          // Verify the process is actually bridge-cli before killing
          final cmdlineResult = await Process.run('cat', [
            '/proc/$pidNum/cmdline',
          ]);
          if (cmdlineResult.exitCode == 0 &&
              cmdlineResult.stdout.toString().contains('bridge-cli')) {
            debugPrint('Killing orphaned bridge process $pidNum');
            await Process.run('kill', [pidNum]);
            await Future.delayed(const Duration(milliseconds: 200));
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
      // Kill any orphaned processes using this port
      if (killExisting) {
        await killOrphanedProcesses();
      }

      // Find bridge server path
      final serverPath = await _findServerPath();

      // B22: Pass token via env instead of --token flag (avoids ps visibility)
      final env = Map<String, String>.from(Platform.environment);
      env['FIGMA_PLUGIN_BRIDGE_TOKEN'] = _config.password;

      // bridge-cli's --host only accepts these three loopback forms; fall
      // back to the safe default rather than letting the process reject
      // an old/free-typed value saved before the host field was
      // restricted to this list.
      final host = validHosts.contains(_config.host)
          ? _config.host
          : '127.0.0.1';

      // Build command args
      final args = [
        serverPath,
        'serve',
        '--host',
        host,
        '--port',
        _config.port.toString(),
      ];

      // Start the server
      await _processManager.startProcess('node', args, environment: env);

      // Token is now the user's password
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
      // Stop our managed process
      if (_processManager.isRunning) {
        await _processManager.stopProcess();
      }

      // Also kill any orphaned processes
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
    // Try to get from installed runtime (copies from bundled assets if needed)
    try {
      return await RuntimeInstaller.getBridgeCliPath();
    } catch (e) {
      debugPrint('Runtime installer failed: $e');
    }

    // Dev-mode convenience: when run via `flutter run` from the project
    // root, the working directory is the project root itself, so the
    // source asset is also reachable as a plain relative path (this does
    // NOT work in a built/installed app, where rootBundle is the only way
    // to reach bundled assets - that's what RuntimeInstaller uses above).
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
    // Stop our own managed process. Deliberately NOT calling
    // killOrphanedProcesses() here: dispose() is synchronous and can't be
    // awaited by its caller, but killOrphanedProcesses() spawns real `lsof`
    // /`kill` subprocesses - fire-and-forgetting that from dispose() left
    // async work (and OS processes) outliving the widget tree, which is
    // exactly what surfaced as a "Timer still pending after dispose"
    // failure under flutter_test. Orphan cleanup already happens
    // explicitly in startServer() and stopServer(); it doesn't need to
    // run again here too.
    _processManager.stopProcess();
    super.dispose();
  }
}
