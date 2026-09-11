import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../core/constants.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UpdateService>().checkForUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.extension,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Version ${AppConstants.appVersion}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'A GUI manager for Figma MCP Local Bridge Server. '
                    'Provides easy server control, system requirements checking, '
                    'and automatic updates.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildUpdateSection(),
          const SizedBox(height: 16),
          _buildLinksSection(),
        ],
      ),
    );
  }

  Widget _buildUpdateSection() {
    return Consumer<UpdateService>(
      builder: (context, updateService, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Updates', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                if (!updateService.isUpdateEnabled)
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Update checking is not configured for this build.',
                        ),
                      ),
                    ],
                  )
                else if (updateService.isChecking)
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Checking for updates...'),
                    ],
                  )
                else if (updateService.hasUpdate())
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.system_update,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Update available: ${updateService.latestUpdate!.version}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                if (updateService.latestUpdate!.releaseNotes !=
                                    null)
                                  Text(
                                    updateService.latestUpdate!.releaseNotes!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final url = Uri.parse(
                                updateService.latestUpdate!.downloadUrl,
                              );
                              await launchUrl(url);
                            },
                            child: const Text('Open Release Page'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => updateService.checkForUpdates(),
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Text('You are running the latest version'),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinksSection() {
    // No repo is configured (AppConstants.githubOwner/githubRepo are
    // deliberately empty until this project has a real one), so building
    // GitHub URLs from them would produce dead links like
    // "https://github.com//" - show nothing instead of a broken card.
    if (AppConstants.githubOwner.isEmpty || AppConstants.githubRepo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Links', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildLinkTile(
              icon: Icons.code,
              title: 'Source Code',
              subtitle: 'GitHub Repository',
              url:
                  'https://github.com/${AppConstants.githubOwner}/${AppConstants.githubRepo}',
            ),
            _buildLinkTile(
              icon: Icons.bug_report,
              title: 'Report Issue',
              subtitle: 'Found a bug? Let us know!',
              url:
                  'https://github.com/${AppConstants.githubOwner}/${AppConstants.githubRepo}/issues',
            ),
            _buildLinkTile(
              icon: Icons.description,
              title: 'Documentation',
              subtitle: 'Learn how to use the app',
              url:
                  'https://github.com/${AppConstants.githubOwner}/${AppConstants.githubRepo}#readme',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new),
      onTap: () async {
        final uri = Uri.parse(url);
        await launchUrl(uri);
      },
    );
  }
}
