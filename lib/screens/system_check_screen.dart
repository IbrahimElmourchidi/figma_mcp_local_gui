import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/system_checker_service.dart';
import '../services/bridge_service.dart';
import '../widgets/requirement_tile.dart';

class SystemCheckScreen extends StatefulWidget {
  const SystemCheckScreen({super.key});

  @override
  State<SystemCheckScreen> createState() => _SystemCheckScreenState();
}

class _SystemCheckScreenState extends State<SystemCheckScreen> {
  void _runCheck() {
    final port = context.read<BridgeService>().config.port;
    context.read<SystemCheckerService>().checkAll(port: port);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Requirements',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              IconButton(
                onPressed: _runCheck,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Check if your system has all required components installed.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Consumer<SystemCheckerService>(
              builder: (context, service, child) {
                if (service.isChecking) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Checking system requirements...'),
                      ],
                    ),
                  );
                }

                if (service.requirements.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        const Text('No requirements to display'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _runCheck,
                          child: const Text('Run Check'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: service.requirements.length,
                  itemBuilder: (context, index) {
                    final requirement = service.requirements[index];
                    return RequirementTile(requirement: requirement);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
