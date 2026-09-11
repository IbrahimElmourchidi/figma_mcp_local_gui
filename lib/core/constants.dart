class AppConstants {
  static const String appName = 'Figma Local MCP GUI';
  // Keep in sync with pubspec.yaml's `version:` (the part before the `+build`).
  static const String appVersion = '1.0.0';

  // Server defaults - port 3845 matches Figma plugin's devAllowedDomains
  static const int defaultPort = 3845;
  static const String defaultHost = '127.0.0.1';
  static const String defaultUrl = 'http://127.0.0.1:3845';

  // GitHub repo for updates - leave empty to disable update checks
  static const String githubOwner = '';
  static const String githubRepo = '';

  // Figma plugin paths
  static const List<String> figmaPluginPaths = [
    '~/.config/figma/Development/',
    '~/Library/Application Support/Figma/Development/',
    '%APPDATA%/Figma/Development/',
  ];

  // Node.js requirements
  static const int minNodeVersion = 18;
  static const String recommendedNodeVersion = '20 LTS';
}
