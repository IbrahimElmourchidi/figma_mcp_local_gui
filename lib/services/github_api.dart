import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Shared "GET some JSON with a timeout" helper for UpdateService and
/// RuntimeUpdateService, which previously each rolled their own
/// http.get + jsonDecode + status-code handling and had drifted (one had no
/// timeout at all).
class GitHubApi {
  static const Duration timeout = Duration(seconds: 10);

  /// GETs [url] and returns the decoded JSON body, or null on a 404 (the
  /// common "nothing published yet" case for a repo with no releases/tags).
  /// Any other non-200 status throws.
  static Future<dynamic> getJson(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    if (response.statusCode == 404) {
      return null;
    }
    throw Exception(
      'GitHub API request failed: ${response.statusCode} for $url',
    );
  }
}
