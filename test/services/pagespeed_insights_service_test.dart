import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_seo/services/pagespeed_insights_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_fixtures.dart';

const _url = 'https://example.com/guide';

Map<String, Object> pageSpeedResponse({double score = .87}) => {
  'analysisUTCTimestamp': '2026-10-20T10:00:00.000Z',
  'lighthouseResult': {
    'finalUrl': _url,
    'categories': {
      'performance': {'score': score},
    },
    'audits': {
      'largest-contentful-paint': {'numericValue': 1800},
      'cumulative-layout-shift': {'numericValue': .02},
    },
  },
};

Future<void> ageCache(Duration age) async {
  final preferences = await SharedPreferences.getInstance();
  final key = preferences.getKeys().singleWhere(
    (key) => key.startsWith('pagespeed_report_'),
  );
  final value = jsonDecode(preferences.getString(key)!) as Map<String, dynamic>;
  value['savedAt'] = DateTime.now().subtract(age).toIso8601String();
  await preferences.setString(key, jsonEncode(value));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'unrelated': 'keep'}));

  test('fresh cache avoids requests and force refresh replaces it', () async {
    var requests = 0;
    final service = PageSpeedInsightsService(
      client: TrackingClient((request) {
        requests++;
        expect(request.url.queryParameters['strategy'], 'mobile');
        expect(request.url.queryParameters['url'], _url);
        return http.Response(
          jsonEncode(pageSpeedResponse(score: requests == 1 ? .87 : .93)),
          200,
        );
      }),
    );
    addTearDown(service.close);
    final first = await service.analyze(_url);
    final cached = await service.analyze(_url);
    expect(first.isCached, isFalse);
    expect(cached.isCached, isTrue);
    expect(cached.performanceScore, 87);
    expect(cached.analysisTime, first.analysisTime);
    expect(requests, 1);
    final refreshed = await service.analyze(_url, forceRefresh: true);
    expect(refreshed.performanceScore, 93);
    expect(refreshed.isCached, isFalse);
    expect(requests, 2);
    expect(await PageSpeedInsightsService.cachedReportCount(), 1);
  });

  test('quota fallback uses a labeled report up to 30 days old', () async {
    var quota = false;
    final service = PageSpeedInsightsService(
      client: TrackingClient(
        (_) => quota
            ? http.Response('{"error":{"status":"RESOURCE_EXHAUSTED"}}', 429)
            : http.Response(jsonEncode(pageSpeedResponse()), 200),
      ),
    );
    addTearDown(service.close);
    await service.analyze(_url);
    await ageCache(const Duration(days: 2));
    quota = true;
    final fallback = await service.analyze(_url);
    expect(fallback.isCached, isTrue);
    expect(fallback.performanceScore, 87);
    await ageCache(const Duration(days: 31));
    await expectLater(
      service.analyze(_url),
      throwsA(
        isA<PageSpeedInsightsException>().having(
          (e) => e.quotaExceeded,
          'quotaExceeded',
          isTrue,
        ),
      ),
    );
  });

  test('clearing during a request prevents late cache resurrection', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final service = PageSpeedInsightsService(
      client: TrackingClient((_) async {
        started.complete();
        await release.future;
        return http.Response(jsonEncode(pageSpeedResponse()), 200);
      }),
    );
    addTearDown(service.close);
    final pending = service.analyze(_url);
    await started.future;
    await PageSpeedInsightsService.clearCache();
    release.complete();
    expect((await pending).performanceScore, 87);
    expect(await PageSpeedInsightsService.cachedReportCount(), 0);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('unrelated'), 'keep');
  });

  test(
    'closed services reject late responses and never populate cache',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final service = PageSpeedInsightsService(
        client: TrackingClient((_) async {
          started.complete();
          await release.future;
          return http.Response(jsonEncode(pageSpeedResponse()), 200);
        }),
      );
      final pending = service.analyze(_url);
      final rejected = expectLater(
        pending,
        throwsA(
          isA<PageSpeedInsightsException>().having(
            (e) => e.message,
            'message',
            contains('cancelled'),
          ),
        ),
      );
      await started.future;
      service.close();
      release.complete();
      await rejected;
      expect(await PageSpeedInsightsService.cachedReportCount(), 0);
    },
  );

  test(
    'missing vitals stay unavailable and field and lab sources stay distinct',
    () {
      final data = pageSpeedResponse();
      data['loadingExperience'] = {
        'metrics': {
          'LARGEST_CONTENTFUL_PAINT_MS': {'percentile': 2300},
        },
      };
      data['originLoadingExperience'] = {
        'metrics': {
          'INTERACTION_TO_NEXT_PAINT': {'percentile': 250},
        },
      };
      final report = PageSpeedReport.fromJson(data);
      expect(report.lcp.value, 2300);
      expect(report.lcp.source, 'Real-user field data');
      expect(report.cls.value, .02);
      expect(report.cls.source, 'Lighthouse lab data');
      expect(report.inp.source, 'Origin field data');
      expect(report.inp.rating, VitalRating.needsImprovement);
      expect(report.usedOriginData, isTrue);
      final withoutField = PageSpeedReport.fromJson(pageSpeedResponse());
      expect(withoutField.inp.value, isNull);
      expect(withoutField.inp.rating, VitalRating.unavailable);
    },
  );

  test(
    'an incomplete API response is not presented or cached as a report',
    () async {
      final service = PageSpeedInsightsService(
        client: TrackingClient((_) => http.Response('{}', 200)),
      );
      addTearDown(service.close);
      await expectLater(
        service.analyze(_url),
        throwsA(isA<PageSpeedInsightsException>()),
      );
      expect(await PageSpeedInsightsService.cachedReportCount(), 0);
    },
  );
}
