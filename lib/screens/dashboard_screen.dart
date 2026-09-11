import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/bridge_service.dart';
import '../services/mcp_service.dart';
import '../services/plugin_manager.dart';
import '../widgets/server_status_card.dart';
import '../widgets/token_display.dart';
import '../widgets/connection_test.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<BridgeService, McpService>(
      builder: (context, bridgeService, mcpService, child) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wrap (not Row) so the control buttons drop to their own
              // line instead of overflowing when the window is narrow or
              // several buttons are visible at once (bridge + MCP running).
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  _buildServerControls(context, bridgeService, mcpService),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ServerStatusCard(state: bridgeService.state),
                      const SizedBox(height: 16),

                      if (bridgeService.state.isRunning)
                        TokenDisplay(
                          token: bridgeService.config.password,
                          url: bridgeService.state.url ?? '',
                        ),

                      const SizedBox(height: 16),
                      ConnectionTest(
                        isRunning: bridgeService.state.isRunning,
                        host: bridgeService.config.host,
                        port: bridgeService.config.port,
                        token: bridgeService.state.isRunning
                            ? bridgeService.config.password
                            : null,
                      ),

                      const SizedBox(height: 16),
                      _FigmaPluginCard(port: bridgeService.config.port),

                      const SizedBox(height: 16),
                      _buildOpenCodeConfigCard(
                        context,
                        bridgeService,
                        mcpService,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServerControls(
    BuildContext context,
    BridgeService bridgeService,
    McpService mcpService,
  ) {
    final isBridgeRunning = bridgeService.state.isRunning;
    final isBridgeStarting = bridgeService.state.isStarting;
    final isBridgeStopping = bridgeService.state.isStopping;
    final isMcpRunning = mcpService.state.isRunning;

    // Wrap (not Row): up to 4 buttons can be visible at once (bridge +
    // MCP both running), which overflows a fixed Row at moderate window
    // widths - Wrap drops extra buttons to a new line instead.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: isBridgeStarting || isBridgeStopping
              ? null
              : () async {
                  await bridgeService.killOrphanedProcesses();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Orphaned processes killed'),
                      ),
                    );
                  }
                },
          icon: const Icon(Icons.cleaning_services),
          label: const Text('Kill Orphans'),
        ),

        if (isBridgeRunning)
          if (isMcpRunning)
            OutlinedButton.icon(
              onPressed: () => mcpService.stop(),
              icon: const Icon(Icons.stop, size: 16),
              label: const Text('Stop MCP'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => mcpService.start(bridgeService.config),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Start MCP'),
            ),

        if (isBridgeRunning) ...[
          ElevatedButton.icon(
            onPressed: isBridgeStopping
                ? null
                : () => bridgeService.stopServer(),
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          OutlinedButton.icon(
            onPressed: isBridgeStopping
                ? null
                : () => bridgeService.restartServer(),
            icon: const Icon(Icons.refresh),
            label: const Text('Restart'),
          ),
        ] else
          ElevatedButton.icon(
            onPressed: isBridgeStarting
                ? null
                : () => bridgeService.startServer(),
            icon: isBridgeStarting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(isBridgeStarting ? 'Starting...' : 'Start Server'),
          ),
      ],
    );
  }

  Widget _buildOpenCodeConfigCard(
    BuildContext context,
    BridgeService bridgeService,
    McpService mcpService,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'opencode Configuration',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Configure opencode CLI to use this MCP server.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: bridgeService.state.isRunning
                      ? () => _configureOpenCode(context, bridgeService)
                      : null,
                  icon: const Icon(Icons.settings),
                  label: const Text('Configure opencode'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showOpenCodeConfig(context, bridgeService),
                  icon: const Icon(Icons.preview),
                  label: const Text('Preview Config'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configureOpenCode(
    BuildContext context,
    BridgeService bridgeService,
  ) async {
    try {
      final config = bridgeService.config;

      // Find MCP server path using the service resolver
      final mcpService = context.read<McpService>();
      String mcpPath;
      try {
        mcpPath = await mcpService.findMcpServerPath(config.mcpServerPath);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('MCP server not found: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final opencodeConfig = McpService.generateOpenCodeConfig(
        mcpServerPath: mcpPath,
        bridgeToken: config.password,
        bridgePort: config.port,
        figmaToken: config.figmaToken,
      );

      await McpService.saveOpenCodeConfig(opencodeConfig);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'opencode configured! Restart opencode to use MCP server.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error configuring opencode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOpenCodeConfig(BuildContext context, BridgeService bridgeService) {
    final config = bridgeService.config;

    // Use placeholder for preview
    final mcpPath = config.mcpServerPath ?? '<mcp-server-path>';

    final opencodeConfig = McpService.generateOpenCodeConfig(
      mcpServerPath: mcpPath,
      bridgeToken: config.password,
      bridgePort: config.port,
      figmaToken: config.figmaToken,
    );

    final configJson = const JsonEncoder.withIndent('    ')
        .convert(opencodeConfig);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('opencode Configuration'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add this to ~/.config/opencode/opencode.json:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  configJson,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Surfaces PluginManagerService in the UI. Previously this service had
/// no screen or widget calling it at all - `installPlugin`/`uninstallPlugin`
/// /`checkInstallation` existed but were unreachable from the app, so the
/// Figma plugin always had to be installed by hand.
class _FigmaPluginCard extends StatefulWidget {
  final int port;

  const _FigmaPluginCard({required this.port});

  @override
  State<_FigmaPluginCard> createState() => _FigmaPluginCardState();
}

class _FigmaPluginCardState extends State<_FigmaPluginCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PluginManagerService>().checkInstallation();
    });
  }

  Future<void> _install(PluginManagerService plugin) async {
    try {
      await plugin.installPlugin(port: widget.port);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Figma plugin installed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Install failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uninstall(PluginManagerService plugin) async {
    try {
      await plugin.uninstallPlugin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Figma plugin uninstalled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uninstall failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PluginManagerService>(
      builder: (context, plugin, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.extension,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Figma Plugin',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Icon(
                      plugin.isInstalled
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 16,
                      color: plugin.isInstalled
                          ? Colors.green
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(plugin.isInstalled ? 'Installed' : 'Not installed'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  plugin.isInstalled
                      ? plugin.pluginPath ?? ''
                      : 'Copies the bridge plugin into Figma\'s Development directory '
                            '(import it there as a development plugin).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _install(plugin),
                      icon: const Icon(Icons.download),
                      label: Text(plugin.isInstalled ? 'Reinstall' : 'Install'),
                    ),
                    if (plugin.isInstalled) ...[
                      OutlinedButton.icon(
                        onPressed: () => plugin.openPluginFolder(),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Open Folder'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _uninstall(plugin),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Uninstall'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
