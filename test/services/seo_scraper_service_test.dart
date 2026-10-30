import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile_seo/services/seo_scraper_service.dart';

SeoScraperService _serviceFor(int statusCode) {
  return SeoScraperService(
    client: MockClient((_) async => http.Response('response body', statusCode)),
  );
}

Matcher _throwsKind(SeoErrorKind kind) {
  return throwsA(
    isA<SeoScrapeException>().having((e) => e.kind, 'kind', kind),
  );
}

void main() {
  test('fetches and parses an HTML page', () async {
    final client = MockClient((request) async {
      expect(request.url, Uri.parse('https://example.com'));
      return http.Response(
        '<html><head><title> Example </title>'
        '<meta name="description" content=" A demo page "></head>'
        '<body><h1>Hi</h1></body></html>',
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    });

    final page = await SeoScraperService(client: client)
        .fetchDocument('example.com');

    expect(page.title, 'Example');
    expect(page.metaDescription, 'A demo page');
    expect(page.document.querySelector('h1')?.text, 'Hi');
  });

  test('rejects invalid and unsupported URLs before any request', () async {
    final service = SeoScraperService(client: MockClient((_) async {
      fail('HTTP should not be called for invalid URLs');
    }));

    await expectLater(
      service.fetchDocument('   '),
      _throwsKind(SeoErrorKind.invalidUrl),
    );
    await expectLater(
      service.fetchDocument('ftp://example.com'),
      _throwsKind(SeoErrorKind.invalidUrl),
    );
  });

  test('maps 404 to a notFound error', () async {
    await expectLater(
      _serviceFor(404).fetchDocument('https://example.com/missing'),
      throwsA(
        isA<SeoScrapeException>()
            .having((e) => e.kind, 'kind', SeoErrorKind.notFound)
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.userMessage, 'userMessage', contains('Page not found')),
      ),
    );
  });

  test('maps 500 to a serverError', () async {
    await expectLater(
      _serviceFor(500).fetchDocument('https://example.com'),
      throwsA(
        isA<SeoScrapeException>()
            .having((e) => e.kind, 'kind', SeoErrorKind.serverError)
            .having((e) => e.userMessage, 'userMessage', contains('server error')),
      ),
    );
  });

  test('maps 403 and 429 to blocked', () async {
    await expectLater(
      _serviceFor(403).fetchDocument('https://example.com'),
      _throwsKind(SeoErrorKind.blocked),
    );
    await expectLater(
      _serviceFor(429).fetchDocument('https://example.com'),
      _throwsKind(SeoErrorKind.blocked),
    );
  });

  test('times out instead of hanging forever', () async {
    final service = SeoScraperService(
      timeout: const Duration(milliseconds: 20),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('<html></html>', 200);
      }),
    );

    await expectLater(
      service.fetchDocument('https://slow.example.com'),
      _throwsKind(SeoErrorKind.timeout),
    );
  });

  test('rejects non-HTML content types', () async {
    final service = SeoScraperService(
      client: MockClient(
        (_) async => http.Response(
          '{"ok":true}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      service.fetchDocument('https://example.com/api'),
      _throwsKind(SeoErrorKind.notHtml),
    );
  });
}
