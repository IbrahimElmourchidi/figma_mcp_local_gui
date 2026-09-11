import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:figma_local_mcp_gui/app.dart';
import 'package:figma_local_mcp_gui/models/bridge_config.dart';
import 'package:figma_local_mcp_gui/services/bootstrap_service.dart';
import 'package:figma_local_mcp_gui/services/bridge_service.dart';
import 'package:figma_local_mcp_gui/services/node_runtime_service.dart';
import 'package:figma_local_mcp_gui/services/runtime_update_service.dart';
import 'package:figma_local_mcp_gui/services/system_checker_service.dart';
import 'package:figma_local_mcp_gui/services/update_service.dart';
import 'package:figma_local_mcp_gui/services/plugin_manager.dart';
import 'package:figma_local_mcp_gui/services/mcp_service.dart';
import 'package:figma_local_mcp_gui/services/theme_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final nodeRuntimeService = NodeRuntimeService();
    final runtimeUpdateService = RuntimeUpdateService();
    final updateService = UpdateService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BridgeService()),
          ChangeNotifierProvider(create: (_) => SystemCheckerService()),
          ChangeNotifierProvider.value(value: updateService),
          ChangeNotifierProvider(create: (_) => PluginManagerService()),
          ChangeNotifierProvider(create: (_) => McpService()),
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider.value(value: nodeRuntimeService),
          ChangeNotifierProvider.value(value: runtimeUpdateService),
          ChangeNotifierProvider(
            create: (_) => BootstrapService(
              nodeRuntimeService: nodeRuntimeService,
              runtimeUpdateService: runtimeUpdateService,
              updateService: updateService,
            ),
          ),
        ],
        child: FigmaMcpGuiApp(initialConfig: BridgeConfig()),
      ),
    );

    // BootstrapService.run() is only invoked from main(), not by this test,
    // so `isRunning` stays false and the dashboard renders directly.
    expect(find.text('Dashboard'), findsWidgets);
  });
}
