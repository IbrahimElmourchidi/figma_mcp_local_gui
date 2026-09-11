import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import 'runtime_installer.dart';
import 'node_runtime_service.dart';

class SourceBuildService extends ChangeNotifier {
  bool _isBuilding = false;
  double _progress = 0;
  String _status = '';
  String? _error;

  bool get isBuilding => _isBuilding;
  double get progress => _progress;
  String get status => _status;
  String? get error => _error;

  final NodeRuntimeService _nodeRuntimeService;

  SourceBuildService(this._nodeRuntimeService);

  Future<bool> buildFromSource({required String upstreamSha}) async {
    if (_isBuilding) return false;
    if (!_nodeRuntimeService.isReady) {
      _error = 'Node.js not available';
      notifyListeners();
      return false;
    }

    _isBuilding = true;
    _progress = 0;
    _status = 'Preparing build...';
    _error = null;
    notifyListeners();

    final appDir = await AppUtils.getAppDirectory();
    final buildDir = Directory('${appDir.path}/build');
    final nodePath = _nodeRuntimeService.nodePath!;

    try {
      // Clean up any previous build
      if (await buildDir.exists()) {
        await buildDir.delete(recursive: true);
      }
      await buildDir.create(recursive: true);

      // Step 1: Download upstream source
      _status = 'Downloading upstream source...';
      _progress = 0.1;
      notifyListeners();

      final sourceDir = await _downloadUpstreamSource(upstreamSha, buildDir);

      // Step 2: Download pnpm
      _status = 'Setting up pnpm...';
      _progress = 0.2;
      notifyListeners();

      final pnpmPath = await _downloadPnpm(buildDir);

      // Step 3: Install dependencies
      _status = 'Installing dependencies...';
      _progress = 0.3;
      notifyListeners();

      await _installDependencies(nodePath, pnpmPath, sourceDir);

      // Step 4: Build
      _status = 'Building...';
      _progress = 0.5;
      notifyListeners();

      await _buildProject(nodePath, pnpmPath, sourceDir);

      // Step 5: Bundle with esbuild
      _status = 'Bundling...';
      _progress = 0.7;
      notifyListeners();

      final bundleDir = await _bundleWithEsbuild(nodePath, sourceDir, buildDir);

      // Step 6: Copy plugin files
      _status = 'Copying plugin files...';
      _progress = 0.8;
      notifyListeners();

      await _copyPluginFiles(sourceDir, bundleDir);

      // Step 7: Generate manifest
      _status = 'Generating manifest...';
      _progress = 0.9;
      notifyListeners();

      await _generateManifest(upstreamSha, bundleDir);

      // Step 8: Stage and swap
      _status = 'Installing runtime...';
      _progress = 0.95;
      notifyListeners();

      await RuntimeInstaller.stageAndSwap(bundleDir);

      _status = 'Build complete!';
      _progress = 1.0;
      _isBuilding = false;
      notifyListeners();

      debugPrint('Source build completed for $upstreamSha');
      return true;
    } catch (e) {
      _error = 'Build failed: $e';
      _isBuilding = false;
      notifyListeners();
      debugPrint('Source build failed: $e');
      return false;
    } finally {
      // Cleanup build directory
      try {
        if (await buildDir.exists()) {
          await buildDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('Warning: Failed to clean up build dir: $e');
      }
    }
  }

  /// Downloads a .tar.gz from [url] and extracts it into [destDir], via the
  /// shared AppUtils.downloadFile helper. Used for the upstream source
  /// tarball, pnpm, and esbuild - all three plain "download + tar -xzf"
  /// with only the URL, destination, and extra tar flags differing.
  Future<void> _downloadAndExtractTarGz(
    String url,
    Directory destDir, {
    List<String> extraTarArgs = const [],
  }) async {
    await destDir.create(recursive: true);
    final tarPath = '${destDir.path}.tar.gz';

    await AppUtils.downloadFile(url, tarPath);

    try {
      final result = await Process.run('tar', [
        '-xzf',
        tarPath,
        '-C',
        destDir.path,
        ...extraTarArgs,
      ]);
      if (result.exitCode != 0) {
        throw Exception('Failed to extract $url: ${result.stderr}');
      }
    } finally {
      await File(tarPath).delete();
    }
  }

  Future<Directory> _downloadUpstreamSource(
    String sha,
    Directory buildDir,
  ) async {
    final sourceDir = Directory('${buildDir.path}/source');
    final url =
        'https://codeload.github.com/${AppConstants.upstreamOwner}/${AppConstants.upstreamRepo}/tar.gz/$sha';
    await _downloadAndExtractTarGz(
      url,
      sourceDir,
      extraTarArgs: ['--strip-components=1'],
    );
    return sourceDir;
  }

  Future<String> _downloadPnpm(Directory buildDir) async {
    final pnpmDir = Directory('${buildDir.path}/pnpm');
    const url = 'https://registry.npmjs.org/pnpm/-/pnpm-9.15.9.tgz';
    await _downloadAndExtractTarGz(url, pnpmDir);
    return '${pnpmDir.path}/package/dist/pnpm.cjs';
  }

  Future<void> _installDependencies(
    String nodePath,
    String pnpmPath,
    Directory sourceDir,
  ) async {
    final result = await Process.run(
      nodePath,
      [pnpmPath, 'install', '--frozen-lockfile'],
      workingDirectory: sourceDir.path,
    );
    if (result.exitCode != 0) {
      throw Exception('pnpm install failed: ${result.stderr}');
    }
  }

  Future<void> _buildProject(
    String nodePath,
    String pnpmPath,
    Directory sourceDir,
  ) async {
    final result = await Process.run(
      nodePath,
      [pnpmPath, '-r', 'run', 'build'],
      workingDirectory: sourceDir.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Build failed: ${result.stderr}');
    }
  }

  Future<Directory> _bundleWithEsbuild(
    String nodePath,
    Directory sourceDir,
    Directory buildDir,
  ) async {
    // Download esbuild binary. AppConstants.esbuildOsName uses npm's
    // @esbuild/* naming ('win32'), distinct from the Node.js dist naming
    // ('win') used elsewhere.
    final platform = AppConstants.esbuildOsName;
    final arch = await AppConstants.getArch();
    final esbuildUrl =
        'https://registry.npmjs.org/@esbuild/$platform-$arch/-/$platform-$arch-0.28.2.tgz';
    final esbuildDir = Directory('${buildDir.path}/esbuild');
    await _downloadAndExtractTarGz(esbuildUrl, esbuildDir);

    final esbuildBin = '${esbuildDir.path}/package/bin/esbuild';

    // Bundle mcp-server
    final mcpResult = await Process.run(
      esbuildBin,
      [
        '${sourceDir.path}/packages/mcp-server/dist/index.js',
        '--bundle',
        '--platform=node',
        '--format=cjs',
        '--target=node18',
        '--outfile=${buildDir.path}/mcp-server.cjs',
      ],
    );
    if (mcpResult.exitCode != 0) {
      throw Exception('esbuild mcp-server failed: ${mcpResult.stderr}');
    }

    // Bundle bridge-cli
    final cliResult = await Process.run(
      esbuildBin,
      [
        '${sourceDir.path}/packages/cli/dist/bridge-cli.js',
        '--bundle',
        '--platform=node',
        '--format=cjs',
        '--target=node18',
        '--outfile=${buildDir.path}/bridge-cli.cjs',
      ],
    );
    if (cliResult.exitCode != 0) {
      throw Exception('esbuild bridge-cli failed: ${cliResult.stderr}');
    }

    // Copy VERSION
    final shaResult = await Process.run('git', ['-C', sourceDir.path, 'rev-parse', 'HEAD']);
    final sha = shaResult.exitCode == 0 ? shaResult.stdout.toString().trim() : 'unknown';
    await File('${buildDir.path}/VERSION').writeAsString(sha);

    return buildDir;
  }

  Future<void> _copyPluginFiles(Directory sourceDir, Directory bundleDir) async {
    final pluginDir = Directory('${bundleDir.path}/plugin');
    await pluginDir.create();

    // Upstream keeps these at plugins/local-bridge/, not packages/plugin/.
    final pluginFiles = ['code.js', 'ui.html'];
    for (final file in pluginFiles) {
      final source = File('${sourceDir.path}/plugins/local-bridge/$file');
      if (await source.exists()) {
        await source.copy('${pluginDir.path}/$file');
      }
    }

    // Only manifest.template.json is tracked upstream; manifest.json itself
    // is generated per-user/per-port and gitignored there.
    final manifestSource = File(
      '${sourceDir.path}/plugins/local-bridge/manifest.template.json',
    );
    if (await manifestSource.exists()) {
      await manifestSource.copy('${pluginDir.path}/manifest.template.json');
    }
  }

  Future<void> _generateManifest(String upstreamSha, Directory bundleDir) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final manifest = {
      'schema': 1,
      'upstreamRepo': '${AppConstants.upstreamOwner}/${AppConstants.upstreamRepo}',
      'upstreamSha': upstreamSha,
      'builtAt': now,
      'builtBy': 'on-device',
      'esbuildVersion': '0.28.2',
      'nodeTarget': 'node18',
      'files': <String, String>{},
    };

    // Compute checksums
    final filesMap = manifest['files'] as Map<String, String>;
    final files = ['mcp-server.cjs', 'bridge-cli.cjs', 'plugin/code.js', 'plugin/ui.html', 'plugin/manifest.template.json'];
    for (final file in files) {
      final f = File('${bundleDir.path}/$file');
      if (await f.exists()) {
        filesMap[file] = await AppUtils.sha256OfFile(f.path);
      }
    }

    final jsonStr = const JsonEncoder.withIndent('  ').convert(manifest);
    await File('${bundleDir.path}/runtime.json').writeAsString(jsonStr);
  }
}
