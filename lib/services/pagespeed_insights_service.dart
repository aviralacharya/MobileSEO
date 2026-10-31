import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
  });

  final int? performanceScore;
  final WebVitalMetric lcp;
  final WebVitalMetric cls;
  final WebVitalMetric inp;
  final bool usedOriginData;
  final String? finalUrl;
  final DateTime? analysisTime;

  factory PageSpeedReport.fromJson(Map<String, dynamic> json) {
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
    );
  }
}

class PageSpeedInsightsException implements Exception {
  const PageSpeedInsightsException(this.message);
  final String message;
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

  Future<PageSpeedReport> analyze(String targetUrl) async {
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
      throw PageSpeedInsightsException(
        message ?? 'PageSpeed Insights returned HTTP ${response.statusCode}.',
      );
    }

    if (body['lighthouseResult'] == null) {
      throw const PageSpeedInsightsException(
        'PageSpeed Insights did not include a Lighthouse result for this URL.',
      );
    }
    return PageSpeedReport.fromJson(body);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

double? _number(Object? value) => value is num
    ? value.toDouble()
    : value is String
    ? double.tryParse(value)
    : null;
