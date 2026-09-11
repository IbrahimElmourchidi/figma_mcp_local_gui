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
import 'services/node_runtime_service.dart';
import 'services/runtime_update_service.dart';
import 'services/source_build_service.dart';
import 'services/bootstrap_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final savedConfig = await storage.loadConfig();

  final nodeRuntimeService = NodeRuntimeService();
  final runtimeUpdateService = RuntimeUpdateService();
  final updateService = UpdateService();

  final bridgeService = BridgeService();
  bridgeService.updateConfig(savedConfig);
  bridgeService.setNodeRuntimeService(nodeRuntimeService);

  final mcpService = McpService();
  mcpService.setNodeRuntimeService(nodeRuntimeService);

  final systemCheckerService = SystemCheckerService();
  systemCheckerService.setNodeRuntimeService(nodeRuntimeService);

  final themeService = ThemeService();
  await themeService.load();

  final bootstrapService = BootstrapService(
    nodeRuntimeService: nodeRuntimeService,
    runtimeUpdateService: runtimeUpdateService,
    updateService: updateService,
  );

  // Run bootstrap in background
  _bootstrap(bootstrapService, savedConfig);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: bridgeService),
        ChangeNotifierProvider.value(value: systemCheckerService),
        ChangeNotifierProvider.value(value: updateService),
        ChangeNotifierProvider(create: (_) => PluginManagerService()),
        ChangeNotifierProvider.value(value: mcpService),
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: nodeRuntimeService),
        ChangeNotifierProvider.value(value: runtimeUpdateService),
        ChangeNotifierProvider(
          create: (_) => SourceBuildService(nodeRuntimeService),
        ),
        ChangeNotifierProvider.value(value: bootstrapService),
      ],
      child: FigmaMcpGuiApp(initialConfig: savedConfig),
    ),
  );
}

Future<void> _bootstrap(
  BootstrapService bootstrapService,
  dynamic config,
) async {
  try {
    await bootstrapService.run(config: config);
  } catch (e) {
    debugPrint('Bootstrap failed: $e');
  }
}
