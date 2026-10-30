import 'dart:convert';

import 'package:html/dom.dart' as dom;

import 'image_seo_checker.dart';
import 'seo_scraper_service.dart';

/// One heading found on the page, e.g. `HeadingTag(tag: 'h1', text: 'Pricing')`.
class HeadingTag {
  const HeadingTag({required this.tag, required this.text});

  /// Lower-case tag name: `h1`, `h2` or `h3`.
  final String tag;

  final String text;

  @override
  String toString() => '<$tag> $text';
}

/// The raw SEO fields scraped from a page.
class SeoSnapshot {
  const SeoSnapshot({
    required this.url,
    this.title,
    this.metaDescription,
    this.headings = const [],
    this.hasSchemaMarkup = false,
    this.schemaTypes = const [],
    this.imageReport = const ImageSeoReport.empty(),
    this.error,
    this.errorKind,
  });

  /// Builds a failed snapshot instead of throwing.
  const SeoSnapshot.failure(this.url, this.error, {this.errorKind})
      : title = null,
        metaDescription = null,
        headings = const [],
        hasSchemaMarkup = false,
        schemaTypes = const [],
        imageReport = const ImageSeoReport.empty();

  /// Final URL after redirects (or the raw input if fetching failed).
  final String url;
  final String? title;
  final String? metaDescription;

  /// Every h1/h2/h3 in document order.
  final List<HeadingTag> headings;

  /// True when at least one `script[type="application/ld+json"]` exists.
  final bool hasSchemaMarkup;

  /// `@type` values parsed out of the JSON-LD blocks (may be empty).
  final List<String> schemaTypes;

  /// Alt-text coverage for every `<img>` on the page.
  final ImageSeoReport imageReport;

  /// Human-readable failure reason, or `null` on success.
  final String? error;

  /// Machine-readable failure reason; used to decide if "Retry" is offered.
  final SeoErrorKind? errorKind;

  bool get isSuccess => error == null;

  List<HeadingTag> byTag(String tag) =>
      headings.where((heading) => heading.tag == tag).toList();

  /// Extracts the fields from an already-fetched page.
  factory SeoSnapshot.fromPage(ScrapedPage page) {
    final document = page.document;

    final headings = <HeadingTag>[];
    for (final element in document.querySelectorAll('h1, h2, h3')) {
      final tag = element.localName?.toLowerCase();
      final text = _cleanText(element.text);
      if (tag == null || text.isEmpty) continue;
      headings.add(HeadingTag(tag: tag, text: text));
    }

    final schemaScripts =
        document.querySelectorAll('script[type="application/ld+json"]');

    final title = page.title == null ? null : _cleanText(page.title!);
    final description =
        page.metaDescription == null ? null : _cleanText(page.metaDescription!);

    return SeoSnapshot(
      url: page.uri.toString(),
      title: (title == null || title.isEmpty) ? null : title,
      metaDescription: (description == null || description.isEmpty)
          ? null
          : description,
      headings: List.unmodifiable(headings),
      hasSchemaMarkup: schemaScripts.isNotEmpty,
      schemaTypes: _schemaTypes(document),
      imageReport: checkImageSeo(document),
    );
  }
}

/// Fetches [rawUrl] and extracts title, meta description, headings and
/// JSON-LD presence.
///
/// `https://` is added automatically when the scheme is missing, and every
/// failure (bad URL, timeout, non-2xx, non-HTML, oversized body) is returned
/// as `SeoSnapshot.failure(...)` — this function never throws, so it is safe
/// to call straight from a button handler.
///
/// Pass [scraper] in tests to inject a mocked HTTP client; otherwise the
/// function owns and closes its own client.
Future<SeoSnapshot> extractSeo(
  String rawUrl, {
  SeoScraperService? scraper,
}) async {
  final service = scraper ?? SeoScraperService();

  try {
    // SeoScraperService performs the GET, normalises "example.com" to
    // "https://example.com", applies a timeout and validates the response.
    final page = await service.fetchDocument(rawUrl);
    return SeoSnapshot.fromPage(page);
  } on SeoScrapeException catch (error) {
    return SeoSnapshot.failure(
      rawUrl,
      error.userMessage,
      errorKind: error.kind,
    );
  } catch (error) {
    return SeoSnapshot.failure(
      rawUrl,
      'Unexpected error while scraping the page: $error',
    );
  } finally {
    if (scraper == null) {
      service.close();
    }
  }
}

String _cleanText(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Reads `@type` values from JSON-LD blocks, falling back to microdata.
List<String> _schemaTypes(dom.Document document) {
  final types = <String>{};

  for (final script
      in document.querySelectorAll('script[type="application/ld+json"]')) {
    final raw = script.text.trim();
    if (raw.isEmpty) continue;
    try {
      _collectTypes(jsonDecode(raw), types);
    } on FormatException {
      // Invalid JSON-LD should not break the rest of the extraction.
    }
  }

  if (types.isEmpty && document.querySelector('[itemscope]') != null) {
    types.addAll(
      document
          .querySelectorAll('[itemscope][itemtype]')
          .map((element) => element.attributes['itemtype'] ?? '')
          .where((value) => value.isNotEmpty)
          .map((value) => value.split('/').last)
          .where((value) => value.isNotEmpty),
    );
  }

  final sorted = types.toList()..sort();
  return List.unmodifiable(sorted);
}

void _collectTypes(Object? node, Set<String> out) {
  if (node is List) {
    for (final item in node) {
      _collectTypes(item, out);
    }
    return;
  }
  if (node is Map) {
    final type = node['@type'];
    if (type is String) {
      out.add(type);
    } else if (type is List) {
      out.addAll(type.whereType<String>());
    }
    if (node.containsKey('@graph')) {
      _collectTypes(node['@graph'], out);
    }
  }
}
