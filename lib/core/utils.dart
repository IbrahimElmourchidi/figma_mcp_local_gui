import 'dart:io';

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
