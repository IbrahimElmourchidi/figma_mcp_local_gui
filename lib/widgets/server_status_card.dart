import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/server_status.dart';
import '../services/mcp_service.dart';
import '../core/utils.dart';

class ServerStatusCard extends StatelessWidget {
  final ServerState state;

  const ServerStatusCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Consumer<McpService>(
      builder: (context, mcpService, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),

                // Bridge Server Status
                _buildServiceRow(
                  context,
                  name: 'Bridge Server',
                  status: state.status,
                  details: state.isRunning
                      ? [
                          'URL: ${state.url ?? "-"}',
                          'Session: ${state.sessionId ?? "-"}',
                          'Uptime: ${state.uptime != null ? AppUtils.formatDuration(state.uptime!) : "-"}',
                        ]
                      : null,
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),

                // MCP Server Status
                _buildMcpStatusRow(context, mcpService),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceRow(
    BuildContext context, {
    required String name,
    required ServerStatus status,
    List<String>? details,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            _buildStatusChip(context, status),
          ],
        ),
        if (details != null) ...[
          const SizedBox(height: 12),
          ...details.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMcpStatusRow(BuildContext context, McpService mcpService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('MCP Server', style: Theme.of(context).textTheme.titleMedium),
        _buildMcpChip(context, mcpService.state.status),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context, ServerStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case ServerStatus.running:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Running';
        break;
      case ServerStatus.starting:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        label = 'Starting';
        break;
      case ServerStatus.stopping:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        label = 'Stopping';
        break;
      case ServerStatus.error:
        color = Colors.red;
        icon = Icons.error;
        label = 'Error';
        break;
      case ServerStatus.stopped:
        color = Colors.grey;
        icon = Icons.stop_circle;
        label = 'Stopped';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMcpChip(BuildContext context, McpStatus status) {
    Color color;
    String label;

    switch (status) {
      case McpStatus.running:
        color = Colors.green;
        label = 'Running';
        break;
      case McpStatus.starting:
        color = Colors.orange;
        label = 'Starting';
        break;
      case McpStatus.stopping:
        color = Colors.orange;
        label = 'Stopping';
        break;
      case McpStatus.error:
        color = Colors.red;
        label = 'Error';
        break;
      case McpStatus.stopped:
        color = Colors.grey;
        label = 'Stopped';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
