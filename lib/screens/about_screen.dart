import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../services/runtime_update_service.dart';
import '../services/runtime_installer.dart';
import '../services/node_runtime_service.dart';
import '../core/constants.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = '';
  RuntimeManifest? _runtimeManifest;
  String? _nodeVersion;

  @override
  void initState() {
    super.initState();
    _loadInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UpdateService>().checkForUpdates();
      context.read<RuntimeUpdateService>().checkForRuntimeUpdate();
    });
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _appVersion = info.version);
    } catch (_) {
      setState(() => _appVersion = 'unknown');
    }

    try {
      final manifest = await RuntimeInstaller.getInstalledManifest();
      setState(() => _runtimeManifest = manifest);
    } catch (_) {}

    try {
      final nodeService = context.read<NodeRuntimeService>();
      _nodeVersion = nodeService.currentVersion;
    } catch (_) {}
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
                            'Version $_appVersion',
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
          _buildRuntimeInfoCard(),
          const SizedBox(height: 16),
          _buildUpdateSection(),
          const SizedBox(height: 16),
          _buildLinksSection(),
        ],
      ),
    );
  }

  Widget _buildRuntimeInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Runtime Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Upstream SHA',
              _shortSha(_runtimeManifest?.upstreamSha),
            ),
            if (_nodeVersion != null)
              _buildInfoRow('Node.js', _nodeVersion!),
            if (_runtimeManifest?.builtAt != null)
              _buildInfoRow('Built at', _runtimeManifest!.builtAt!),
          ],
        ),
      ),
    );
  }

  String _shortSha(String? sha) {
    if (sha == null || sha.isEmpty) return 'unknown';
    return sha.length > 12 ? sha.substring(0, 12) : sha;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
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
                else if (updateService.noReleasesYet)
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('No releases available yet.'),
                      ),
                    ],
                  )
                else if (updateService.hasUpdate)
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
                // Manual check button always visible when enabled
                if (updateService.isUpdateEnabled) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => updateService.checkForUpdates(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Check for updates'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinksSection() {
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
