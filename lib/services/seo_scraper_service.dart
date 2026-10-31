import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../utils/url_validator.dart';

/// Why a scrape failed. The UI uses this to pick an icon, a message and
/// whether offering a "Retry" button makes sense.
enum SeoErrorKind {
  invalidUrl,
  timeout,
  blocked,
  notFound,
  serverError,
  network,
  corsBlocked,
  notHtml,
  tooLarge,
  empty,
  unknown,
}

/// Thrown when a page cannot be fetched, decoded, or parsed.
class SeoScrapeException implements Exception {
  const SeoScrapeException(
    this.message, {
    this.kind = SeoErrorKind.unknown,
    this.uri,
    this.statusCode,
  });

  /// Technical message, useful for logs.
  final String message;
  final SeoErrorKind kind;
  final Uri? uri;
  final int? statusCode;

  /// Short, non-technical message that is safe to show to a user.
  String get userMessage {
    switch (kind) {
      case SeoErrorKind.invalidUrl:
        return message;
      case SeoErrorKind.timeout:
        return 'The site took too long to respond. Check the URL and try again.';
      case SeoErrorKind.blocked:
        return 'This site refused the request (HTTP ${statusCode ?? '?'}). '
            'It may be blocking automated access.';
      case SeoErrorKind.notFound:
        return 'Page not found (HTTP ${statusCode ?? 404}). '
            'Double-check the URL.';
      case SeoErrorKind.serverError:
        return 'The site returned a server error (HTTP ${statusCode ?? '?'}). '
            'Try again in a moment.';
      case SeoErrorKind.network:
        return 'Could not reach the site. Check your internet connection.';
      case SeoErrorKind.corsBlocked:
        return 'This site blocks browser based audits (CORS). Run MobileSEO on Android or iOS, or connect a server side fetch service for web audits.';
      case SeoErrorKind.notHtml:
        return 'That link does not return an HTML page, so there is nothing '
            'to audit.';
      case SeoErrorKind.tooLarge:
        return 'The page is too large to audit safely.';
      case SeoErrorKind.empty:
        return 'The page returned an empty response.';
      case SeoErrorKind.unknown:
        return message;
    }
  }

  @override
  String toString() {
    final target = uri == null ? '' : ' ($uri)';
    final status = statusCode == null ? '' : ' [HTTP $statusCode]';
    return 'SeoScrapeException(${kind.name})$status: $message$target';
  }
}

/// A page that was fetched successfully and parsed into a DOM.
class ScrapedPage {
  const ScrapedPage({
    required this.uri,
    required this.document,
    required this.statusCode,
    this.responseHeaders = const {},
    this.responseTimeMs = 0,
  });

  /// Final URL after any redirects.
  final Uri uri;
  final dom.Document document;
  final int statusCode;
  final Map<String, String> responseHeaders;
  final int responseTimeMs;

  String? get title {
    final text = document.querySelector('title')?.text.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  String? get metaDescription {
    final content = document
        .querySelector('meta[name="description"]')
        ?.attributes['content'];
    final trimmed = content?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// Fetches a public web page and returns its parsed HTML document.
///
/// All failures (bad input, timeouts, non-2xx responses, non-HTML content,
/// oversized bodies) surface as [SeoScrapeException], so callers only need to
/// handle one error type.
class SeoScraperService {
  SeoScraperService({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.maxBodyBytes = 10 * 1024 * 1024,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  final int maxBodyBytes;

  /// Downloads [rawUrl] and parses it. `https://` is assumed when no scheme
  /// is given ("example.com" -> "https://example.com").
  Future<ScrapedPage> fetchDocument(String rawUrl) async {
    final uri = _normalizeUrl(rawUrl);

    final http.Response response;
    final stopwatch = Stopwatch()..start();
    try {
      response = await _client
          .get(
            uri,
            headers: const {'Accept': 'text/html,application/xhtml+xml'},
          )
          .timeout(timeout);
      stopwatch.stop();
    } on TimeoutException {
      throw SeoScrapeException(
        'Request timed out after ${timeout.inSeconds}s.',
        kind: SeoErrorKind.timeout,
        uri: uri,
      );
    } on http.ClientException catch (error) {
      final detail = error.message.toLowerCase();
      final cors =
          detail.contains('xmlhttprequest') ||
          detail.contains('failed to fetch') ||
          detail.contains('cors');
      throw SeoScrapeException(
        'Request failed: ${error.message}',
        kind: cors ? SeoErrorKind.corsBlocked : SeoErrorKind.network,
        uri: uri,
      );
    } catch (error) {
      // SocketException, HandshakeException, etc. (kept generic so this file
      // still compiles for Flutter Web, where dart:io is unavailable).
      throw SeoScrapeException(
        'Request failed: $error',
        kind: SeoErrorKind.network,
        uri: uri,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SeoScrapeException(
        'Unexpected status code.',
        kind: _kindForStatus(response.statusCode),
        uri: uri,
        statusCode: response.statusCode,
      );
    }

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.isNotEmpty && !_looksLikeHtml(contentType)) {
      throw SeoScrapeException(
        'Response is not HTML (content-type: $contentType).',
        kind: SeoErrorKind.notHtml,
        uri: uri,
        statusCode: response.statusCode,
      );
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw SeoScrapeException(
        'Response body is empty.',
        kind: SeoErrorKind.empty,
        uri: uri,
        statusCode: response.statusCode,
      );
    }
    if (bytes.length > maxBodyBytes) {
      throw SeoScrapeException(
        'Response is too large '
        '(${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB, '
        'limit ${(maxBodyBytes / 1024 / 1024).toStringAsFixed(1)} MB).',
        kind: SeoErrorKind.tooLarge,
        uri: uri,
        statusCode: response.statusCode,
      );
    }

    final markup = _decodeBody(bytes, contentType);
    try {
      return ScrapedPage(
        uri: response.request?.url ?? uri,
        document: html_parser.parse(markup),
        statusCode: response.statusCode,
        responseHeaders: Map.unmodifiable(response.headers),
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      throw SeoScrapeException(
        'Could not parse HTML: $error',
        kind: SeoErrorKind.unknown,
        uri: uri,
      );
    }
  }

  /// Releases the underlying HTTP client. Only closes clients this service
  /// created itself, not ones injected by the caller.
  void close() {
    if (_ownsClient) _client.close();
  }

  static Uri _normalizeUrl(String rawUrl) {
    final validation = UrlValidator.validate(rawUrl);
    if (!validation.isValid) {
      throw SeoScrapeException(
        validation.message!,
        kind: SeoErrorKind.invalidUrl,
      );
    }
    return validation.uri!;
  }

  static SeoErrorKind _kindForStatus(int statusCode) {
    if (statusCode == 404 || statusCode == 410) return SeoErrorKind.notFound;
    if (statusCode == 401 ||
        statusCode == 403 ||
        statusCode == 429 ||
        statusCode == 451) {
      return SeoErrorKind.blocked;
    }
    if (statusCode >= 500) return SeoErrorKind.serverError;
    return SeoErrorKind.unknown;
  }

  static bool _looksLikeHtml(String contentType) {
    final value = contentType.toLowerCase();
    return value.contains('text/html') || value.contains('application/xhtml');
  }

  static String _decodeBody(List<int> bytes, String contentType) {
    final charset = _charsetFromContentType(contentType);
    final encoding =
        (charset == null ? null : Encoding.getByName(charset)) ?? utf8;
    try {
      return encoding.decode(bytes);
    } on FormatException {
      // A single bad byte should not fail the whole audit.
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static String? _charsetFromContentType(String contentType) {
    final match = RegExp(
      r'charset\s*=\s*"?([\w-]+)"?',
      caseSensitive: false,
    ).firstMatch(contentType);
    return match?.group(1);
  }
}
