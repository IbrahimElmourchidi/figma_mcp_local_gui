import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../services/bridge_service.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
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
  String _host = AppConstants.defaultHost;
  bool _autoStart = false;
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
      _autoStart = config.autoStart;
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
      autoStart: _autoStart,
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
                  _buildGeneralSettings(),
                  const SizedBox(height: 24),
                  _buildAppearanceSettings(),
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
}
