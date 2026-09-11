import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUtils {
  static Future<Directory> getAppDirectory() async {
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      return Directory('$home/.local/share/figma_local_mcp_gui');
    } else if (Platform.isMacOS) {
      final appSupport = await getApplicationSupportDirectory();
      return appSupport;
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      return Directory('$appData\\figma_local_mcp_gui');
    }
    return getApplicationDocumentsDirectory();
  }

  static Future<Directory> getBridgeDirectory() async {
    final appDir = await getAppDirectory();
    final bridgeDir = Directory('${appDir.path}/bridge');
    if (!await bridgeDir.exists()) {
      await bridgeDir.create(recursive: true);
    }
    return bridgeDir;
  }

  static Future<Directory> getPluginsDirectory() async {
    final appDir = await getAppDirectory();
    final pluginsDir = Directory('${appDir.path}/plugins');
    if (!await pluginsDir.exists()) {
      await pluginsDir.create(recursive: true);
    }
    return pluginsDir;
  }

  static Future<SharedPreferences> getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  /// Streams [url] to [savePath], optionally reporting 0.0-1.0 progress.
  /// Shared by NodeRuntimeService, RuntimeUpdateService, and
  /// SourceBuildService so download error handling and disk-flush ordering
  /// only need to be right in one place.
  static Future<void> downloadFile(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Download failed with status ${response.statusCode} for $url',
        );
      }

      final contentLength = response.contentLength ?? 0;
      final sink = File(savePath).openWrite();
      var received = 0;

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (contentLength > 0) {
            onProgress?.call(received / contentLength);
          }
        }
      } finally {
        // Must be awaited: otherwise the file's write buffer may not be
        // flushed before the caller reads it back (e.g. for checksum
        // verification), risking a spurious mismatch against a truncated
        // file.
        await sink.close();
      }

      onProgress?.call(1.0);
    } finally {
      client.close();
    }
  }

  /// SHA-256 hex digest of a file's contents.
  static Future<String> sha256OfFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return sha256OfBytes(bytes);
  }

  /// SHA-256 hex digest of raw bytes.
  static String sha256OfBytes(List<int> bytes) => sha256.convert(bytes).toString();

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
