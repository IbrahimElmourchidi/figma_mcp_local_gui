import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ProcessManagerService {
  Process? _serverProcess;
  final StreamController<String> _stdoutController =
      StreamController<String>.broadcast();
  final StreamController<String> _stderrController =
      StreamController<String>.broadcast();
  final StreamController<int> _exitCodeController =
      StreamController<int>.broadcast();
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  bool _disposed = false;

  Stream<String> get stdout => _stdoutController.stream;
  Stream<String> get stderr => _stderrController.stream;
  Stream<int> get exitCode => _exitCodeController.stream;

  bool get isRunning => _serverProcess != null && _serverProcess!.pid > 0;

  Future<void> startProcess(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (isRunning) {
      throw Exception('Process already running');
    }

    try {
      _serverProcess = await Process.start(
        executable,
        args,
        workingDirectory: workingDirectory,
        environment: environment,
        mode: ProcessStartMode.normal,
      );

      _stdoutSub = _serverProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (!_disposed) {
              _stdoutController.add(line);
            }
          });

      _stderrSub = _serverProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (!_disposed) {
              _stderrController.add(line);
            }
          });

      _serverProcess!.exitCode.then((code) {
        _serverProcess = null;
        if (!_disposed) {
          _exitCodeController.add(code);
        }
      });
    } catch (e) {
      _serverProcess = null;
      throw Exception('Failed to start process: $executable\n$e');
    }
  }

  Future<void> stopProcess() async {
    if (!isRunning) return;

    try {
      _serverProcess!.kill(ProcessSignal.sigterm);
      await _serverProcess!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _serverProcess!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (e) {
      _serverProcess?.kill(ProcessSignal.sigkill);
    } finally {
      _serverProcess = null;
    }
  }

  void dispose() {
    _disposed = true;
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    stopProcess().then((_) {
      _stdoutController.close();
      _stderrController.close();
      _exitCodeController.close();
    });
  }
}
