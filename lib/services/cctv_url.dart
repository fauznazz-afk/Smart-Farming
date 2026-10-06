import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const allowedCctvHost = 'cctv.mbkm20262027.tech';
const defaultAllowedCctvUrl =
    'https://cctv.mbkm20262027.tech/stream.html?src=cam1';

/// Second stream, on the same go2rtc host, shown on the fish page.
///
/// It is a separate setting rather than a derived value because the allowlist
/// already fixes the host and the only thing that varies is the `src` camera
/// name. Deriving it would mean assuming the second camera is always `cam2`,
/// and a user with a different rig could not point the fish page at their own
/// camera.
const defaultAllowedFishCctvUrl =
    'https://cctv.mbkm20262027.tech/stream.html?src=cam2';

const _cctvStorage = FlutterSecureStorage();
const _cctvUrlKey = 'cctv_url';
const _fishCctvUrlKey = 'cctv_url_fish';

/// The go2rtc player page. The only page this setting is for.
const _allowedCctvPath = '/stream.html';

/// A go2rtc stream name, and nothing else.
///
/// `src` is handed straight to the go2rtc process on the camera host, which
/// dials whatever it is given. It was previously unconstrained, so
/// `?src=rtsp://203.0.113.9/x` and `?src=file:///etc/passwd` both passed this
/// function, got saved to secure storage, and turned the user's own camera box
/// into a relay that dials out of their LAN on request. The host allowlist was
/// written to prevent exactly that and simply did not reach this far.
///
/// A stream *name* is `[A-Za-z0-9_-]`. A URL is not, which is why the pattern
/// rejects rather than sanitises: stripping `:` and `//` out of a URL leaves
/// something that still means something to go2rtc.
final _streamName = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// Validate a saved or typed CCTV URL against the allowlist.
///
/// Four checks, and each one is there because the version above it was missing:
///
/// 1. **https** -- no `http`, so no cleartext, and no `javascript:`/`data:`/
///    scheme reaching the WebView either.
/// 2. **Exact host** -- not a prefix and not a suffix, so neither
///    `x.cctv.mbkm20262027.tech` nor `cctv.mbkm20262027.tech.evil.example`
///    resolves. A trailing dot fails closed, which is safe but will refuse a
///    legitimate FQDN-rooted host.
/// 3. **No userinfo** -- `https://user:pw@cctv.mbkm20262027.tech/` is the right
///    host, but it persists a password into secure storage and replays it on
///    every stream start. `requireAllowedThingsBoardHost` on the Kotlin side
///    rejects this with a comment naming the trick; this one is its mirror and
///    did not have it.
/// 4. **Known page, and a `src` that is a name.** `src` is a stream name, not
///    a URL -- see [_streamName].
///
/// **This is the strict form, for configuration.** It is deliberately *not*
/// what the WebView navigation guard uses; that is [isAllowedCctvNavigation].
/// One function serving two purposes is how the player page breaks: go2rtc
/// navigates internally, and a strict `path == /stream.html` refuses those
/// in-page requests. Found in review on 6 October 2026, after the first attempt
/// at tightening this broke exactly that.
Uri? parseAllowedCctvUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
  if (uri.host.toLowerCase() != allowedCctvHost) return null;
  if (uri.hasPort && uri.port != 443) return null;
  if (uri.userInfo.isNotEmpty) return null;
  if (uri.path != _allowedCctvPath) return null;
  if (uri.fragment.isNotEmpty) return null;
  if (!isAllowedCctvStreamQuery(uri)) return null;
  return uri;
}

/// The `src` rule, shared so the two entry points cannot disagree.
bool isAllowedCctvStreamQuery(Uri uri) {
  // `src` is optional: go2rtc's player page shows a stream picker without one,
  // and there is nothing to abuse in its absence. What is not legitimate is a
  // second parameter, a repeated `src`, or a `src` that is a URL. An extra
  // `&`-separated parameter is how a second `src=` hides behind the first.
  final query = uri.queryParametersAll;
  if (query.keys.any((key) => key != 'src')) return false;
  final src = query['src'];
  if (src != null && src.length != 1) return false;
  if (src != null && !_streamName.hasMatch(src.single)) return false;
  return true;
}

/// The **loose** form, for the WebView navigation guard.
///
/// Same origin, same scheme, no credentials -- and nothing else. A camera page
/// is free to request `/`, a favicon, or whatever its own player needs, and
/// refusing those is refusing the player rather than refusing an attacker.
///
/// This guards one question: "can the camera host navigate somewhere else?"
/// It does not answer "can the camera host ask for things?" -- sub-resources
/// still go anywhere, which is inherent to a WebView and a hardening note
/// rather than a break, because the host is the user's own camera box.
bool isAllowedCctvNavigation(Uri uri) {
  if (uri.scheme.toLowerCase() != 'https') return false;
  if (uri.host.toLowerCase() != allowedCctvHost) return false;
  if (uri.hasPort && uri.port != 443) return false;
  if (uri.userInfo.isNotEmpty) return false;
  return true;
}

/// Load the saved CCTV URL from secure storage.
Future<String> loadCctvUrl() async {
  final saved = await _cctvStorage.read(key: _cctvUrlKey);
  return saved ?? defaultAllowedCctvUrl;
}

/// Load the saved fish-page CCTV URL from secure storage.
Future<String> loadFishCctvUrl() async {
  final saved = await _cctvStorage.read(key: _fishCctvUrlKey);
  return saved ?? defaultAllowedFishCctvUrl;
}

/// Save the CCTV URL to secure storage.
Future<void> saveCctvUrl(String url) async {
  await _cctvStorage.write(key: _cctvUrlKey, value: url);
}

/// Save the fish-page CCTV URL to secure storage.
Future<void> saveFishCctvUrl(String url) async {
  await _cctvStorage.write(key: _fishCctvUrlKey, value: url);
}

/// Clear the saved CCTV URL (e.g., on logout or reset).
Future<void> clearCctvUrl() async {
  await _cctvStorage.delete(key: _cctvUrlKey);
  await _cctvStorage.delete(key: _fishCctvUrlKey);
}
