import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../services/bridge_service.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../services/runtime_installer.dart';
import '../services/runtime_update_service.dart';
import '../services/source_build_service.dart';
import '../models/bridge_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _portController = TextEditingController();
  final _passwordController = TextEditingController();
  final _figmaTokenController = TextEditingController();
  final _mcpPathController = TextEditingController();
  final _nodePathController = TextEditingController();
  final _figmaPluginIdController = TextEditingController();
  String _host = AppConstants.defaultHost;
  bool _autoStart = false;
  bool _autoCheckUpdates = true;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = StorageService();
    final config = await storage.loadConfig();

    setState(() {
      _portController.text = config.port.toString();
      _host = BridgeService.validHosts.contains(config.host)
          ? config.host
          : AppConstants.defaultHost;
      _passwordController.text = config.password;
      _figmaTokenController.text = config.figmaToken ?? '';
      _mcpPathController.text = config.mcpServerPath ?? '';
      _nodePathController.text = config.nodePath ?? '';
      _figmaPluginIdController.text = config.figmaPluginId ?? '';
      _autoStart = config.autoStart;
      _autoCheckUpdates = config.autoCheckUpdates;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final config = BridgeConfig(
      port: int.tryParse(_portController.text) ?? AppConstants.defaultPort,
      host: _host,
      password: _passwordController.text.isNotEmpty
          ? _passwordController.text
          : BridgeConfig.defaultPassword,
      figmaToken: _figmaTokenController.text.isNotEmpty
          ? _figmaTokenController.text
          : null,
      mcpServerPath: _mcpPathController.text.isNotEmpty
          ? _mcpPathController.text
          : null,
      nodePath: _nodePathController.text.isNotEmpty
          ? _nodePathController.text
          : null,
      figmaPluginId: _figmaPluginIdController.text.isNotEmpty
          ? _figmaPluginIdController.text
          : null,
      autoStart: _autoStart,
      autoCheckUpdates: _autoCheckUpdates,
    );

    final storage = StorageService();
    await storage.saveConfig(config);

    if (mounted) {
      context.read<BridgeService>().updateConfig(config);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  void dispose() {
    _portController.dispose();
    _passwordController.dispose();
    _figmaTokenController.dispose();
    _mcpPathController.dispose();
    _nodePathController.dispose();
    _figmaPluginIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _buildServerSettings(),
                  const SizedBox(height: 24),
                  _buildPasswordSettings(),
                  const SizedBox(height: 24),
                  _buildMcpSettings(),
                  const SizedBox(height: 24),
                  _buildNodeSettings(),
                  const SizedBox(height: 24),
                  _buildPluginSettings(),
                  const SizedBox(height: 24),
                  _buildGeneralSettings(),
                  const SizedBox(height: 24),
                  _buildAppearanceSettings(),
                  const SizedBox(height: 24),
                  _buildRuntimeSettings(),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      child: const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '${AppConstants.defaultPort}',
                helperText: 'Must match the Figma plugin manifest\'s devAllowedDomains port',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Port is required';
                }
                final port = int.tryParse(value);
                if (port == null || port < 1 || port > 65535) {
                  return 'Invalid port number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _host,
              decoration: const InputDecoration(
                labelText: 'Host',
                helperText: 'The bridge server only accepts these loopback bind addresses',
              ),
              items: BridgeService.validHosts
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _host = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pairing Password',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This password is used to authenticate the Figma plugin with the bridge server. '
              'Use the same password in the Figma plugin settings.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Min 32 characters',
                helperText: 'Default: ${BridgeConfig.defaultPassword}',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.length < BridgeConfig.minPasswordLength) {
                  return 'Password must be at least ${BridgeConfig.minPasswordLength} characters';
                }
                if (value.length > BridgeConfig.maxPasswordLength) {
                  return 'Password must be at most ${BridgeConfig.maxPasswordLength} characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMcpSettings() {
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
                  'MCP Server (for opencode)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Configure the MCP server to connect to opencode CLI. '
              'The Figma token is optional and only needed for REST API tools.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _figmaTokenController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Figma Token (optional)',
                hintText: 'figd_...',
                helperText: 'For REST API tools (get_file, get_nodes, etc.)',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mcpPathController,
              decoration: const InputDecoration(
                labelText: 'MCP Server Path (optional)',
                hintText: '/path/to/mcp-server.cjs',
                helperText: 'Auto-detected (installed alongside the app) if not specified',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Node.js',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The app manages its own Node.js runtime by default. '
              'Override with a custom path if needed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nodePathController,
              decoration: const InputDecoration(
                labelText: 'Node.js Path (optional)',
                hintText: '/usr/local/bin/node',
                helperText: 'Auto-detected if not specified',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPluginSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.extension, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Figma Plugin',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your Figma development plugin ID. You get this when creating '
              'a development plugin in Figma.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _figmaPluginIdController,
              decoration: const InputDecoration(
                labelText: 'Figma Plugin ID',
                hintText: '1679462793087496067',
                helperText: 'From Figma plugin development settings',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('General', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto-start server'),
              subtitle: const Text('Start server when app launches'),
              value: _autoStart,
              onChanged: (value) => setState(() => _autoStart = value),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Auto-check for updates'),
              subtitle: const Text('Check for updates on app launch'),
              value: _autoCheckUpdates,
              onChanged: (value) => setState(() => _autoCheckUpdates = value),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSettings() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ThemeMode>(
                  initialValue: themeService.mode,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) themeService.setMode(value);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRuntimeSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Runtime',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FutureBuilder<bool>(
              future: RuntimeInstaller.hasRollbackAvailable(),
              builder: (context, snapshot) {
                final hasRollback = snapshot.data ?? false;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await RuntimeInstaller.forceReinstall();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Runtime reinstalled'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Force Reinstall'),
                    ),
                    if (hasRollback)
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await RuntimeInstaller.rollback();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Runtime rolled back'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.undo),
                        label: const Text('Rollback'),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Advanced: build from source',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'For a SHA the runtime-sync CI has not published a prebuilt '
              'bundle for yet. Downloads the upstream source and pnpm/esbuild '
              'as plain packages and builds locally using the managed Node.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Consumer2<RuntimeUpdateService, SourceBuildService>(
              builder: (context, runtimeUpdateService, sourceBuildService, child) {
                final sha = runtimeUpdateService.latestUpstreamSha;
                return Row(
                  children: [
                    Expanded(
                      child: sourceBuildService.isBuilding
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(value: sourceBuildService.progress),
                                const SizedBox(height: 4),
                                Text(
                                  sourceBuildService.status,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            )
                          : Text(
                              sha == null
                                  ? 'Upstream SHA unknown - open About to check first.'
                                  : 'Latest upstream: ${sha.substring(0, sha.length > 12 ? 12 : sha.length)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: sourceBuildService.isBuilding || sha == null
                          ? null
                          : () => _buildFromSource(sourceBuildService, sha),
                      icon: const Icon(Icons.build),
                      label: const Text('Build from source'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buildFromSource(
    SourceBuildService sourceBuildService,
    String upstreamSha,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Build runtime from source?'),
        content: Text(
          'This downloads figma-mcp-free @ ${upstreamSha.substring(0, 12)} and '
          'builds it on this machine. It can take a few minutes and requires '
          'network access to GitHub and the npm registry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Build'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await sourceBuildService.buildFromSource(upstreamSha: upstreamSha);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Runtime built and installed successfully'
              : 'Build failed: ${sourceBuildService.error ?? "unknown error"}',
        ),
        backgroundColor: success ? null : Colors.red,
      ),
    );
  }
}
