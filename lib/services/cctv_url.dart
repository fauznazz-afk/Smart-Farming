const allowedCctvHost = 'cctv.mbkm20262027.tech';
const defaultAllowedCctvUrl =
    'https://cctv.mbkm20262027.tech/stream.html?src=cam1';

Uri? parseAllowedCctvUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
  if (uri.host.toLowerCase() != allowedCctvHost) return null;
  if (uri.hasPort && uri.port != 443) return null;
  return uri;
}