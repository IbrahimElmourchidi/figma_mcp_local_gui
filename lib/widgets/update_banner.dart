import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/bridge_service.dart';
import '../services/mcp_service.dart';
import '../services/update_service.dart';
import '../services/runtime_update_service.dart';

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _dismissedAppUpdate = false;
  bool _dismissedRuntimeUpdate = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<UpdateService, RuntimeUpdateService>(
      builder: (context, updateService, runtimeUpdateService, child) {
        // App update banner
        if (updateService.hasUpdate && !_dismissedAppUpdate) {
          return _buildAppUpdateBanner(context, updateService);
        }

        // Runtime update banner
        if (runtimeUpdateService.hasUpdate && !_dismissedRuntimeUpdate) {
          return _buildRuntimeUpdateBanner(context, runtimeUpdateService);
        }

        // Upstream moved but not built
        if (runtimeUpdateService.upstreamMovedButNotBuilt) {
          return _buildUpstreamMovedBanner(context, runtimeUpdateService);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAppUpdateBanner(BuildContext context, UpdateService service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Row(
        children: [
          Icon(
            Icons.system_update,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update available: ${service.latestUpdate!.version}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (service.latestUpdate!.releaseNotes != null)
                  Text(
                    service.latestUpdate!.releaseNotes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final url = Uri.parse(service.latestUpdate!.downloadUrl);
              await launchUrl(url);
            },
            child: const Text('View'),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => _dismissUpdate('app'),
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeUpdateBanner(
    BuildContext context,
    RuntimeUpdateService service,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: Row(
        children: [
          Icon(
            Icons.update,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Runtime update available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (service.isApplying)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: () => _applyRuntimeUpdate(context, service),
              child: const Text('Update'),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => _dismissUpdate('runtime'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyRuntimeUpdate(
    BuildContext context,
    RuntimeUpdateService service,
  ) async {
    final bridgeService = context.read<BridgeService>();
    final mcpService = context.read<McpService>();
    final bridgeRunning = bridgeService.state.isRunning;
    final mcpRunning = mcpService.isRunning;

    if (bridgeRunning || mcpRunning) {
      final running = [
        if (bridgeRunning) 'bridge server',
        if (mcpRunning) 'MCP server',
      ].join(' and ');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Stop running services?'),
          content: Text(
            'Applying the runtime update replaces files the $running currently '
            'has open. It will be stopped first, then you can start it again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Stop & Update'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      if (bridgeRunning) await bridgeService.stopServer();
      if (mcpRunning) await mcpService.stop();
    }

    final success = await service.applyRuntimeUpdate();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Runtime updated successfully'
              : 'Runtime update failed: ${service.error ?? "unknown error"}',
        ),
        backgroundColor: success ? null : Colors.red,
      ),
    );
  }

  Widget _buildUpstreamMovedBanner(
    BuildContext context,
    RuntimeUpdateService service,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upstream has new changes (CI build pending)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dismissal is per-session only (not persisted): nothing ever read the
  // SharedPreferences key this used to write, so it was persisting a value
  // no code consumed while suggesting a durability the banner didn't
  // actually have.
  void _dismissUpdate(String type) {
    setState(() {
      if (type == 'app') {
        _dismissedAppUpdate = true;
      } else {
        _dismissedRuntimeUpdate = true;
      }
    });
  }
}
