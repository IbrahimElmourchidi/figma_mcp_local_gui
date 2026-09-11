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

  BridgeConfig({
    int? port,
    String? host,
    String? password,
    this.autoStart = false,
    this.figmaToken,
    this.mcpServerPath,
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
    );
  }
}
