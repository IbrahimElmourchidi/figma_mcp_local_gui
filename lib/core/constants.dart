import 'dart:io';

class AppConstants {
  static const String appName = 'Figma Local MCP GUI';

  // Server defaults - port 3845 matches Figma plugin's devAllowedDomains
  static const int defaultPort = 3845;
  static const String defaultHost = '127.0.0.1';
  static const String defaultUrl = 'http://127.0.0.1:3845';

  // GitHub repo for app updates
  static const String githubOwner = 'IbrahimElmourchidi';
  static const String githubRepo = 'figma_mcp_local_gui';

  // Upstream repo for runtime updates
  static const String upstreamOwner = 'superdoccimo';
  static const String upstreamRepo = 'figma-mcp-free';
  static const String runtimeReleaseTag = 'runtime-latest';

  // Node.js provisioning
  static const String pinnedNodeVersion = 'v24.21.0';
  static const int minNodeVersion = 18;
  static const String recommendedNodeVersion = '20 LTS';

  static String get nodeDistBase => 'https://nodejs.org/dist/$pinnedNodeVersion';

  // Arch never changes during the process lifetime, so cache it instead of
  // re-spawning `uname -m` on every call site that needs it.
  static String? _archCache;

  static Future<String> getArch() async {
    if (_archCache != null) return _archCache!;

    if (Platform.isWindows) {
      _archCache = Platform.environment['PROCESSOR_ARCHITECTURE'] == 'ARM64'
          ? 'arm64'
          : 'x64';
      return _archCache!;
    }
    try {
      final result = await Process.run('uname', ['-m']);
      if (result.exitCode == 0) {
        final arch = result.stdout.toString().trim();
        _archCache = (arch == 'aarch64' || arch == 'arm64') ? 'arm64' : 'x64';
        return _archCache!;
      }
    } catch (_) {}
    _archCache = 'x64';
    return _archCache!;
  }

  static String get nodeExecutableName =>
      Platform.isWindows ? 'node.exe' : 'node';

  static Future<String> nodeArchiveNameFor(String arch) async {
    if (Platform.isLinux) return 'node-$pinnedNodeVersion-linux-$arch.tar.xz';
    if (Platform.isMacOS) return 'node-$pinnedNodeVersion-darwin-$arch.tar.xz';
    if (Platform.isWindows) return 'node-$pinnedNodeVersion-win-$arch.zip';
    throw UnsupportedError('Unsupported platform');
  }

  /// OS slug as used by npm's @esbuild/<os>-<arch> platform packages, which
  /// use 'win32' where Node.js dist naming (above) uses 'win'.
  static String get esbuildOsName {
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isWindows) return 'win32';
    throw UnsupportedError('Unsupported platform');
  }
}
