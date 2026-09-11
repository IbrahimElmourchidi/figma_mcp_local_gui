import '../core/constants.dart';

class BridgeConfig {
  static const String defaultPassword = 'figma-mcp-bridge-token-123456789012';
  static const int minPasswordLength = 32;
  static const int maxPasswordLength = 512;

  final int port;
  final String host;
  final String password;
  final bool autoStart;
  final String? figmaToken;
  final String? mcpServerPath;
  final String? nodePath;
  final String? figmaPluginId;
  final bool autoCheckUpdates;

  BridgeConfig({
    int? port,
    String? host,
    String? password,
    this.autoStart = false,
    this.figmaToken,
    this.mcpServerPath,
    this.nodePath,
    this.figmaPluginId,
    this.autoCheckUpdates = true,
  }) : port = port ?? AppConstants.defaultPort,
       host = host ?? AppConstants.defaultHost,
       password = password ?? defaultPassword;

  String get url => 'http://$host:$port';

  BridgeConfig copyWith({
    int? port,
    String? host,
    String? password,
    bool? autoStart,
    String? figmaToken,
    bool clearFigmaToken = false,
    String? mcpServerPath,
    bool clearMcpServerPath = false,
    String? nodePath,
    bool clearNodePath = false,
    String? figmaPluginId,
    bool clearFigmaPluginId = false,
    bool? autoCheckUpdates,
  }) {
    return BridgeConfig(
      port: port ?? this.port,
      host: host ?? this.host,
      password: password ?? this.password,
      autoStart: autoStart ?? this.autoStart,
      figmaToken: clearFigmaToken ? null : (figmaToken ?? this.figmaToken),
      mcpServerPath: clearMcpServerPath
          ? null
          : (mcpServerPath ?? this.mcpServerPath),
      nodePath: clearNodePath ? null : (nodePath ?? this.nodePath),
      figmaPluginId: clearFigmaPluginId
          ? null
          : (figmaPluginId ?? this.figmaPluginId),
      autoCheckUpdates: autoCheckUpdates ?? this.autoCheckUpdates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'port': port,
      'host': host,
      'password': password,
      'autoStart': autoStart,
      'figmaToken': figmaToken,
      'mcpServerPath': mcpServerPath,
      'nodePath': nodePath,
      'figmaPluginId': figmaPluginId,
      'autoCheckUpdates': autoCheckUpdates,
    };
  }

  factory BridgeConfig.fromJson(Map<String, dynamic> json) {
    return BridgeConfig(
      port: json['port'] ?? AppConstants.defaultPort,
      host: json['host'] ?? AppConstants.defaultHost,
      password: json['password'] ?? defaultPassword,
      autoStart: json['autoStart'] ?? false,
      figmaToken: json['figmaToken'],
      mcpServerPath: json['mcpServerPath'],
      nodePath: json['nodePath'],
      figmaPluginId: json['figmaPluginId'],
      autoCheckUpdates: json['autoCheckUpdates'] ?? true,
    );
  }
}
