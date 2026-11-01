import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile_seo/services/site_files_checker.dart';

const _robotsFile = '''
User-agent: *
Disallow: /admin
Sitemap: https://example.com/sitemap.xml
''';

const _sitemapFile = '''
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/</loc></url>
</urlset>
''';

SiteFilesChecker _checker({
  http.Response? robots,
  http.Response? sitemap,
  List<Uri>? requested,
  Duration timeout = const Duration(seconds: 8),
}) {
  return SiteFilesChecker(
    timeout: timeout,
    client: MockClient((request) async {
      requested?.add(request.url);
      return switch (request.url.path) {
        '/robots.txt' => robots ?? http.Response('not found', 404),
        '/sitemap.xml' => sitemap ?? http.Response('not found', 404),
        _ => http.Response('not found', 404),
      };
    }),
  );
}

void main() {
  test('passes both files when they exist and look valid', () async {
    final report = await _checker(
      robots: http.Response(_robotsFile, 200),
      sitemap: http.Response(_sitemapFile, 200),
    ).check(Uri.parse('https://example.com/blog/a-post?ref=nav'));

    expect(report.robots.passed, isTrue);
    expect(report.sitemap.passed, isTrue);
    expect(report.allPassed, isTrue);
    expect(report.passedCount, 2);
    expect(report.robots.fileName, 'robots.txt');
    expect(report.sitemap.fileName, 'sitemap.xml');
  });

  test('requests the site root, keeping scheme, host and port', () async {
    final requested = <Uri>[];

    await _checker(
      robots: http.Response(_robotsFile, 200),
      sitemap: http.Response(_sitemapFile, 200),
      requested: requested,
    ).check(Uri.parse('http://example.com:8080/blog/post?x=1#top'));

    expect(
      requested,
      unorderedEquals([
        Uri.parse('http://example.com:8080/robots.txt'),
        Uri.parse('http://example.com:8080/sitemap.xml'),
        Uri.parse('http://example.com:8080/llms.txt'),
        Uri.parse('http://example.com:8080/llms-full.txt'),
      ]),
    );
  });

  test('fails a missing robots.txt but still passes the sitemap', () async {
    final report = await _checker(sitemap: http.Response(_sitemapFile, 200))
        .check(Uri.parse('https://example.com'));

    expect(report.robots.passed, isFalse);
    expect(report.robots.httpStatus, 404);
    expect(report.robots.detail, contains('not found'));
    expect(report.sitemap.passed, isTrue);
    expect(report.allPassed, isFalse);
    expect(report.passedCount, 1);
  });

  test('rejects a soft-404 HTML page served with HTTP 200', () async {
    final report = await _checker(
      robots: http.Response(
        '<!DOCTYPE html><html><body>Oops</body></html>',
        200,
      ),
      sitemap: http.Response('<html><body>Not here</body></html>', 200),
    ).check(Uri.parse('https://example.com'));

    expect(report.robots.passed, isFalse);
    expect(report.robots.detail, contains('HTML'));
    expect(report.sitemap.passed, isFalse);
    expect(report.sitemap.detail, contains('HTML'));
  });

  test('rejects a 200 response that is not a sitemap', () async {
    final report = await _checker(sitemap: http.Response('{"ok":true}', 200))
        .check(Uri.parse('https://example.com'));

    expect(report.sitemap.passed, isFalse);
    expect(report.sitemap.httpStatus, 200);
    expect(report.sitemap.detail, contains('not a valid sitemap'));
  });

  test('reports blocked and server-error statuses without throwing', () async {
    final blocked = await _checker(
      robots: http.Response('forbidden', 403),
      sitemap: http.Response('boom', 500),
    ).check(Uri.parse('https://example.com'));

    expect(blocked.robots.passed, isFalse);
    expect(blocked.robots.detail, contains('access blocked'));
    expect(blocked.sitemap.passed, isFalse);
    expect(blocked.sitemap.detail, contains('server error'));
  });

  test('times out into a failed check instead of hanging', () async {
    final checker = SiteFilesChecker(
      timeout: const Duration(milliseconds: 20),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response(_robotsFile, 200);
      }),
    );

    final report = await checker.check(Uri.parse('https://slow.example.com'));

    expect(report.robots.passed, isFalse);
    expect(report.robots.detail, contains('Timed out'));
    expect(report.sitemap.passed, isFalse);
  });

  test('turns a transport failure into failed checks', () async {
    final checker = SiteFilesChecker(
      client: MockClient((_) async {
        throw http.ClientException('connection reset');
      }),
    );

    final report = await checker.check(Uri.parse('https://example.com'));

    expect(report.robots.passed, isFalse);
    expect(report.robots.detail, 'Could not reach the site');
    expect(report.sitemap.passed, isFalse);
    expect(report.allPassed, isFalse);
  });
}
