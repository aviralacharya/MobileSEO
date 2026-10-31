import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Pass/fail outcome for one crawl file.
enum SiteFileStatus { pass, fail }

/// Result of probing a single file such as `robots.txt`.
class SiteFileCheck {
  const SiteFileCheck({
    required this.fileName,
    required this.url,
    required this.status,
    required this.detail,
    this.httpStatus,
  });

  /// `robots.txt` or `sitemap.xml`.
  final String fileName;

  /// Absolute URL that was requested.
  final String url;
  final SiteFileStatus status;

  /// Short explanation, e.g. `HTTP 200` or `HTTP 404 — not found`.
  final String detail;
  final int? httpStatus;

  bool get passed => status == SiteFileStatus.pass;
}

enum AiCrawlerAccess { allowed, restricted, disallowed, unknown }

class AiCrawlerStatus {
  const AiCrawlerStatus({
    required this.userAgent,
    required this.access,
    required this.detail,
  });

  final String userAgent;
  final AiCrawlerAccess access;
  final String detail;
}

class AiReadinessReport {
  const AiReadinessReport({
    this.crawlers = const [],
    this.llmsTxt,
    this.llmsFullTxt,
  });

  final List<AiCrawlerStatus> crawlers;
  final SiteFileCheck? llmsTxt;
  final SiteFileCheck? llmsFullTxt;

  int get score {
    if (crawlers.isEmpty) return 0;
    var points = 0;
    for (final crawler in crawlers) {
      points += switch (crawler.access) {
        AiCrawlerAccess.allowed => 20,
        AiCrawlerAccess.restricted => 10,
        AiCrawlerAccess.disallowed => 0,
        AiCrawlerAccess.unknown => 10,
      };
    }
    if (llmsTxt?.passed ?? false) points += 10;
    if (llmsFullTxt?.passed ?? false) points += 10;
    return points.clamp(0, 100);
  }

  int get allowedCount => crawlers
      .where((crawler) => crawler.access == AiCrawlerAccess.allowed)
      .length;
  int get restrictedCount => crawlers
      .where((crawler) => crawler.access == AiCrawlerAccess.restricted)
      .length;
  int get disallowedCount => crawlers
      .where((crawler) => crawler.access == AiCrawlerAccess.disallowed)
      .length;

  factory AiReadinessReport.fromRobots({
    required SiteFileCheck robots,
    required String? body,
    required SiteFileCheck llmsTxt,
    required SiteFileCheck llmsFullTxt,
  }) {
    const agents = ['GPTBot', 'ClaudeBot', 'Google-Extended', 'PerplexityBot'];
    final groups = body == null ? const <_RobotsGroup>[] : _parseRobots(body);
    final crawlers = agents
        .map((agent) {
          if (body == null) {
            final notFound =
                robots.httpStatus == 404 || robots.httpStatus == 410;
            return AiCrawlerStatus(
              userAgent: agent,
              access: notFound
                  ? AiCrawlerAccess.allowed
                  : AiCrawlerAccess.unknown,
              detail: notFound
                  ? 'robots.txt is not published; no rule blocks this crawler.'
                  : 'Could not read robots.txt to determine access.',
            );
          }

          final exactGroups = groups
              .where((group) => group.agents.contains(agent.toLowerCase()))
              .toList();
          final selected = exactGroups.isNotEmpty
              ? exactGroups
              : groups.where((group) => group.agents.contains('*')).toList();
          final rules = selected.expand((group) => group.rules).toList();
          final disallows = rules
              .where(
                (rule) => rule.directive == 'disallow' && rule.path.isNotEmpty,
              )
              .map((rule) => rule.path)
              .toList();
          final allows = rules
              .where(
                (rule) => rule.directive == 'allow' && rule.path.isNotEmpty,
              )
              .map((rule) => rule.path)
              .toList();

          final blocksEverything =
              disallows.contains('/') && !allows.contains('/');
          final isRestricted = disallows.any((path) => path != '/');
          final access = blocksEverything
              ? AiCrawlerAccess.disallowed
              : isRestricted
              ? AiCrawlerAccess.restricted
              : AiCrawlerAccess.allowed;
          final matchingLabel = exactGroups.isNotEmpty
              ? 'explicit $agent group'
              : selected.isNotEmpty
              ? 'wildcard group'
              : 'no matching robots rule';
          final detail = switch (access) {
            AiCrawlerAccess.disallowed => 'Disallow: / in the $matchingLabel.',
            AiCrawlerAccess.restricted =>
              'Some paths are disallowed in the $matchingLabel.',
            AiCrawlerAccess.allowed =>
              allows.contains('/')
                  ? 'Allow: / in the $matchingLabel.'
                  : 'No site-wide block in the $matchingLabel.',
            AiCrawlerAccess.unknown => 'Could not determine crawler access.',
          };
          return AiCrawlerStatus(
            userAgent: agent,
            access: access,
            detail: detail,
          );
        })
        .toList(growable: false);

    return AiReadinessReport(
      crawlers: List.unmodifiable(crawlers),
      llmsTxt: llmsTxt,
      llmsFullTxt: llmsFullTxt,
    );
  }
}

class _RobotsRule {
  const _RobotsRule(this.directive, this.path);
  final String directive;
  final String path;
}

class _RobotsGroup {
  const _RobotsGroup(this.agents, this.rules);
  final List<String> agents;
  final List<_RobotsRule> rules;
}

List<_RobotsGroup> _parseRobots(String text) {
  final groups = <_RobotsGroup>[];
  var agents = <String>[];
  var rules = <_RobotsRule>[];

  void finishGroup() {
    if (agents.isNotEmpty) {
      groups.add(
        _RobotsGroup(List.unmodifiable(agents), List.unmodifiable(rules)),
      );
    }
    agents = <String>[];
    rules = <_RobotsRule>[];
  }

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.split('#').first.trim();
    final colon = line.indexOf(':');
    if (colon < 1) continue;
    final name = line.substring(0, colon).trim().toLowerCase();
    final value = line.substring(colon + 1).trim();
    if (name == 'user-agent') {
      if (rules.isNotEmpty) finishGroup();
      if (value.isNotEmpty) agents.add(value.toLowerCase());
    } else if ((name == 'allow' || name == 'disallow') && agents.isNotEmpty) {
      rules.add(_RobotsRule(name, value));
    }
  }
  finishGroup();
  return groups;
}

/// Combined result for the two site-level crawl files.
class SiteFilesReport {
  const SiteFilesReport({
    required this.robots,
    required this.sitemap,
    this.aiReadiness = const AiReadinessReport(),
  });

  final SiteFileCheck robots;
  final SiteFileCheck sitemap;
  final AiReadinessReport aiReadiness;

  int get passedCount => (robots.passed ? 1 : 0) + (sitemap.passed ? 1 : 0);

  bool get allPassed => robots.passed && sitemap.passed;
}

/// Fetches the root crawl and LLM guidance files and analyzes crawler rules.
///
/// Both requests run in parallel and every failure (timeout, DNS, 403, 404,
/// an HTML error page) is returned as a failed [SiteFileCheck] instead of
/// throwing, so a missing file never interrupts the rest of the audit.
class SiteFilesChecker {
  SiteFilesChecker({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const String _userAgent =
      'MobileSEO-AuditBot/1.0 (+https://example.com/bot)';

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  /// Checks both files for the site that hosts [auditedUrl].
  Future<SiteFilesReport> check(Uri auditedUrl) async {
    final base = baseUrlFor(auditedUrl);

    try {
      String? robotsBody;
      final results = await Future.wait([
        _probe(
          url: base.resolve('/robots.txt'),
          fileName: 'robots.txt',
          passDetail: 'HTTP 200 — found',
          validateBody: _robotsProblem,
          onBody: (body) => robotsBody = body,
        ),
        _probe(
          url: base.resolve('/sitemap.xml'),
          fileName: 'sitemap.xml',
          passDetail: 'HTTP 200 — valid sitemap',
          validateBody: _sitemapProblem,
        ),
        _probe(
          url: base.resolve('/llms.txt'),
          fileName: 'llms.txt',
          passDetail: 'HTTP 200 — found',
          validateBody: _textFileProblem,
        ),
        _probe(
          url: base.resolve('/llms-full.txt'),
          fileName: 'llms-full.txt',
          passDetail: 'HTTP 200 — found',
          validateBody: _textFileProblem,
        ),
      ]);
      return SiteFilesReport(
        robots: results[0],
        sitemap: results[1],
        aiReadiness: AiReadinessReport.fromRobots(
          robots: results[0],
          body: robotsBody,
          llmsTxt: results[2],
          llmsFullTxt: results[3],
        ),
      );
    } catch (_) {
      // Defensive: `check` is documented as never throwing.
      return SiteFilesReport(
        robots: _failed(
          'robots.txt',
          base.resolve('/robots.txt'),
          'Could not check this file',
        ),
        sitemap: _failed(
          'sitemap.xml',
          base.resolve('/sitemap.xml'),
          'Could not check this file',
        ),
        aiReadiness: AiReadinessReport(),
      );
    }
  }

  /// Releases the client if this instance created it.
  void close() {
    if (_ownsClient) _client.close();
  }

  /// Strips the path, query and fragment, keeping scheme, host and port.
  ///
  /// `https://example.com/blog/post?x=1` -> `https://example.com`
  static Uri baseUrlFor(Uri url) {
    return Uri(
      scheme: url.scheme.isEmpty ? 'https' : url.scheme,
      host: url.host,
      port: url.hasPort ? url.port : null,
    );
  }

  Future<SiteFileCheck> _probe({
    required Uri url,
    required String fileName,
    required String passDetail,
    required String? Function(String body) validateBody,
    void Function(String body)? onBody,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .get(url, headers: const {'User-Agent': _userAgent, 'Accept': '*/*'})
          .timeout(timeout);
    } on TimeoutException {
      return _failed(fileName, url, 'Timed out after ${timeout.inSeconds}s');
    } on http.ClientException {
      return _failed(fileName, url, 'Could not reach the site');
    } catch (_) {
      // SocketException, HandshakeException, etc. (kept generic so the file
      // also compiles on Flutter Web).
      return _failed(fileName, url, 'Could not reach the site');
    }

    if (response.statusCode != 200) {
      return SiteFileCheck(
        fileName: fileName,
        url: url.toString(),
        status: SiteFileStatus.fail,
        detail: _statusDetail(response.statusCode),
        httpStatus: response.statusCode,
      );
    }

    final body = _decode(response);
    onBody?.call(body);
    final problem = validateBody(body);
    if (problem != null) {
      return SiteFileCheck(
        fileName: fileName,
        url: url.toString(),
        status: SiteFileStatus.fail,
        detail: problem,
        httpStatus: response.statusCode,
      );
    }

    return SiteFileCheck(
      fileName: fileName,
      url: url.toString(),
      status: SiteFileStatus.pass,
      detail: passDetail,
      httpStatus: response.statusCode,
    );
  }

  SiteFileCheck _failed(String fileName, Uri url, String detail) {
    return SiteFileCheck(
      fileName: fileName,
      url: url.toString(),
      status: SiteFileStatus.fail,
      detail: detail,
    );
  }

  /// A 200 response can still be a soft-404 HTML page, which is not a
  /// robots.txt file.
  static String? _robotsProblem(String body) {
    if (_looksLikeHtml(body)) {
      return 'Returned an HTML page, not a robots.txt file';
    }
    return null;
  }

  /// A 200 response must contain a `<urlset>` or `<sitemapindex>` root.
  static String? _sitemapProblem(String body) {
    if (_looksLikeHtml(body)) {
      return 'Returned an HTML page, not a sitemap';
    }
    final lower = body.toLowerCase();
    if (!lower.contains('<urlset') && !lower.contains('<sitemapindex')) {
      return 'File is not a valid sitemap';
    }
    return null;
  }

  static String? _textFileProblem(String body) {
    if (_looksLikeHtml(body)) return 'Returned an HTML page, not a text file';
    if (body.trim().isEmpty) return 'File is empty';
    return null;
  }

  static bool _looksLikeHtml(String body) {
    final trimmed = body.trimLeft().toLowerCase();
    return trimmed.startsWith('<!doctype html') ||
        trimmed.startsWith('<html') ||
        trimmed.startsWith('<head') ||
        trimmed.startsWith('<body');
  }

  static String _decode(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      return response.body;
    }
  }

  static String _statusDetail(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return 'HTTP $statusCode — access blocked';
    }
    if (statusCode == 404 || statusCode == 410) {
      return 'HTTP $statusCode — not found';
    }
    if (statusCode == 429) {
      return 'HTTP $statusCode — rate limited';
    }
    if (statusCode >= 500) {
      return 'HTTP $statusCode — server error';
    }
    if (statusCode >= 300 && statusCode < 400) {
      return 'HTTP $statusCode — redirect not followed';
    }
    return 'HTTP $statusCode';
  }
}
