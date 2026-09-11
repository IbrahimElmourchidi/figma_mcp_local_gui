import 'dart:io' as io;

import 'package:pub_semver/pub_semver.dart';

class AppUpdateAsset {
  final String name;
  final int size;
  final String downloadUrl;
  final String? contentType;
  final int? downloadCount;

  AppUpdateAsset({
    required this.name,
    required this.size,
    required this.downloadUrl,
    this.contentType,
    this.downloadCount,
  });

  factory AppUpdateAsset.fromJson(Map<String, dynamic> json) {
    return AppUpdateAsset(
      name: json['name'] ?? '',
      size: json['size'] ?? 0,
      downloadUrl: json['browser_download_url'] ?? '',
      contentType: json['content_type'],
      downloadCount: json['download_count'],
    );
  }
}

class AppUpdate {
  final String version;
  final String? releaseNotes;
  final DateTime publishedAt;
  final String downloadUrl;
  final String changelogUrl;
  final List<AppUpdateAsset> assets;

  AppUpdate({
    required this.version,
    this.releaseNotes,
    required this.publishedAt,
    required this.downloadUrl,
    required this.changelogUrl,
    this.assets = const [],
  });

  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    final assetsList = <AppUpdateAsset>[];
    if (json['assets'] is List) {
      for (final asset in json['assets']) {
        assetsList.add(AppUpdateAsset.fromJson(asset));
      }
    }

    return AppUpdate(
      version: json['tag_name'] ?? '',
      releaseNotes: json['body'],
      publishedAt: DateTime.parse(
        json['published_at'] ?? DateTime.now().toIso8601String(),
      ),
      downloadUrl: json['html_url'] ?? '',
      changelogUrl: json['html_url'] ?? '',
      assets: assetsList,
    );
  }

  bool isNewerThan(String currentVersion) {
    try {
      final current = Version.parse(_cleanVersion(currentVersion));
      final latest = Version.parse(_cleanVersion(version));
      return latest > current;
    } catch (e) {
      return version.compareTo(currentVersion) > 0;
    }
  }

  String _cleanVersion(String version) {
    return version.replaceFirst(RegExp(r'^v'), '').split('+').first;
  }

  AppUpdateAsset? getPlatformAsset() {
    final platform = _getPlatform();
    for (final asset in assets) {
      if (asset.name.toLowerCase().contains(platform)) {
        return asset;
      }
    }
    return null;
  }

  String _getPlatform() {
    if (io.Platform.isLinux) return 'linux';
    if (io.Platform.isMacOS) return 'macos';
    if (io.Platform.isWindows) return 'windows';
    return '';
  }
}
