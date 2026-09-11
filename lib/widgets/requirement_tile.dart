import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/system_requirement.dart';

class RequirementTile extends StatelessWidget {
  final SystemRequirement requirement;

  const RequirementTile({super.key, required this.requirement});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requirement.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        requirement.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (requirement.currentVersion != null)
                  _buildVersionChip(context),
              ],
            ),
            if (requirement.isMissing || requirement.isOutdated) ...[
              const SizedBox(height: 12),
              _buildActionButtons(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    IconData icon;
    Color color;

    switch (requirement.status) {
      case RequirementStatus.met:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case RequirementStatus.missing:
        icon = Icons.error;
        color = Colors.red;
        break;
      case RequirementStatus.outdated:
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case RequirementStatus.checking:
        icon = Icons.hourglass_empty;
        color = Colors.grey;
        break;
      case RequirementStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
    }

    if (requirement.isChecking) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Icon(icon, color: color, size: 28);
  }

  Widget _buildVersionChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        requirement.currentVersion!,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        if (requirement.installUrl != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final url = Uri.parse(requirement.installUrl!);
                await launchUrl(url);
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Install'),
            ),
          ),
        if (requirement.installUrl != null && requirement.guideUrl != null)
          const SizedBox(width: 8),
        if (requirement.guideUrl != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final url = Uri.parse(requirement.guideUrl!);
                await launchUrl(url);
              },
              icon: const Icon(Icons.help_outline, size: 16),
              label: const Text('Guide'),
            ),
          ),
      ],
    );
  }
}
