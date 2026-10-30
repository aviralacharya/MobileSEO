import 'image_seo_checker.dart';
import 'seo_extractor.dart';
import 'seo_scraper_service.dart';

/// Colour category used by the UI for a single audit check.
enum AuditStatus { good, warning }

/// One line item in the audit report.
class AuditCheck {
  const AuditCheck({
    required this.label,
    required this.value,
    required this.note,
    required this.status,
  });

  final String label;
  final String value;
  final String note;
  final AuditStatus status;
}

/// Everything the home screen needs to render a report.
class SeoAuditResult {
  const SeoAuditResult({
    required this.url,
    required this.title,
    required this.description,
    required this.headings,
    required this.h1Count,
    required this.h2Count,
    required this.h3Count,
    required this.schemaTypes,
    required this.imageReport,
    required this.checks,
  });

  final String url;
  final String? title;
  final String? description;
  final List<HeadingTag> headings;
  final int h1Count;
  final int h2Count;
  final int h3Count;
  final List<String> schemaTypes;
  final ImageSeoReport imageReport;
  final List<AuditCheck> checks;

  bool get hasSchema => schemaTypes.isNotEmpty;

  int get passedCount =>
      checks.where((check) => check.status == AuditStatus.good).length;

  int get score {
    if (checks.isEmpty) return 0;
    return ((passedCount / checks.length) * 100).round();
  }
}

/// Turns scraped data into an [SeoAuditResult] with pass/warn checks.
class SeoAuditService {
  const SeoAuditService();

  /// Fetches [url] and runs the on-page checks.
  ///
  /// Throws [SeoScrapeException] when the page cannot be loaded.
  Future<SeoAuditResult> audit(String url) async {
    final snapshot = await extractSeo(url);
    if (!snapshot.isSuccess) {
      throw SeoScrapeException(
        snapshot.error!,
        kind: snapshot.errorKind ?? SeoErrorKind.unknown,
        uri: Uri.tryParse(snapshot.url),
      );
    }
    return analyzeSnapshot(snapshot);
  }

  /// Runs the checks against an already-fetched page.
  SeoAuditResult analyze(ScrapedPage page) =>
      analyzeSnapshot(SeoSnapshot.fromPage(page));

  /// Runs the checks against extracted SEO fields.
  SeoAuditResult analyzeSnapshot(SeoSnapshot snapshot) {
    final title = snapshot.title;
    final description = snapshot.metaDescription;
    final h1 = snapshot.byTag('h1').length;
    final h2 = snapshot.byTag('h2').length;
    final h3 = snapshot.byTag('h3').length;

    final checks = <AuditCheck>[
      _titleCheck(title),
      _descriptionCheck(description),
      _headingCheck('H1', h1),
      _headingCheck('H2', h2),
      _imageCheck(snapshot.imageReport),
      _schemaCheck(snapshot.schemaTypes),
    ];

    return SeoAuditResult(
      url: snapshot.url,
      title: title,
      description: description,
      headings: snapshot.headings,
      h1Count: h1,
      h2Count: h2,
      h3Count: h3,
      schemaTypes: snapshot.schemaTypes,
      imageReport: snapshot.imageReport,
      checks: checks,
    );
  }

  static AuditCheck _titleCheck(String? title) {
    if (title == null) {
      return const AuditCheck(
        label: 'Meta title',
        value: 'No title tag found',
        note: 'Add a <title> tag — it is the headline of your search result.',
        status: AuditStatus.warning,
      );
    }
    if (title.length < 30) {
      return AuditCheck(
        label: 'Meta title',
        value: title,
        note: '${title.length} characters — a little short. Aim for 30–60.',
        status: AuditStatus.warning,
      );
    }
    if (title.length > 60) {
      return AuditCheck(
        label: 'Meta title',
        value: title,
        note: '${title.length} characters — may be cut off in search results. '
            'Keep it under 60.',
        status: AuditStatus.warning,
      );
    }
    return AuditCheck(
      label: 'Meta title',
      value: title,
      note: '${title.length} characters — ideal length for search results.',
      status: AuditStatus.good,
    );
  }

  static AuditCheck _descriptionCheck(String? description) {
    if (description == null) {
      return const AuditCheck(
        label: 'Meta description',
        value: 'No meta description found',
        note: 'Add a meta description so search engines can summarise the page.',
        status: AuditStatus.warning,
      );
    }
    if (description.length < 70) {
      return AuditCheck(
        label: 'Meta description',
        value: description,
        note: '${description.length} characters — a little short. '
            'Aim for 70–160.',
        status: AuditStatus.warning,
      );
    }
    if (description.length > 160) {
      return AuditCheck(
        label: 'Meta description',
        value: description,
        note: '${description.length} characters — may be truncated. '
            'Keep it under 160.',
        status: AuditStatus.warning,
      );
    }
    return AuditCheck(
      label: 'Meta description',
      value: description,
      note: '${description.length} characters — ideal length for search results.',
      status: AuditStatus.good,
    );
  }

  static AuditCheck _headingCheck(String tag, int count) {
    if (tag == 'H1') {
      if (count == 1) {
        return const AuditCheck(
          label: 'H1 heading',
          value: '1 H1 on the page',
          note: 'Exactly one H1 — great for page structure.',
          status: AuditStatus.good,
        );
      }
      return AuditCheck(
        label: 'H1 heading',
        value: count == 0 ? 'No H1 found' : '$count H1 tags found',
        note: count == 0
            ? 'Add a single H1 that describes the page.'
            : 'Use exactly one H1 per page for the clearest structure.',
        status: AuditStatus.warning,
      );
    }

    if (count == 0) {
      return AuditCheck(
        label: '$tag headings',
        value: 'None found',
        note: 'Consider adding $tag subheadings to break up content.',
        status: AuditStatus.warning,
      );
    }
    return AuditCheck(
      label: '$tag headings',
      value: '$count found',
      note: 'Good — subheadings help readers and crawlers scan the page.',
      status: AuditStatus.good,
    );
  }

  static AuditCheck _imageCheck(ImageSeoReport report) {
    if (report.totalImages == 0) {
      return const AuditCheck(
        label: 'Image SEO',
        value: 'No images found',
        note: 'There are no <img> tags on this page to check.',
        status: AuditStatus.good,
      );
    }
    if (report.isHealthy) {
      return AuditCheck(
        label: 'Image SEO',
        value: 'All ${report.totalImages} images have alt text',
        note: 'Every image is described for search engines and screen readers.',
        status: AuditStatus.good,
      );
    }
    return AuditCheck(
      label: 'Image SEO',
      value: '${report.missingAltCount} out of ${report.totalImages} '
          'images missing alt text',
      note: report.missingAltCount == report.totalImages
          ? 'None of the images have alt text. Describe each one in a few words.'
          : 'Add descriptive alt text to the images listed below.',
      status: AuditStatus.warning,
    );
  }

  static AuditCheck _schemaCheck(List<String> types) {
    if (types.isEmpty) {
      return const AuditCheck(
        label: 'Schema markup',
        value: 'Not detected',
        note: 'Add JSON-LD structured data to unlock rich results.',
        status: AuditStatus.warning,
      );
    }
    return AuditCheck(
      label: 'Schema markup',
      value: types.join(', '),
      note: 'Structured data detected on the page.',
      status: AuditStatus.good,
    );
  }
}
