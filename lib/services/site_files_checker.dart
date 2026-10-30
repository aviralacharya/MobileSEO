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

/// Combined result for the two site-level crawl files.
class SiteFilesReport {
  const SiteFilesReport({required this.robots, required this.sitemap});

  final SiteFileCheck robots;
  final SiteFileCheck sitemap;

  int get passedCount => (robots.passed ? 1 : 0) + (sitemap.passed ? 1 : 0);

  bool get allPassed => robots.passed && sitemap.passed;
}

/// Fetches `robots.txt` and `sitemap.xml` from the root of the audited site
/// and reports whether each one exists and looks valid.
///
/// Both requests run in parallel and every failure (timeout, DNS, 403, 404,
/// an HTML error page) is returned as a failed [SiteFileCheck] instead of
/// throwing, so a missing file never interrupts the rest of the audit.
class SiteFilesChecker {
  SiteFilesChecker({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  })  : _client = client ?? http.Client(),
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
      final results = await Future.wait([
        _probe(
          url: base.resolve('/robots.txt'),
          fileName: 'robots.txt',
          passDetail: 'HTTP 200 — found',
          validateBody: _robotsProblem,
        ),
        _probe(
          url: base.resolve('/sitemap.xml'),
          fileName: 'sitemap.xml',
          passDetail: 'HTTP 200 — valid sitemap',
          validateBody: _sitemapProblem,
        ),
      ]);
      return SiteFilesReport(robots: results[0], sitemap: results[1]);
    } catch (_) {
      // Defensive: `check` is documented as never throwing.
      return SiteFilesReport(
        robots: _failed('robots.txt', base.resolve('/robots.txt'),
            'Could not check this file'),
        sitemap: _failed('sitemap.xml', base.resolve('/sitemap.xml'),
            'Could not check this file'),
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
  }) async {
    final http.Response response;
    try {
      response = await _client.get(
        url,
        headers: const {
          'User-Agent': _userAgent,
          'Accept': '*/*',
        },
      ).timeout(timeout);
    } on TimeoutException {
      return _failed(
        fileName,
        url,
        'Timed out after ${timeout.inSeconds}s',
      );
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
