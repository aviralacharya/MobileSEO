import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile_seo/services/seo_extractor.dart';
import 'package:mobile_seo/services/seo_scraper_service.dart';

const _html = '''
<html>
  <head>
    <title>  Example  Site  </title>
    <meta name="description" content="A short page about SEO.">
    <meta property="og:title" content="Example Site">
    <meta property="og:description" content="A short page about SEO.">
    <meta property="og:image" content="https://example.com/preview.png">
    <script type="application/ld+json">
      {"@context":"https://schema.org","@type":"WebSite","name":"Example"}
    </script>
  </head>
  <body>
    <h1>Main heading</h1>
    <h2> First   section </h2>
    <h3>Sub section</h3>
    <h2>Second section</h2>
  </body>
</html>
''';

SeoScraperService _scraperReturning(http.Response response) {
  return SeoScraperService(
    client: MockClient((_) async => response),
  );
}

void main() {
  test('extracts title, description, headings and schema', () async {
    final snapshot = await extractSeo(
      'https://example.com',
      scraper: _scraperReturning(
        http.Response(_html, 200, headers: {'content-type': 'text/html'}),
      ),
    );

    expect(snapshot.isSuccess, isTrue);
    expect(snapshot.title, 'Example Site');
    expect(snapshot.metaDescription, 'A short page about SEO.');
    expect(snapshot.hasSchemaMarkup, isTrue);
    expect(snapshot.schemaTypes, ['WebSite']);

    // Open Graph tags are extracted alongside the regular SEO fields.
    expect(snapshot.openGraph.isComplete, isTrue);
    expect(snapshot.openGraph.title, 'Example Site');
    expect(snapshot.openGraph.image, 'https://example.com/preview.png');

    // Document order, tag names preserved, whitespace collapsed.
    expect(
      snapshot.headings.map((heading) => '${heading.tag}:${heading.text}'),
      [
        'h1:Main heading',
        'h2:First section',
        'h3:Sub section',
        'h2:Second section',
      ],
    );
    expect(
      snapshot.byTag('h2').map((heading) => heading.text),
      ['First section', 'Second section'],
    );
  });

  test('adds https:// when the scheme is missing', () async {
    Uri? requested;
    final snapshot = await extractSeo(
      'example.com/blog',
      scraper: SeoScraperService(
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(
            '<html><head><title>Blog</title></head><body></body></html>',
            200,
            headers: {'content-type': 'text/html'},
          );
        }),
      ),
    );

    expect(requested.toString(), 'https://example.com/blog');
    expect(snapshot.title, 'Blog');
  });

  test('returns a failure snapshot instead of throwing', () async {
    final snapshot = await extractSeo(
      'https://example.com',
      scraper: _scraperReturning(http.Response('nope', 500)),
    );

    expect(snapshot.isSuccess, isFalse);
    expect(snapshot.error, contains('server error'));
    expect(snapshot.errorKind, SeoErrorKind.serverError);
    expect(snapshot.title, isNull);
  });

  test('reports an invalid URL without a request', () async {
    var called = false;
    final snapshot = await extractSeo(
      'ftp://example.com',
      scraper: SeoScraperService(
        client: MockClient((_) async {
          called = true;
          return http.Response('', 200);
        }),
      ),
    );

    expect(called, isFalse);
    expect(snapshot.isSuccess, isFalse);
    expect(snapshot.errorKind, SeoErrorKind.invalidUrl);
    expect(snapshot.error, contains('http:// and https://'));
  });

  test('detects missing schema markup', () async {
    final snapshot = await extractSeo(
      'https://example.com',
      scraper: _scraperReturning(
        http.Response(
          '<html><head><title>Plain</title></head><body></body></html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      ),
    );

    expect(snapshot.hasSchemaMarkup, isFalse);
    expect(snapshot.schemaTypes, isEmpty);
  });
}
