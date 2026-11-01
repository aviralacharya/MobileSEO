/// Rejects malformed persisted URLs before they can reach navigation or reports.
Uri parsePageUrl(String url) {
  final value = url.trim();
  final uri = Uri.parse(value);
  if ((uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      RegExp(r'\s').hasMatch(value) ||
      uri.port < 1 ||
      uri.port > 65535) {
    throw const FormatException('Expected an absolute HTTP(S) page URL.');
  }
  return uri;
}

/// Fragments identify positions within one document. Schemes, paths, ports
/// and queries remain significant so different pages never share a score trend.
String pageIdentity(String url) {
  final uri = parsePageUrl(url);
  return uri
      .replace(path: uri.path.isEmpty ? '/' : uri.path)
      .removeFragment()
      .toString();
}

bool samePage(String a, String b) => pageIdentity(a) == pageIdentity(b);

String formatAuditDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
