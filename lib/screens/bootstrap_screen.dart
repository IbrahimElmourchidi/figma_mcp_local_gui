import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/bootstrap_service.dart';

class BootstrapScreen extends StatelessWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BootstrapService>(
      builder: (context, bootstrap, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.extension,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Starting up',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preparing runtime components...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildStepProgress(context, bootstrap),
                  if (bootstrap.progress.hasError && !bootstrap.isRunning) ...[
                    const SizedBox(height: 16),
                    Text(
                      bootstrap.progress.errorMessage ?? 'An error occurred',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => bootstrap.retry(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepProgress(BuildContext context, BootstrapService bootstrap) {
    return Column(
      children: [
        _buildStep(
          context,
          'Provisioning Node.js',
          bootstrap.progress.getStatus(BootstrapStep.nodeReady),
        ),
        const SizedBox(height: 12),
        _buildStep(
          context,
          'Installing runtime',
          bootstrap.progress.getStatus(BootstrapStep.runtimeReady),
        ),
        const SizedBox(height: 12),
        _buildStep(
          context,
          'Checking runtime updates',
          bootstrap.progress.getStatus(BootstrapStep.runtimeUpdateChecked),
        ),
        const SizedBox(height: 12),
        _buildStep(
          context,
          'Checking app updates',
          bootstrap.progress.getStatus(BootstrapStep.appUpdateChecked),
        ),
      ],
    );
  }

  Widget _buildStep(
    BuildContext context,
    String label,
    BootstrapStepStatus status,
  ) {
    return Row(
      children: [
        _buildStatusIcon(status),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: status == BootstrapStepStatus.error
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(BootstrapStepStatus status) {
    switch (status) {
      case BootstrapStepStatus.pending:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case BootstrapStepStatus.running:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case BootstrapStepStatus.complete:
        return const Icon(Icons.check_circle, size: 20, color: Colors.green);
      case BootstrapStepStatus.error:
        return const Icon(Icons.error, size: 20, color: Colors.red);
      case BootstrapStepStatus.skipped:
        return const Icon(Icons.skip_next, size: 20, color: Colors.grey);
    }
  }
}
