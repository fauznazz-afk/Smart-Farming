import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const allowedCctvHost = 'cctv.mbkm20262027.tech';
const defaultAllowedCctvUrl =
    'https://cctv.mbkm20262027.tech/stream.html?src=cam1';
const _cctvStorage = FlutterSecureStorage();
const _cctvUrlKey = 'cctv_url';

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

/// Save the CCTV URL to secure storage.
Future<void> saveCctvUrl(String url) async {
  await _cctvStorage.write(key: _cctvUrlKey, value: url);
}

/// Clear the saved CCTV URL (e.g., on logout or reset).
Future<void> clearCctvUrl() async {
  await _cctvStorage.delete(key: _cctvUrlKey);
}