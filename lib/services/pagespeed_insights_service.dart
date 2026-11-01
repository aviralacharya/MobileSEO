import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum VitalRating { good, needsImprovement, poor, unavailable }

class WebVitalMetric {
  const WebVitalMetric({
    required this.value,
    required this.rating,
    required this.source,
  });

  final double? value;
  final VitalRating rating;
  final String source;
}

class PageSpeedReport {
  const PageSpeedReport({
    required this.performanceScore,
    required this.lcp,
    required this.cls,
    required this.inp,
    required this.usedOriginData,
    required this.finalUrl,
    required this.analysisTime,
    this.isCached = false,
  });

  final int? performanceScore;
  final WebVitalMetric lcp;
  final WebVitalMetric cls;
  final WebVitalMetric inp;
  final bool usedOriginData;
  final String? finalUrl;
  final DateTime? analysisTime;
  final bool isCached;

  factory PageSpeedReport.fromJson(
    Map<String, dynamic> json, {
    bool isCached = false,
  }) {
    final lighthouse = _map(json['lighthouseResult']);
    final audits = _map(lighthouse['audits']);
    final categories = _map(lighthouse['categories']);
    final performance = _map(categories['performance']);
    final loadingExperience = _map(json['loadingExperience']);
    final pageMetrics = _map(loadingExperience['metrics']);
    final originExperience = _map(json['originLoadingExperience']);
    final originMetrics = _map(originExperience['metrics']);
    final pageIsOriginFallback = loadingExperience['origin_fallback'] == true;
    var usesOrigin = pageIsOriginFallback;

    WebVitalMetric metric({
      required String fieldKey,
      required String labKey,
      required VitalRating Function(double) classify,
      required double Function(double) normalize,
    }) {
      final pageFieldValue = _number(_map(pageMetrics[fieldKey])['percentile']);
      final originFieldValue = _number(
        _map(originMetrics[fieldKey])['percentile'],
      );
      final useOriginField =
          (pageIsOriginFallback || pageFieldValue == null) &&
          originFieldValue != null;
      final fieldValue = useOriginField ? originFieldValue : pageFieldValue;
      if (fieldValue != null) {
        if (useOriginField || pageIsOriginFallback) usesOrigin = true;
        final value = normalize(fieldValue);
        return WebVitalMetric(
          value: value,
          rating: classify(value),
          source: useOriginField || pageIsOriginFallback
              ? 'Origin field data'
              : 'Real-user field data',
        );
      }
      final labValue = _number(_map(audits[labKey])['numericValue']);
      if (labValue != null) {
        return WebVitalMetric(
          value: labValue,
          rating: classify(labValue),
          source: 'Lighthouse lab data',
        );
      }
      return const WebVitalMetric(
        value: null,
        rating: VitalRating.unavailable,
        source: 'No data available',
      );
    }

    final scoreValue = _number(performance['score']);
    return PageSpeedReport(
      performanceScore: scoreValue == null
          ? null
          : (scoreValue * 100).round().clamp(0, 100),
      lcp: metric(
        fieldKey: 'LARGEST_CONTENTFUL_PAINT_MS',
        labKey: 'largest-contentful-paint',
        classify: (value) => value <= 2500
            ? VitalRating.good
            : value <= 4000
            ? VitalRating.needsImprovement
            : VitalRating.poor,
        normalize: (value) => value,
      ),
      cls: metric(
        fieldKey: 'CUMULATIVE_LAYOUT_SHIFT_SCORE',
        labKey: 'cumulative-layout-shift',
        classify: (value) => value <= 0.1
            ? VitalRating.good
            : value <= 0.25
            ? VitalRating.needsImprovement
            : VitalRating.poor,
        normalize: (value) => value > 1 ? value / 1000 : value,
      ),
      inp: metric(
        fieldKey: 'INTERACTION_TO_NEXT_PAINT',
        labKey: 'interaction-to-next-paint',
        classify: (value) => value <= 200
            ? VitalRating.good
            : value <= 500
            ? VitalRating.needsImprovement
            : VitalRating.poor,
        normalize: (value) => value,
      ),
      usedOriginData: usesOrigin,
      finalUrl: lighthouse['finalUrl'] as String? ?? json['id'] as String?,
      analysisTime: DateTime.tryParse(
        json['analysisUTCTimestamp'] as String? ?? '',
      ),
      isCached: isCached,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'performanceScore': performanceScore,
    'lcp': _metricCacheJson(lcp),
    'cls': _metricCacheJson(cls),
    'inp': _metricCacheJson(inp),
    'usedOriginData': usedOriginData,
    'finalUrl': finalUrl,
    'analysisTime': analysisTime?.toIso8601String(),
  };

  factory PageSpeedReport.fromCacheJson(Map<String, dynamic> json) =>
      PageSpeedReport(
        performanceScore: json['performanceScore'] as int?,
        lcp: _metricFromCache(json['lcp']),
        cls: _metricFromCache(json['cls']),
        inp: _metricFromCache(json['inp']),
        usedOriginData: json['usedOriginData'] as bool? ?? false,
        finalUrl: json['finalUrl'] as String?,
        analysisTime: DateTime.tryParse(json['analysisTime'] as String? ?? ''),
        isCached: true,
      );
}

class PageSpeedInsightsException implements Exception {
  const PageSpeedInsightsException(this.message, {this.quotaExceeded = false});
  final String message;
  final bool quotaExceeded;
  @override
  String toString() => message;
}

class PageSpeedInsightsService {
  PageSpeedInsightsService({
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  bool _closed = false;
  static const _freshCacheAge = Duration(hours: 24);
  static const _staleCacheAge = Duration(days: 30);
  static int _cacheGeneration = 0;
  static Future<void> _cacheWrites = Future.value();

  Future<PageSpeedReport> analyze(
    String targetUrl, {
    bool forceRefresh = false,
  }) async {
    final cacheGeneration = _cacheGeneration;
    final cached = await _readCache(targetUrl);
    if (_closed) {
      throw const PageSpeedInsightsException('PageSpeed check cancelled.');
    }
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.savedAt) <= _freshCacheAge) {
      return cached.report;
    }

    final uri = Uri.https(
      'www.googleapis.com',
      '/pagespeedonline/v5/runPagespeed',
      {'url': targetUrl, 'strategy': 'mobile', 'category': 'performance'},
    );

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw PageSpeedInsightsException(
        'PageSpeed analysis timed out. Try again in a moment.',
      );
    } on http.ClientException catch (error) {
      throw PageSpeedInsightsException(
        'Could not reach PageSpeed Insights: ${error.message}',
      );
    } catch (error) {
      throw PageSpeedInsightsException(
        'Could not reach PageSpeed Insights: $error',
      );
    }

    if (_closed) {
      throw const PageSpeedInsightsException('PageSpeed check cancelled.');
    }

    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true))
            as Map,
      );
    } catch (_) {
      throw PageSpeedInsightsException(
        'PageSpeed Insights returned an unreadable response.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final apiError = _map(body['error']);
      final message = apiError['message'] as String?;
      final quotaExceeded = _isQuotaResponse(response.statusCode, body);
      if (quotaExceeded &&
          cached != null &&
          DateTime.now().difference(cached.savedAt) <= _staleCacheAge) {
        return cached.report;
      }
      throw PageSpeedInsightsException(
        quotaExceeded
            ? 'Google PageSpeed Insights has temporarily reached its free request limit.'
            : message ??
                  'PageSpeed Insights returned HTTP ${response.statusCode}.',
        quotaExceeded: quotaExceeded,
      );
    }

    if (body['lighthouseResult'] == null) {
      throw const PageSpeedInsightsException(
        'PageSpeed Insights did not include a Lighthouse result for this URL.',
      );
    }
    final report = PageSpeedReport.fromJson(body);
    await _writeCache(targetUrl, report, cacheGeneration);
    return report;
  }

  Future<_CachedPageSpeedReport?> _readCache(String targetUrl) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_cacheKey(targetUrl));
      if (encoded == null) return null;
      final cache = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      if (cache['targetUrl'] != null && cache['targetUrl'] != targetUrl) {
        return null;
      }
      final savedAt = DateTime.tryParse(cache['savedAt'] as String? ?? '');
      final reportJson = cache['report'];
      if (savedAt == null || reportJson is! Map) return null;
      return _CachedPageSpeedReport(
        PageSpeedReport.fromCacheJson(Map<String, dynamic>.from(reportJson)),
        savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    String targetUrl,
    PageSpeedReport report,
    int generation,
  ) async {
    try {
      await _cacheOperation(() async {
        if (_closed || generation != _cacheGeneration) return;
        final preferences = await SharedPreferences.getInstance();
        if (_closed || generation != _cacheGeneration) return;
        await preferences.setString(
          _cacheKey(targetUrl),
          jsonEncode({
            'targetUrl': targetUrl,
            'savedAt': DateTime.now().toIso8601String(),
            'report': report.toCacheJson(),
          }),
        );
      });
    } catch (_) {
      // A successful live report should remain usable if local storage is full.
    }
  }

  static Future<void> _cacheOperation(Future<void> Function() operation) {
    final next = _cacheWrites.then((_) => operation());
    _cacheWrites = next.catchError((Object _) {});
    return next;
  }

  static Future<int> cachedReportCount() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences
        .getKeys()
        .where((key) => key.startsWith('pagespeed_report_'))
        .length;
  }

  static Future<void> clearCache() {
    _cacheGeneration++;
    return _cacheOperation(() async {
      final preferences = await SharedPreferences.getInstance();
      for (final key in preferences.getKeys().where(
        (key) => key.startsWith('pagespeed_report_'),
      )) {
        final removed = await preferences.remove(key);
        if (!removed) throw StateError('A cached report could not be removed.');
      }
    });
  }

  static String _cacheKey(String targetUrl) {
    var hash = 0x811c9dc5;
    for (final unit in targetUrl.trim().codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return 'pagespeed_report_${hash.toRadixString(16)}';
  }

  static bool _isQuotaResponse(int statusCode, Map<String, dynamic> body) {
    final error = _map(body['error']);
    final text = '${error['message'] ?? ''} ${error['status'] ?? ''}'
        .toLowerCase();
    return statusCode == 429 ||
        text.contains('quota') ||
        text.contains('resource_exhausted') ||
        text.contains('ratelimitexceeded');
  }

  void close() {
    _closed = true;
    if (_ownsClient) _client.close();
  }
}

class _CachedPageSpeedReport {
  const _CachedPageSpeedReport(this.report, this.savedAt);
  final PageSpeedReport report;
  final DateTime savedAt;
}

Map<String, dynamic> _metricCacheJson(WebVitalMetric metric) => {
  'value': metric.value,
  'rating': metric.rating.name,
  'source': metric.source,
};

WebVitalMetric _metricFromCache(Object? value) {
  final json = _map(value);
  final ratingName = json['rating'] as String?;
  final rating = VitalRating.values.firstWhere(
    (item) => item.name == ratingName,
    orElse: () => VitalRating.unavailable,
  );
  return WebVitalMetric(
    value: _number(json['value']),
    rating: rating,
    source: json['source'] as String? ?? 'Saved PageSpeed result',
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

double? _number(Object? value) => value is num
    ? value.toDouble()
    : value is String
    ? double.tryParse(value)
    : null;
