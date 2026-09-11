import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

class ConnectionTest extends StatefulWidget {
  final bool isRunning;
  final String host;
  final int port;
  final String? token;

  const ConnectionTest({
    super.key,
    required this.isRunning,
    required this.host,
    required this.port,
    this.token,
  });

  @override
  State<ConnectionTest> createState() => _ConnectionTestState();
}

class _ConnectionTestState extends State<ConnectionTest> {
  bool _isTesting = false;
  bool? _isConnected;
  String? _errorMessage;

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _isConnected = null;
      _errorMessage = null;
    });

    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://${widget.host}:${widget.port}/health'),
      );

      if (widget.token != null && widget.token!.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer ${widget.token}');
      }

      request.headers.set('Host', '${widget.host}:${widget.port}');

      final httpResponse = await request.close().timeout(
        const Duration(seconds: 5),
      );
      await httpResponse.drain();
      client.close();

      setState(() {
        _isConnected = httpResponse.statusCode == 200;
        _isTesting = false;
      });
    } on TimeoutException {
      setState(() {
        _isConnected = false;
        _errorMessage = 'Connection timed out';
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _errorMessage = e.toString();
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plugin Connection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (!widget.isRunning)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Start the server first to test the connection.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.token == null || widget.token!.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.vpn_key,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter or capture a pairing token first.',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (_isTesting)
                const Center(child: CircularProgressIndicator())
              else if (_isConnected == true)
                _buildSuccessMessage(context)
              else if (_isConnected == false)
                _buildErrorMessage(context)
              else
                _buildInitialState(context),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.isRunning && widget.token != null
                      ? _testConnection
                      : null,
                  icon: const Icon(Icons.wifi_find),
                  label: const Text('Test Connection'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.help_outline,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Click "Test Connection" to verify the server is reachable.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Server is reachable. Paste the URL and token into the Figma plugin.',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'Connection failed. Is the server running?',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
