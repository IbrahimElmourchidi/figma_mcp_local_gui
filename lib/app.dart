import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'models/bridge_config.dart';
import 'services/bridge_service.dart';
import 'services/theme_service.dart';
import 'services/bootstrap_service.dart';
import 'services/update_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/system_check_screen.dart';
import 'screens/about_screen.dart';
import 'screens/bootstrap_screen.dart';
import 'widgets/update_banner.dart';

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
    _initServices();
    _handleAutoStart();
  }

  Future<void> _initServices() async {
    // Initialize update service to get current version
    final updateService = context.read<UpdateService>();
    await updateService.init();
  }

  void _handleAutoStart() {
    if (!widget.initialConfig.autoStart) return;

    // Wait for bootstrap (Node provisioning + runtime install) to finish
    // before starting the server - otherwise NodeRuntimeService may not be
    // ready yet and startServer() silently falls back to a bare 'node' on
    // PATH, which is exactly what managed provisioning exists to avoid.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bootstrapService = context.read<BootstrapService>();

      void tryStart() {
        if (!mounted) return;
        final bridgeService = context.read<BridgeService>();
        if (!bridgeService.state.isRunning) {
          bridgeService.startServer();
        }
      }

      if (!bootstrapService.isRunning) {
        tryStart();
        return;
      }

      late VoidCallback listener;
      listener = () {
        if (!bootstrapService.isRunning) {
          bootstrapService.removeListener(listener);
          tryStart();
        }
      };
      bootstrapService.addListener(listener);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeService, BootstrapService>(
      builder: (context, themeService, bootstrapService, child) {
        return MaterialApp(
          title: 'Figma Local MCP GUI',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.mode,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Stack(
              children: [
                // Main content
                if (bootstrapService.isRunning)
                  const BootstrapScreen()
                else
                  _buildMainContent(),
                // Update banner overlay
                if (!bootstrapService.isRunning)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: UpdateBanner(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        const SizedBox(height: 40), // Space for update banner
        Expanded(
          child: Row(
            children: [
              _buildNavigationRail(),
              const VerticalDivider(width: 1),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ],
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
