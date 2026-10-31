import 'package:html/dom.dart' as dom;

class LinkAudit {
  const LinkAudit({
    required this.total,
    required this.internal,
    required this.external,
    required this.emptyHrefs,
    required this.nofollow,
    this.externalHosts = const [],
    this.urls = const [],
  });
  const LinkAudit.empty()
    : total = 0,
      internal = 0,
      external = 0,
      emptyHrefs = 0,
      nofollow = 0,
      externalHosts = const [],
      urls = const [];
  final int total, internal, external, emptyHrefs, nofollow;
  final List<String> externalHosts;

  /// Absolute HTTP(S) links in document order, used by the optional link scan.
  final List<String> urls;
  bool get hasLinks => total > 0;
  bool get hasEmptyHrefs => emptyHrefs > 0;
  String get summary =>
      '$total links · $internal internal · $external external';
}

LinkAudit checkLinks(dom.Document document, Uri pageUrl) {
  final hosts = <String>{};
  final urls = <String>[];
  var internal = 0, external = 0, empty = 0, nofollow = 0;
  for (final anchor in document.querySelectorAll('a[href]')) {
    final href = (anchor.attributes['href'] ?? '').trim();
    if (href.isEmpty ||
        href.startsWith('#') ||
        href.toLowerCase().startsWith('javascript:')) {
      empty++;
      continue;
    }
    if ((anchor.attributes['rel'] ?? '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .contains('nofollow'))
      nofollow++;
    final parsed = Uri.tryParse(href);
    if (parsed == null) {
      empty++;
      continue;
    }
    final target = parsed.hasScheme ? parsed : pageUrl.resolveUri(parsed);
    if ((target.scheme != 'http' && target.scheme != 'https') ||
        target.host.isEmpty) {
      empty++;
      continue;
    }
    urls.add(target.toString());
    if (target.host.toLowerCase() == pageUrl.host.toLowerCase()) {
      internal++;
    } else {
      external++;
      hosts.add(target.host.toLowerCase());
    }
  }
  final sorted = hosts.toList()..sort();
  return LinkAudit(
    total: internal + external,
    internal: internal,
    external: external,
    emptyHrefs: empty,
    nofollow: nofollow,
    externalHosts: List.unmodifiable(sorted),
    urls: List.unmodifiable(urls),
  );
}
