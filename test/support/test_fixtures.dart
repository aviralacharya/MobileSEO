import 'dart:async';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_seo/controllers/workspace_controller.dart';
import 'package:mobile_seo/services/audit_history_service.dart';
import 'package:mobile_seo/services/local_store.dart';
import 'package:mobile_seo/services/project_service.dart';
import 'package:mobile_seo/services/seo_audit_service.dart';
import 'package:mobile_seo/services/seo_scraper_service.dart';

class MemoryStore implements LocalStore {
  MemoryStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;
  final List<String> writes = [];
  Future<void> Function(String key)? beforeRead, beforeWrite;
  bool failReads = false, failWrites = false;

  @override
  Future<String?> read(String key) async {
    // Capture before waiting to simulate a stale read in flight.
    final value = values[key];
    await beforeRead?.call(key);
    if (failReads) throw StateError('Storage unavailable');
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    await beforeWrite?.call(key);
    if (failWrites) throw StateError('Storage full');
    writes.add(key);
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (failWrites) throw StateError('Storage unavailable');
    values.remove(key);
  }
}

WorkspaceController workspaceFor(MemoryStore store) => WorkspaceController(
  history: AuditHistoryService(store: store),
  projects: ProjectService(store: store),
);

const healthyHtml = '''
<!doctype html><html lang="en"><head>
  <title>A practical guide to a weekend in Kathmandu</title>
  <meta name="description" content="Plan a relaxed weekend in Kathmandu with neighborhood walks, local food and practical travel advice from our experienced guides.">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta property="og:title" content="A weekend in Kathmandu">
  <meta property="og:description" content="Neighborhood walks and local food.">
  <meta property="og:image" content="https://example.com/cover.webp">
  <link rel="canonical" href="https://example.com/guide">
  <script type="application/ld+json">{"@context":"https://schema.org","@type":"Article","headline":"Kathmandu guide"}</script>
</head><body><main>
  <h1>A weekend in Kathmandu</h1>
  <h2>Explore the old town</h2>
  <p>Walk through quiet courtyards and stop at a local cafe. Take water and wear comfortable shoes. Leave time to enjoy the journey.</p>
  <img src="cover.webp" alt="A sunny courtyard" width="1200" height="800" loading="lazy">
  <a href="/guides">More city guides</a>
  <a href="https://other.example.org/about">Local travel advice</a>
</main></body></html>
''';

const incompleteHtml = '''
<!doctype html><html><head><title>Short title</title></head>
<body><h1>City guide</h1><h2>Walk with us</h2><img src="cover.jpg">
<p>Our city guide is being updated with more practical information.</p></body></html>
''';

SeoAuditResult auditResult({
  String url = 'https://example.com/guide',
  String html = healthyHtml,
}) => const SeoAuditService().analyze(
  ScrapedPage(
    uri: Uri.parse(url),
    document: html_parser.parse(html),
    statusCode: 200,
    responseTimeMs: 246,
    responseHeaders: const {'strict-transport-security': 'max-age=31536000'},
  ),
);

http.Response pageResponse(http.Request request, {String html = healthyHtml}) =>
    http.Response(
      html,
      200,
      request: request,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );

http.Response fileResponse(http.Request request) => http.Response(
  switch (request.url.path) {
    '/robots.txt' => 'User-agent: *\nAllow: /',
    '/sitemap.xml' =>
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"></urlset>',
    _ => '# Website guidance\nPublic documentation.',
  },
  200,
  request: request,
);

/// Deliberately permits late responses after close, like an already delivered
/// response. Controllers must reject these with their generation guards.
class TrackingClient extends http.BaseClient {
  TrackingClient(FutureOr<http.Response> Function(http.Request) handler)
    : _delegate = MockClient((request) async => handler(request));

  final http.Client _delegate;
  final List<http.BaseRequest> requests = [];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return _delegate.send(request);
  }

  @override
  void close() {
    closed = true;
    _delegate.close();
  }
}
