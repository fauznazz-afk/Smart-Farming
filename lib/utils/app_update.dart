import 'dart:convert';

import 'package:flutter/foundation.dart';

/// "A newer build exists on GitHub, and here is where it is."
///
/// **A value type rather than a set of out-parameters, because the caller has
/// to make two decisions from it** - is this worth telling the user, and what do
/// we open - and the pair is meaningless apart.
@immutable
class AppRelease {
  const AppRelease({
    required this.tag,
    required this.version,
    required this.url,
    this.notes,
  });

  /// The tag as GitHub reports it, `v1.13.0`.
  final String tag;

  /// The tag with the leading `v` removed, `1.13.0`.
  final String version;

  /// The release's own page. **Never assembled from the tag**, because the
  /// download is an asset upload whose URL is not derivable from a version.
  final String url;

  /// The release body, markdown, or null.
  final String? notes;

  @override
  bool operator ==(Object other) =>
      other is AppRelease && other.tag == tag && other.url == url;

  @override
  int get hashCode => Object.hash(tag, url);
}

/// The GitHub repository this app is released from.
///
/// **A constant rather than a setting, for the same reason the ThingsBoard base
/// URL is one.** A user cannot point the updater at their own mirror, and the
/// request carries no credential, so the host is fixed and there is nothing to
/// leak. What a settings field would add is a way to be wrong.
const String kReleaseApiUrl =
    'https://api.github.com/repos/fauznazz-afk/Smart-Farming/releases/latest';

/// How often the updater is allowed to ask.
///
/// **A day, and the reason is the client's data.** This runs on a phone that is
/// on a metered connection in a greenhouse; a check per launch is a request per
/// launch forever, for a number that changes a few times a year. Once a day is
/// well inside "you find out about an update the same day it ships".
const Duration kUpdateCheckInterval = Duration(hours: 24);

/// Parses GitHub's `/releases/latest` body, or null for anything unexpected.
///
/// **Returns null rather than throwing, and that is the whole contract.** This
/// runs during startup against a third-party API that can rate-limit, return a
/// maintenance page, or one day change its shape. A parse failure must leave the
/// app exactly as it was, because the alternative is an app that cannot be
/// launched because an optional convenience could not be understood.
AppRelease? parseGitHubRelease(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final tag = decoded['tag_name'];
    final url = decoded['html_url'];
    if (tag is! String || tag.isEmpty) return null;
    if (url is! String || !url.startsWith('https://')) return null;
    final notes = decoded['body'];
    return AppRelease(
      tag: tag,
      version: normalizeVersion(tag),
      url: url,
      notes: notes is String && notes.trim().isNotEmpty ? notes.trim() : null,
    );
  } on FormatException {
    return null;
  }
}

/// Strips a release tag down to the version.
///
/// **`v` and anything before it goes, and so does a leading `=`.** Tags are
/// written by hand at release time and the three forms that have shipped in this
/// repo are `v1.13.0`, `1.13.0` and `release-1.13.0`. Only the first two are
/// expected; the third is why this is a prefix scan and not a single `if`.
String normalizeVersion(String tag) {
  var v = tag.trim();
  if (v.startsWith('release-')) v = v.substring('release-'.length);
  if (v.startsWith('=')) v = v.substring(1);
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
  return v;
}

/// Whether [candidate] is strictly newer than [current].
///
/// **Segment by segment, numerically, and a missing segment is zero** - so
/// `1.14` beats `1.13.0` and `1.13` does not. Comparing the strings would say
/// `1.9.0` is newer than `1.13.0`, which is the bug this exists to avoid, and it
/// is not hypothetical: this app shipped `1.13.0`.
///
/// Returns false for anything unparseable, which means an unrecognised version
/// never nags the user. A false negative is a person missing an update; a false
/// positive is a person told to reinstall an app they already have.
bool isNewerVersion(String candidate, String current) {
  final a = _segments(candidate);
  final b = _segments(current);
  if (a == null || b == null) return false;
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final left = i < a.length ? a[i] : 0;
    final right = i < b.length ? b[i] : 0;
    if (left != right) return left > right;
  }
  return false;
}

/// The numeric segments of a version, or null if any of them is not a number.
///
/// **The build number after `+` is dropped**, and this is deliberate: the tag
/// `v1.13.0` names a release and the `+25` on the installed build is a local
/// counter that never appears in a tag. Comparing them would make every build
/// of a released version look different from the release.
List<int>? _segments(String version) {
  final core = version.split('+').first.split('-').first;
  if (core.isEmpty) return null;
  final parts = <int>[];
  for (final part in core.split('.')) {
    if (part.isEmpty) return null;
    final n = int.tryParse(part);
    if (n == null || n < 0) return null;
    parts.add(n);
  }
  return parts;
}

/// Whether the last check is old enough to run again.
///
/// **Null means never checked, and that counts as due.** An app that has never
/// looked must not wait a day before its first look.
bool isDue(DateTime? lastChecked, DateTime now) {
  if (lastChecked == null) return true;
  return now.difference(lastChecked) >= kUpdateCheckInterval;
}