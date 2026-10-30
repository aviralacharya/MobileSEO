import 'package:html/dom.dart' as dom;

/// Anchor statistics for one page.
///
/// Purely informational: links do not contribute to the audit score, they are
/// shown in the "Technical & Links" tab so the numbers are visible.
class LinkAudit {
  const LinkAudit({
    required this.total,
    required this.internal,
    required this.external,
    required this.emptyHrefs,
    required this.nofollow,
    this.externalHosts = const [],
  });

  const LinkAudit.empty()
      : total = 0,
        internal = 0,
        external = 0,
        emptyHrefs = 0,
        nofollow = 0,
        externalHosts = const [];

  /// Navigable links (`internal + external`).
  final int total;

  /// Links pointing at the audited host.
  final int internal;

  /// Links pointing at another host.
  final int external;

  /// `href=""`, `href="#"` or `javascript:` — links that go nowhere.
  final int emptyHrefs;

  /// Links with `rel="nofollow"` / `nofollow` in a multi-value rel.
  final int nofollow;

  /// Distinct external hosts, sorted.
  final List<String> externalHosts;

  bool get hasLinks => total > 0;

  bool get hasEmptyHrefs => emptyHrefs > 0;

  /// e.g. `14 links · 9 internal · 5 external`.
  String get summary => '$total links · $internal internal · '
      '$external external';
}

/// Counts the anchors in [document], resolving relative hrefs against
/// [pageUrl] so internal and external links can be told apart.
LinkAudit checkLinks(dom.Document document, Uri pageUrl) {
  final hosts = <String>{};
  var internal = 0;
  var external = 0;
  var emptyHrefs = 0;
  var nofollow = 0;

  for (final anchor in document.querySelectorAll('a[href]')) {
    final href = (anchor.attributes['href'] ?? '').trim();

    if (href.isEmpty ||
        href.startsWith('#') ||
        href.toLowerCase().startsWith('javascript:')) {
      emptyHrefs++;
      continue;
    }

    final rel = (anchor.attributes['rel'] ?? '').toLowerCase();
    if (rel.split(RegExp(r'\s+')).contains('nofollow')) {
      nofollow++;
    }

    final resolved = Uri.tryParse(href);
    if (resolved == null) {
      emptyHrefs++;
      continue;
    }

    final target = resolved.hasScheme ? resolved : pageUrl.resolveUri(resolved);
    if (!target.hasScheme && !target.hasAuthority) {
      // Things like `mailto:` and `tel:` parse without a host; treat them as
      // non-navigational rather than external.
      emptyHrefs++;
      continue;
    }

    if (target.host.isEmpty) {
      emptyHrefs++;
      continue;
    }

    if (target.host.toLowerCase() == pageUrl.host.toLowerCase()) {
      internal++;
    } else {
      external++;
      hosts.add(target.host.toLowerCase());
    }
  }

  final sortedHosts = hosts.toList()..sort();

  return LinkAudit(
    total: internal + external,
    internal: internal,
    external: external,
    emptyHrefs: emptyHrefs,
    nofollow: nofollow,
    externalHosts: List.unmodifiable(sortedHosts),
  );
}
