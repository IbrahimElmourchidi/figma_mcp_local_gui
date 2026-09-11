import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/bridge_config.dart';
import 'node_runtime_service.dart';
import 'runtime_installer.dart';
import 'runtime_update_service.dart';
import 'update_service.dart';

enum BootstrapStep {
  nodeReady,
  runtimeReady,
  runtimeUpdateChecked,
  appUpdateChecked,
}

class BootstrapProgress {
  final Map<BootstrapStep, BootstrapStepStatus> steps;
  final String? errorMessage;

  BootstrapProgress({
    this.steps = const {},
    this.errorMessage,
  });

  BootstrapStepStatus getStatus(BootstrapStep step) =>
      steps[step] ?? BootstrapStepStatus.pending;

  bool get isComplete => steps.values.every(
    (s) => s == BootstrapStepStatus.complete || s == BootstrapStepStatus.skipped,
  );

  bool get hasError => steps.values.any(
    (s) => s == BootstrapStepStatus.error,
  );
}

enum BootstrapStepStatus {
  pending,
  running,
  complete,
  error,
  skipped,
}

class BootstrapService extends ChangeNotifier {
  final NodeRuntimeService _nodeRuntimeService;
  final RuntimeUpdateService _runtimeUpdateService;
  final UpdateService _updateService;

  BootstrapProgress _progress = BootstrapProgress();
  bool _isRunning = false;
  BridgeConfig? _lastConfig;

  BootstrapProgress get progress => _progress;
  bool get isRunning => _isRunning;

  BootstrapService({
    required NodeRuntimeService nodeRuntimeService,
    required RuntimeUpdateService runtimeUpdateService,
    required UpdateService updateService,
  })  : _nodeRuntimeService = nodeRuntimeService,
        _runtimeUpdateService = runtimeUpdateService,
        _updateService = updateService;

  Future<void> run({
    BridgeConfig? config,
    bool skipUpdateChecks = false,
  }) async {
    if (_isRunning) return;
    _lastConfig = config;
    _isRunning = true;
    _progress = BootstrapProgress();
    notifyListeners();

    try {
      // Steps 1+2 (Node provisioning, runtime install) are independent of
      // each other, as are steps 3+4 (the two update checks) - run each
      // pair concurrently rather than back-to-back. _runStep only ever
      // mutates _progress via a synchronous read-modify-write with no
      // await in between, so concurrent steps can't lose each other's
      // status updates. Future.wait's default (eagerError: false) still
      // lets both steps in a pair finish before surfacing either's error,
      // so a Node failure doesn't cut the independent runtime install
      // short.
      await Future.wait([
        _runStep(BootstrapStep.nodeReady, () async {
          await _nodeRuntimeService.ensureNode(
            overrideNodePath: config?.nodePath,
          );
        }),
        _runStep(BootstrapStep.runtimeReady, () async {
          await RuntimeInstaller.ensureInstalled();
        }),
      ]);

      if (!skipUpdateChecks) {
        await Future.wait([
          _runStep(BootstrapStep.runtimeUpdateChecked, () async {
            await _runtimeUpdateService.checkForRuntimeUpdate();
          }, skippable: true),
          _runStep(BootstrapStep.appUpdateChecked, () async {
            await _updateService.checkForUpdates();
          }, skippable: true),
        ]);
      } else {
        _setStep(BootstrapStep.runtimeUpdateChecked, BootstrapStepStatus.skipped);
        _setStep(BootstrapStep.appUpdateChecked, BootstrapStepStatus.skipped);
      }
    } catch (e) {
      // A non-skippable step (Node/runtime) already recorded the error in
      // _progress; just stop here so `finally` below always clears
      // _isRunning instead of leaving the app stuck on the bootstrap screen
      // with no way to retry.
      debugPrint('Bootstrap aborted: $e');
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Re-runs bootstrap after a failure, reusing the last config.
  Future<void> retry() => run(config: _lastConfig);

  Future<void> _runStep(
    BootstrapStep step,
    Future<void> Function() action, {
    bool skippable = false,
  }) async {
    _setStep(step, BootstrapStepStatus.running);

    try {
      await action();
      _setStep(step, BootstrapStepStatus.complete);
    } catch (e) {
      debugPrint('Bootstrap step $step failed: $e');
      _setStep(step, BootstrapStepStatus.error, errorMessage: 'Step $step failed: $e');
      if (!skippable) {
        // Re-throw non-skippable errors
        rethrow;
      }
    }
  }

  /// Single place that mutates _progress, used by every status transition
  /// (running/complete/error/skipped) instead of each repeating its own
  /// `BootstrapProgress(steps: Map.from(_progress.steps)..[step] = ...)`
  /// construction. Also preserves the last non-null errorMessage across
  /// transitions instead of a later step's success silently clearing an
  /// earlier skippable step's recorded error.
  void _setStep(
    BootstrapStep step,
    BootstrapStepStatus status, {
    String? errorMessage,
  }) {
    _progress = BootstrapProgress(
      steps: Map.from(_progress.steps)..[step] = status,
      errorMessage: errorMessage ?? _progress.errorMessage,
    );
    notifyListeners();
  }

  void reset() {
    _progress = BootstrapProgress();
    notifyListeners();
  }
}
