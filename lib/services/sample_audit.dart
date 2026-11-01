import 'package:html/parser.dart' as html_parser;

import 'seo_audit_service.dart';
import 'seo_scraper_service.dart';
import 'site_files_checker.dart';

/// Bundled HTML only. Opening or exploring this audit requires no network.
class SampleAudit {
  const SampleAudit._();
  static const url = 'https://example.com/guides/weekend-in-kathmandu';

  static SeoAuditResult create() => const SeoAuditService().analyze(
    ScrapedPage(
      uri: Uri.parse(url),
      statusCode: 200,
      responseTimeMs: 246,
      responseHeaders: const {'strict-transport-security': 'max-age=31536000'},
      document: html_parser.parse('''
      <!doctype html><html lang="en"><head>
        <title>Kathmandu guide</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="description" content="Discover local cafes, peaceful courtyards and memorable walks in Kathmandu. Plan a relaxed weekend with our practical city guide and local travel tips.">
        <meta property="og:title" content="A weekend in Kathmandu">
        <link rel="canonical" href="$url">
      </head><body><main>
        <h1>A weekend in Kathmandu</h1>
        <p>Explore the city at your own pace. This two-day guide brings together quiet courtyards, local food and walks through historic neighborhoods.</p>
        <h2>Start with the old town</h2>
        <p>Leave early for a walk through the old town. Take water, wear comfortable shoes and leave time to stop in small cafes along the way.</p>
        <img src="courtyard.webp" width="1200" height="800" loading="lazy">
        <h2>Make space for local food</h2>
        <p>Ask about seasonal dishes and try a neighborhood restaurant. A flexible plan gives you time to discover places recommended by local people.</p>
        <a href="/guides">More city guides</a><a href="/about">About our team</a>
      </main></body></html>
    '''),
    ),
  );

  static SiteFilesReport get files {
    SiteFileCheck file(String name, bool found) => SiteFileCheck(
      fileName: name,
      url: 'https://example.com/$name',
      status: found ? SiteFileStatus.pass : SiteFileStatus.fail,
      detail: found
          ? 'Sample · HTTP 200 — found'
          : 'Sample · HTTP 404 — not found',
      httpStatus: found ? 200 : 404,
    );
    final robots = file('robots.txt', true);
    return SiteFilesReport(
      robots: robots,
      sitemap: file('sitemap.xml', true),
      aiReadiness: AiReadinessReport.fromRobots(
        robots: robots,
        body: 'User-agent: *\nAllow: /',
        llmsTxt: file('llms.txt', false),
        llmsFullTxt: file('llms-full.txt', false),
      ),
    );
  }
}
