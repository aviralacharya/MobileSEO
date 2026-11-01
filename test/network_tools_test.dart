import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_seo/screens/competitor_compare_screen.dart';
import 'package:mobile_seo/services/link_checker.dart';
import 'package:mobile_seo/widgets/audit_cards.dart';

import 'support/test_fixtures.dart';

Widget toolApp(Widget child) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: child,
);

Widget linksPage(List<String> urls) => toolApp(
  Scaffold(
    body: SingleChildScrollView(
      child: LinksCard(
        audit: LinkAudit(
          total: urls.length,
          internal: urls.length,
          external: 0,
          emptyHrefs: 0,
          nofollow: 0,
          urls: urls,
        ),
      ),
    ),
  ),
);

Finder urlField(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets(
    'link scan bounds concurrency and unique requests, retries HEAD and distinguishes unavailable links',
    (tester) async {
      final release = Completer<void>();
      var active = 0, peak = 0;
      final client = TrackingClient((request) async {
        active++;
        if (active > peak) peak = active;
        await release.future;
        active--;
        final status = switch ((request.url.path, request.method)) {
          ('/0', 'HEAD') => 405,
          ('/1', _) => 404,
          ('/2', _) => 403,
          _ => 200,
        };
        return http.Response('', status);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          linksPage([
            for (var i = 0; i < 30; i++) 'https://example.com/$i',
            'https://example.com/0',
          ]),
        );
        await tester.tap(find.text('Scan for Broken Links'));
        await tester.pump();
        expect(client.requests, hasLength(3));
        expect(find.text('Scanning 0/25…'), findsOneWidget);
        release.complete();
        await tester.pumpAndSettle();
        expect(peak, 3);
        expect(
          client.requests.where((request) => request.method == 'HEAD'),
          hasLength(25),
        );
        expect(
          client.requests
              .where((request) => request.method == 'GET')
              .single
              .url
              .path,
          '/0',
        );
        expect(
          find.text('1 HTTP-error links · 1 unavailable · 25 checked'),
          findsOneWidget,
        );
        expect(client.closed, isTrue);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );

  testWidgets(
    'cancelled link responses cannot overwrite a new scan or schedule more work',
    (tester) async {
      final release = Completer<void>();
      final old = TrackingClient((_) async {
        await release.future;
        return http.Response('', 404);
      });
      final fresh = TrackingClient((_) => http.Response('', 200));
      final clients = [old, fresh].iterator;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            linksPage([
              for (var i = 0; i < 5; i++) 'https://example.com/$i',
              'https://example.com/0',
            ]),
          );
          await tester.tap(find.text('Scan for Broken Links'));
          await tester.pump();
          expect(find.text('Scanning 0/5…'), findsOneWidget);
          await tester.tap(find.text('Cancel link scan'));
          await tester.pump();
          expect(old.closed, isTrue);
          await tester.tap(find.text('Scan for Broken Links'));
          await tester.pumpAndSettle();
          release.complete();
          await tester.pumpAndSettle();
          expect(old.requests, hasLength(3));
          expect(fresh.requests, hasLength(5));
          expect(
            find.text('0 HTTP-error links · 0 unavailable · 5 checked'),
            findsOneWidget,
          );
          expect(find.text('https://example.com/0'), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () {
          if (!clients.moveNext()) throw StateError('Unexpected HTTP client');
          return clients.current;
        },
      );
    },
  );

  for (final dispose in [false, true]) {
    testWidgets(
      '${dispose ? 'disposing' : 'replacing'} link content closes the active scan',
      (tester) async {
        final release = Completer<void>();
        final client = TrackingClient((_) async {
          await release.future;
          return http.Response('', 404);
        });
        await http.runWithClient(() async {
          await tester.pumpWidget(linksPage(['https://example.com/old']));
          await tester.tap(find.text('Scan for Broken Links'));
          await tester.pump();
          await tester.pumpWidget(
            dispose
                ? const SizedBox.shrink()
                : linksPage(['https://example.com/new']),
          );
          expect(client.closed, isTrue);
          release.complete();
          await tester.pumpAndSettle();
          expect(find.text('https://example.com/old'), findsNothing);
          expect(find.textContaining('HTTP-error links'), findsNothing);
          expect(tester.takeException(), isNull);
        }, () => client);
      },
    );
  }

  testWidgets(
    'competitor cancellation rejects late pages and reruns with the latest URLs',
    (tester) async {
      final release = Completer<void>();
      final old = TrackingClient((request) async {
        await release.future;
        return pageResponse(request, html: incompleteHtml);
      });
      final fresh = TrackingClient(
        (request) => request.url.path == '/guide'
            ? pageResponse(request)
            : fileResponse(request),
      );
      final clients = [old, fresh].iterator;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            toolApp(
              CompetitorCompareScreen(
                result: auditResult(),
                onGoToAudit: () {},
              ),
            ),
          );
          await tester.enterText(
            urlField('Competitor URL'),
            'https://old.example.com/guide',
          );
          await tester.tap(find.text('Compare Websites'));
          await tester.pump();
          expect(old.requests, hasLength(2));
          await tester.tap(find.text('Cancel comparison'));
          await tester.pumpAndSettle();
          expect(old.closed, isTrue);
          await tester.enterText(
            urlField('Competitor URL'),
            'https://new.example.com/guide',
          );
          await tester.tap(find.text('Compare Websites'));
          await tester.pumpAndSettle();
          expect(find.text('Comparison results'), findsOneWidget);
          expect(find.text('new.example.com'), findsOneWidget);
          release.complete();
          await tester.pumpAndSettle();
          expect(old.requests, hasLength(2));
          expect(fresh.requests, hasLength(10));
          expect(fresh.closed, isTrue);
          expect(find.text('old.example.com'), findsNothing);
          expect(find.text('new.example.com'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () {
          if (!clients.moveNext()) throw StateError('Unexpected HTTP client');
          return clients.current;
        },
      );
    },
  );

  for (final dispose in [false, true]) {
    testWidgets(
      '${dispose ? 'disposing' : 'changing the audited page'} cancels pending competitor site checks',
      (tester) async {
        final release = Completer<void>();
        final client = TrackingClient((request) async {
          if (request.url.path == '/guide') return pageResponse(request);
          await release.future;
          return fileResponse(request);
        });
        await http.runWithClient(() async {
          await tester.pumpWidget(
            toolApp(
              CompetitorCompareScreen(
                result: auditResult(),
                onGoToAudit: () {},
              ),
            ),
          );
          await tester.enterText(
            urlField('Competitor URL'),
            'https://other.example.com/guide',
          );
          await tester.tap(find.text('Compare Websites'));
          await tester.pumpAndSettle();
          expect(find.text('Comparison results'), findsOneWidget);
          expect(client.requests, hasLength(10));
          await tester.pumpWidget(
            dispose
                ? const SizedBox.shrink()
                : toolApp(
                    CompetitorCompareScreen(
                      result: auditResult(url: 'https://example.com/new'),
                      onGoToAudit: () {},
                    ),
                  ),
          );
          expect(client.closed, isTrue);
          release.complete();
          await tester.pumpAndSettle();
          expect(find.text('Comparison results'), findsNothing);
          if (!dispose) {
            expect(
              tester
                  .widget<TextField>(urlField('Your Website URL'))
                  .controller!
                  .text,
              'https://example.com/new',
            );
          }
          expect(tester.takeException(), isNull);
        }, () => client);
      },
    );
  }
}
