import 'content_analyzer.dart';
import 'image_seo_checker.dart';
import 'indexation_checker.dart';
import 'link_checker.dart';
import 'open_graph_checker.dart';
import 'readability_accessibility_analyzer.dart';
import 'schema_inspector.dart';
import 'seo_scraper_service.dart';
import 'security_report.dart';

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
    this.schemaScripts = const [],
    this.imageReport = const ImageSeoReport.empty(),
    this.openGraph = const OpenGraphReport.empty(),
    this.linkAudit = const LinkAudit.empty(),
    this.content = const ContentMetrics.empty(),
    this.indexation = const IndexationInfo.empty(),
    this.security = const SecurityReport.empty(),
    this.readability = const ReadabilityAccessibilityReport(),
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
      schemaScripts = const [],
      imageReport = const ImageSeoReport.empty(),
      openGraph = const OpenGraphReport.empty(),
      linkAudit = const LinkAudit.empty(),
      content = const ContentMetrics.empty(),
      indexation = const IndexationInfo.empty(),
      security = const SecurityReport.empty(),
      readability = const ReadabilityAccessibilityReport();

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
  final List<JsonLdScriptReport> schemaScripts;

  /// Alt-text coverage for every `<img>` on the page.
  final ImageSeoReport imageReport;

  /// Open Graph tags used for social link previews.
  final OpenGraphReport openGraph;

  /// Anchor counts, shown in the Technical & Links tab.
  final LinkAudit linkAudit;
  final ContentMetrics content;
  final IndexationInfo indexation;
  final SecurityReport security;
  final ReadabilityAccessibilityReport readability;

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

    final schemaInspection = inspectSchema(document);

    final title = page.title == null ? null : _cleanText(page.title!);
    final description = page.metaDescription == null
        ? null
        : _cleanText(page.metaDescription!);

    return SeoSnapshot(
      url: page.uri.toString(),
      title: (title == null || title.isEmpty) ? null : title,
      metaDescription: (description == null || description.isEmpty)
          ? null
          : description,
      headings: List.unmodifiable(headings),
      hasSchemaMarkup: schemaInspection.scripts.isNotEmpty,
      schemaTypes: schemaInspection.schemaTypes,
      schemaScripts: schemaInspection.scripts,
      imageReport: checkImageSeo(document),
      openGraph: checkOpenGraph(document),
      linkAudit: checkLinks(document, page.uri),
      content: ContentMetrics.fromDocument(document),
      indexation: IndexationInfo.fromDocument(document, page.uri),
      security: SecurityReport.fromPage(page),
      readability: ReadabilityAccessibilityReport.fromDocument(document),
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
