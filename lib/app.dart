import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'models/bridge_config.dart';
import 'services/bridge_service.dart';
import 'services/theme_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/system_check_screen.dart';
import 'screens/about_screen.dart';

class FigmaMcpGuiApp extends StatefulWidget {
  final BridgeConfig initialConfig;

  const FigmaMcpGuiApp({super.key, required this.initialConfig});

  @override
  State<FigmaMcpGuiApp> createState() => _FigmaMcpGuiAppState();
}

class _FigmaMcpGuiAppState extends State<FigmaMcpGuiApp> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _handleAutoStart();
  }

  void _handleAutoStart() {
    // Auto-start server if enabled in config
    if (widget.initialConfig.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bridgeService = context.read<BridgeService>();
        if (!bridgeService.state.isRunning) {
          bridgeService.startServer();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Figma Local MCP GUI',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.mode,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Row(
              children: [
                _buildNavigationRail(),
                const VerticalDivider(width: 1),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(
              Icons.extension,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              'MCP',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.check_circle_outline),
          selectedIcon: Icon(Icons.check_circle),
          label: Text('System'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.info_outline),
          selectedIcon: Icon(Icons.info),
          label: Text('About'),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const SettingsScreen();
      case 2:
        return const SystemCheckScreen();
      case 3:
        return const AboutScreen();
      default:
        return const DashboardScreen();
    }
  }
}
