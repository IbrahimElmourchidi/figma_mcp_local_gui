import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:figma_local_mcp_gui/app.dart';
import 'package:figma_local_mcp_gui/models/bridge_config.dart';
import 'package:figma_local_mcp_gui/services/bridge_service.dart';
import 'package:figma_local_mcp_gui/services/system_checker_service.dart';
import 'package:figma_local_mcp_gui/services/update_service.dart';
import 'package:figma_local_mcp_gui/services/plugin_manager.dart';
import 'package:figma_local_mcp_gui/services/mcp_service.dart';
import 'package:figma_local_mcp_gui/services/theme_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BridgeService()),
          ChangeNotifierProvider(create: (_) => SystemCheckerService()),
          ChangeNotifierProvider(create: (_) => UpdateService()),
          ChangeNotifierProvider(create: (_) => PluginManagerService()),
          ChangeNotifierProvider(create: (_) => McpService()),
          ChangeNotifierProvider(create: (_) => ThemeService()),
        ],
        child: FigmaMcpGuiApp(initialConfig: BridgeConfig()),
      ),
    );

    // Verify that the app loads
    expect(find.text('Dashboard'), findsWidgets);
  });
}
