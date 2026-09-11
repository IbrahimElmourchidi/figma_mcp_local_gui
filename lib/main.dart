import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/bridge_service.dart';
import 'services/system_checker_service.dart';
import 'services/update_service.dart';
import 'services/plugin_manager.dart';
import 'services/mcp_service.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load config before creating providers so BridgeService starts with persisted settings
  final storage = StorageService();
  final savedConfig = await storage.loadConfig();

  final bridgeService = BridgeService();
  bridgeService.updateConfig(savedConfig);

  final themeService = ThemeService();
  await themeService.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: bridgeService),
        ChangeNotifierProvider(create: (_) => SystemCheckerService()),
        ChangeNotifierProvider(create: (_) => UpdateService()),
        ChangeNotifierProvider(create: (_) => PluginManagerService()),
        ChangeNotifierProvider(create: (_) => McpService()),
        ChangeNotifierProvider.value(value: themeService),
      ],
      child: FigmaMcpGuiApp(initialConfig: savedConfig),
    ),
  );
}
