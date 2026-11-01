import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:mobile_seo/services/seo_audit_service.dart';
import 'package:mobile_seo/services/seo_scraper_service.dart';

ScrapedPage _page(String html) {
  return ScrapedPage(
    uri: Uri.parse('https://example.com'),
    document: html_parser.parse(html),
    statusCode: 200,
  );
}

void main() {
  const service = SeoAuditService();

  test('passes a well-optimised page', () {
    final result = service.analyze(
      _page('''
      <html>
        <head>
          <title>A perfectly sized page title for search results</title>
          <meta name="description" content="${'Great description. ' * 5}">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@graph":[
              {"@type":"Organization","name":"Acme"},
              {"@type":"WebSite","name":"Acme"}
            ]}
          </script>
        </head>
        <body>
          <h1>Main heading</h1>
          <h2>Section</h2>
          <h3>Sub section</h3>
        </body>
      </html>
    '''),
    );

    expect(result.title, startsWith('A perfectly sized'));
    expect(result.h1Count, 1);
    expect(result.h2Count, 1);
    expect(result.h3Count, 1);
    expect(result.schemaTypes, ['Organization', 'WebSite']);
    expect(result.hasSchema, isTrue);
    expect(result.score, 100);
    expect(
      result.checks.every((check) => check.status == AuditStatus.good),
      isTrue,
    );
  });

  test('flags a page with no meta tags, headings or schema', () {
    final result = service.analyze(
      _page('<html><body><p>Hello</p></body></html>'),
    );

    expect(result.title, isNull);
    expect(result.description, isNull);
    expect(result.h1Count, 0);
    expect(result.hasSchema, isFalse);
    expect(result.score, lessThan(50));
    expect(
      result.checks
          .take(4)
          .every((check) => check.status == AuditStatus.warning),
      isTrue,
    );
    // No images means nothing to penalise.
    expect(result.imageReport.totalImages, 0);
    expect(
      result.checks.firstWhere((check) => check.label == 'Image SEO').status,
      AuditStatus.good,
    );
  });

  test('warns when the title is too long', () {
    final longTitle = 'x' * 80;
    final result = service.analyze(
      _page(
        '<html><head><title>$longTitle</title></head>'
        '<body><h1>Hi</h1></body></html>',
      ),
    );

    expect(result.checks.first.status, AuditStatus.warning);
    expect(result.checks.first.note, contains('80 characters'));
  });

  test('detects microdata when JSON-LD is absent', () {
    final result = service.analyze(
      _page(
        '<html><body>'
        '<div itemscope itemtype="https://schema.org/LocalBusiness">'
        '<span itemprop="name">Acme</span></div>'
        '</body></html>',
      ),
    );

    expect(result.schemaTypes, ['LocalBusiness']);
  });

  test('passes Open Graph tags through to the result', () {
    final result = service.analyze(
      _page(
        '<html><head>'
        '<meta property="og:title" content="Example">'
        '<meta property="og:description" content="A description">'
        '<meta property="og:image" content="https://example.com/i.png">'
        '</head><body><h1>Hi</h1></body></html>',
      ),
    );

    expect(result.openGraph.isComplete, isTrue);
    expect(result.openGraph.title, 'Example');
    expect(result.openGraph.image, 'https://example.com/i.png');
  });
}
