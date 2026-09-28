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

Uri? parseAllowedCctvUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
  if (uri.host.toLowerCase() != allowedCctvHost) return null;
  if (uri.hasPort && uri.port != 443) return null;
  return uri;
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