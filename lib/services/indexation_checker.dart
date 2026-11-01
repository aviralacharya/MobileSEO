import 'package:html/dom.dart' as dom;

class HreflangEntry {
  const HreflangEntry(this.language, this.url);
  final String language, url;
}

class IndexationInfo {
  const IndexationInfo({
    this.robotsMeta,
    this.googlebotMeta,
    this.canonicalUrl,
    this.language,
    this.faviconUrl,
    this.viewport,
    this.hreflangs = const [],
  });
  const IndexationInfo.empty()
    : robotsMeta = null,
      googlebotMeta = null,
      canonicalUrl = null,
      language = null,
      faviconUrl = null,
      viewport = null,
      hreflangs = const [];
  final String? robotsMeta,
      googlebotMeta,
      canonicalUrl,
      language,
      faviconUrl,
      viewport;
  final List<HreflangEntry> hreflangs;
  bool get blocksIndexing =>
      [robotsMeta, googlebotMeta].whereType<String>().any(
        (v) =>
            RegExp(r'\b(noindex|nofollow)\b', caseSensitive: false).hasMatch(v),
      );
  String canonicalState(String pageUrl) {
    if (canonicalUrl == null) return 'Missing';
    final a = Uri.tryParse(canonicalUrl!), b = Uri.tryParse(pageUrl);
    return a != null &&
            b != null &&
            a.normalizePath().toString() == b.normalizePath().toString()
        ? 'Self-referencing'
        : 'Points to another URL';
  }

  factory IndexationInfo.fromDocument(dom.Document doc, Uri base) {
    String? meta(String name) => doc
        .querySelectorAll('meta[name]')
        .where((e) => (e.attributes['name'] ?? '').toLowerCase() == name)
        .map((e) => e.attributes['content']?.trim())
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .firstOrNull;
    final canonical = doc
        .querySelector('link[rel~="canonical"]')
        ?.attributes['href'];
    final icon = doc
        .querySelector('link[rel~="icon"],link[rel~="shortcut"]')
        ?.attributes['href'];
    final alternates = <HreflangEntry>[];
    for (final e in doc.querySelectorAll(
      'link[rel~="alternate"][hreflang][href]',
    )) {
      final lang = e.attributes['hreflang']?.trim(),
          href = e.attributes['href']?.trim();
      if (lang != null && href != null && lang.isNotEmpty && href.isNotEmpty) {
        alternates.add(HreflangEntry(lang, base.resolve(href).toString()));
      }
    }
    return IndexationInfo(
      robotsMeta: meta('robots'),
      googlebotMeta: meta('googlebot'),
      canonicalUrl: canonical == null
          ? null
          : base.resolve(canonical).toString(),
      language: doc.documentElement?.attributes['lang'],
      viewport: meta('viewport'),
      faviconUrl: icon == null
          ? base.resolve('/favicon.ico').toString()
          : base.resolve(icon).toString(),
      hreflangs: List.unmodifiable(alternates),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
