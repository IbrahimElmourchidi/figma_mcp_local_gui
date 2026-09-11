class AppUpdate {
  final String version;
  final String? releaseNotes;
  final DateTime publishedAt;
  final String downloadUrl;
  final String changelogUrl;

  AppUpdate({
    required this.version,
    this.releaseNotes,
    required this.publishedAt,
    required this.downloadUrl,
    required this.changelogUrl,
  });

  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    return AppUpdate(
      version: json['tag_name'] ?? '',
      releaseNotes: json['body'],
      publishedAt: DateTime.parse(
        json['published_at'] ?? DateTime.now().toIso8601String(),
      ),
      downloadUrl: json['html_url'] ?? '',
      changelogUrl: json['html_url'] ?? '',
    );
  }

  bool isNewerThan(String currentVersion) {
    final current = _parseVersion(currentVersion);
    final latest = _parseVersion(version);

    for (var i = 0; i < latest.length; i++) {
      if (i >= current.length) return true;
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return false;
  }

  List<int> _parseVersion(String version) {
    return version
        .replaceAll('v', '')
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
  }
}
