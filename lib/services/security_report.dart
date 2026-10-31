import 'seo_scraper_service.dart';

class SecurityReport {
  const SecurityReport({
    this.hsts = false,
    this.csp = false,
    this.xFrameOptions = false,
    this.xContentTypeOptions = false,
    this.server,
    this.responseTimeMs = 0,
    this.mixedContentUrls = const [],
  });
  const SecurityReport.empty()
    : hsts = false,
      csp = false,
      xFrameOptions = false,
      xContentTypeOptions = false,
      server = null,
      responseTimeMs = 0,
      mixedContentUrls = const [];
  final bool hsts, csp, xFrameOptions, xContentTypeOptions;
  final String? server;
  final int responseTimeMs;
  final List<String> mixedContentUrls;
  factory SecurityReport.fromPage(ScrapedPage page) {
    final h = <String, String>{
      for (final e in page.responseHeaders.entries)
        e.key.toLowerCase(): e.value,
    };
    final mixed = <String>{};
    if (page.uri.scheme.toLowerCase() == 'https') {
      for (final element in page.document.querySelectorAll(
        'img[src],script[src],link[href]',
      )) {
        final raw = element
            .attributes[element.localName == 'link' ? 'href' : 'src']
            ?.trim();
        if (raw == null || raw.isEmpty) continue;
        final resolved = page.uri.resolve(raw);
        if (resolved.scheme.toLowerCase() == 'http')
          mixed.add(resolved.toString());
      }
    }
    return SecurityReport(
      hsts: (h['strict-transport-security'] ?? '').isNotEmpty,
      csp: (h['content-security-policy'] ?? '').isNotEmpty,
      xFrameOptions: (h['x-frame-options'] ?? '').isNotEmpty,
      xContentTypeOptions: (h['x-content-type-options'] ?? '').isNotEmpty,
      server: h['server'],
      responseTimeMs: page.responseTimeMs,
      mixedContentUrls: List.unmodifiable(mixed),
    );
  }
}
