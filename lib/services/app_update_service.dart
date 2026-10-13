import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_update.dart';

/// Asks GitHub whether a newer release exists, at most once a day.
///
/// ## Why this is a convenience and not a feature the app depends on
///
/// It runs on a phone in a greenhouse, over a connection that may be metered or
/// intermittent, and it talks to a third-party API that rate-limits. Every one of
/// those is a reason for the answer to be optional: [check] returns null for
/// "up to date", for "not due yet", for "the network failed" and for "the API
/// changed shape", and none of those is distinguished from the outside. There is
/// no error state to surface and nothing to retry, because the next attempt is
/// a day away by design.
///
/// ## What it deliberately does not do
///
/// **It does not download or install anything.** The release page is opened in
/// the browser and the user installs from there. An in-app updater means the app
/// can replace itself with bytes it fetched over the network, which is a
/// materially different security posture from opening a page the user can read
/// first, and it is not a decision this convenience should make on its own.
class AppUpdateService {
  const AppUpdateService({this.client});

  /// Injected in tests; the app passes nothing and gets a fresh client per call.
  final http.Client? client;

  static const String _lastCheckKey = 'app_update_last_check';

  /// How long a single check may take.
  ///
  /// **Short, because this runs during startup.** A slow check on a bad
  /// connection would be the app appearing to hang before the dashboard paints.
  static const Duration _timeout = Duration(seconds: 8);

  /// The body cap, and the release JSON is a couple of kilobytes.
  ///
  /// A cap is here because this parses whatever the endpoint returns, and
  /// `response.body` decodes the whole thing before any code of ours runs.
  static const int _maxBytes = 64 * 1024;

  /// The installed version, or null if the platform will not say.
  ///
  /// Null means the app is in a state where it cannot compare, and the caller
  /// gets nothing - the same answer as being up to date.
  Future<String?> currentVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return null;
    }
  }

  /// The newest release when it is newer than the installed one, else null.
  ///
  /// [force] skips the once-a-day gate and is what a "check for updates" button
  /// passes; a button that silently does nothing because a check ran this
  /// morning is indistinguishable from a broken button.
  Future<AppRelease?> check({bool force = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (!force) {
      final raw = preferences.getString(_lastCheckKey);
      final last = raw == null ? null : DateTime.tryParse(raw);
      if (!isDue(last, now)) return null;
    }

    // Written **before** the request, not after. A phone that is about to be put
    // in a drawer should not repeat the request on the next launch just because
    // the connection dropped mid-flight, and the cost of being wrong is one
    // extra day of not hearing about an update.
    await preferences.setString(_lastCheckKey, now.toIso8601String());

    final body = await _fetch();
    if (body == null) return null;

    final release = parseGitHubRelease(body);
    if (release == null) return null;

    final current = await currentVersion();
    if (current == null) return null;
    return isNewerVersion(release.version, current) ? release : null;
  }

  /// The raw body, or null for any failure at all.
  ///
  /// **Nothing here is worth retrying.** Rate limited, offline, 404 from a
  /// repository that has no releases, a 200 carrying an HTML maintenance page:
  /// all of them are one null, and the once-a-day gate is the retry.
  Future<String?> _fetch() async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(
            Uri.parse(kReleaseApiUrl),
            headers: const {
              // GitHub rejects requests without one from some paths, and the
              // answer is a 403 that looks exactly like rate limiting.
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'EnerGrow-Flutter',
            },
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      if (response.bodyBytes.length > _maxBytes) return null;
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      return null;
    } finally {
      // The caller's client is the caller's to close.
      if (client == null) httpClient.close();
    }
  }
}