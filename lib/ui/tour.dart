const tourOrigin = 'https://360.smartrealtors.vn';
Uri? _parse(String value) {
  try {
    final uri = Uri.parse(value);
    if (!uri.hasScheme) return null;
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        (uri.hasAuthority
            ? uri.host.isEmpty
            : uri.path.replaceAll('/', '').isEmpty)) {
      return null;
    }
    return uri;
  } on FormatException {
    return null;
  }
}

bool _isTour(Uri? uri) =>
    uri != null &&
    uri.scheme == 'https' &&
    uri.host == '360.smartrealtors.vn' &&
    uri.port == 443;
String? tourEmbedUrl(String? url) {
  final u = url?.trim();
  return u != null && u.isNotEmpty && _isTour(_parse(u)) ? u : null;
}

String tourNavigation(String url, bool isTopFrame) {
  if (!isTopFrame) return 'allow';
  if (RegExp(
    r'^(about:blank|data:|blob:)',
    caseSensitive: false,
  ).hasMatch(url)) {
    return 'allow';
  }
  final uri = _parse(url);
  if (uri == null) return 'block';
  if (_isTour(uri)) return 'allow';
  return ['http', 'https', 'tel', 'mailto'].contains(uri.scheme)
      ? 'external'
      : 'block';
}
