import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/services/audit_history_service.dart';
import 'package:mobile_seo/widgets/fix_checklist.dart';
import 'package:mobile_seo/widgets/score_gauge.dart';

import 'support/app_harness.dart';
import 'support/test_fixtures.dart';

Future<void> openSample(WidgetTester tester) async {
  final action = find.text('Explore sample audit');
  await revealByScrolling(tester, action);
  await tester.tap(action.hitTestable().first);
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'all sample destinations work at 320px with large text (${dark ? 'dark' : 'light'})',
      (tester) async {
        var networkClients = 0;
        await HttpOverrides.runZoned(
          () async {
            final app = AppHarness();
            await app.settings.update(
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              reduceMotion: true,
            );
            await pumpTestApp(
              tester,
              harness: app,
              size: const Size(320, 568),
              textScale: 1.6,
            );
            await openSample(tester);
            for (final tab in [
              'On-Page & Content',
              'Technical & Links',
              'Overview',
            ]) {
              await selectAuditTab(tester, tab);
              if (tab == 'On-Page & Content') {
                for (final label in [
                  'Readability & Accessibility',
                  'Scanned images (1)',
                ]) {
                  await revealByScrolling(
                    tester,
                    find.text(label),
                    horizontalFraction: .98,
                  );
                  await tester.tap(find.text(label).hitTestable());
                  await tester.pumpAndSettle();
                }
                expect(
                  find.textContaining('estimated syllables'),
                  findsOneWidget,
                );
                expect(find.text('Alt text is missing or empty'), findsWidgets);
              }
              expect(tester.takeException(), isNull, reason: tab);
            }
            await selectDestination(tester, 'Tools');
            await revealByScrolling(
              tester,
              find.text('Search & social previews'),
            );
            await tester.tap(
              find.text('Search & social previews').hitTestable(),
            );
            await tester.pumpAndSettle();
            expect(find.text('Sample audit · Offline preview'), findsOneWidget);
            await revealByScrolling(
              tester,
              find.text('Social Share Card Debugger'),
              horizontalFraction: .98,
            );
            expect(tester.takeException(), isNull);
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
            await revealByScrolling(tester, find.text('Competitor comparison'));
            await tester.tap(find.text('Competitor comparison').hitTestable());
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await selectDestination(tester, 'Projects');
            expect(find.text('Your websites, organized'), findsOneWidget);
            await selectDestination(tester, 'Settings');
            await revealByScrolling(tester, find.text('Help & SEO glossary'));
            await tester.tap(find.text('Help & SEO glossary').hitTestable());
            await tester.pumpAndSettle();
            await revealByScrolling(
              tester,
              find.text('How is the SEO score calculated?'),
            );
            await tester.tap(
              find.text('How is the SEO score calculated?').hitTestable(),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
            await revealByScrolling(tester, find.text('Privacy Policy'));
            await tester.tap(find.text('Privacy Policy').hitTestable());
            await tester.pumpAndSettle();
            await revealByScrolling(
              tester,
              find.text('Email support'),
              maxDrags: 100,
              horizontalFraction: .98,
            );
            expect(find.text('abiralacharya8@gmail.com'), findsOneWidget);
            await selectAuditTab(tester, 'Terms & Conditions');
            await revealByScrolling(
              tester,
              find.text('Email support'),
              maxDrags: 100,
              horizontalFraction: .98,
            );
            expect(tester.takeException(), isNull);
            expect(app.workspace.history, isEmpty);
            expect(app.workspace.projects, isEmpty);
            expect(networkClients, 0);
            expect(
              find.byWidgetPredicate(
                (widget) => widget is Image && widget.image is NetworkImage,
                skipOffstage: false,
              ),
              findsNothing,
            );
          },
          createHttpClient: (_) {
            networkClients++;
            throw StateError('Sample exploration must stay offline');
          },
        );
      },
    );
  }

  testWidgets(
    'sample fix tracking preserves measured scores and resets when reloaded',
    (tester) async {
      final app = await pumpTestApp(tester);
      await openSample(tester);
      final score = app.audit.result!.score;
      await revealByScrolling(tester, find.text('Start fix').first);
      await tester.tap(find.text('Start fix').first);
      await tester.pumpAndSettle();
      expect(find.text('Move to To do'), findsOneWidget);
      final summary = tester.widget<ScoreSummaryCard>(
        find.byType(ScoreSummaryCard),
      );
      expect(summary.result.score, score);
      expect(summary.projectedScore, greaterThan(score));
      await selectDestination(tester, 'Projects');
      await selectDestination(tester, 'Dashboard');
      expect(find.text('Move to To do'), findsOneWidget);
      await selectDestination(tester, 'Tools');
      await openSample(tester);
      expect(find.text('Move to To do'), findsNothing);
      expect(app.workspace.history, isEmpty);
      expect(app.workspace.projects, isEmpty);
    },
  );

  testWidgets(
    'opening PageSpeed externally preserves the audit and expanded content across navigation',
    (tester) async {
      final launches = <Map<dynamic, dynamic>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          launches.add(call.arguments as Map);
          return true;
        },
      );
      final app = await pumpTestApp(tester);
      final entry = AuditHistoryEntry(
        id: 'saved',
        createdAt: DateTime.utc(2026, 10, 2),
        result: auditResult(),
      );
      app.audit.restore(entry);
      await tester.pumpAndSettle();
      await selectAuditTab(tester, 'Technical & Links');
      await revealByScrolling(tester, find.text('Run PageSpeed'));
      await tester.tap(find.text('Run PageSpeed'));
      await tester.pumpAndSettle();
      expect(
        Uri.parse(launches.single['url'] as String).queryParameters['url'],
        entry.result.url,
      );
      expect(launches.single['useWebView'], isFalse);
      expect(launches.single['useSafariVC'], isFalse);
      await selectAuditTab(tester, 'On-Page & Content');
      await revealByScrolling(tester, find.text('Scanned images (1)'));
      await tester.tap(find.text('Scanned images (1)'));
      await tester.pumpAndSettle();
      await selectAuditTab(tester, 'Overview');
      await selectDestination(tester, 'Projects');
      await selectDestination(tester, 'Dashboard');
      await selectAuditTab(tester, 'Technical & Links');
      expect(find.text('Run PageSpeed'), findsOneWidget);
      expect(app.audit.result, same(entry.result));
      await selectAuditTab(tester, 'On-Page & Content');
      expect(find.text('Alt: A sunny courtyard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'historical snapshots are read-only and only re-audit transitions are verified',
    (tester) async {
      final app = AppHarness();
      final before = await app.workspace.record(
        auditResult(html: incompleteHtml),
        null,
        DateTime.utc(2026, 10, 1),
      );
      final after = await app.workspace.record(
        auditResult(
          html: incompleteHtml.replaceFirst(
            'Short title',
            'A practical guide to a weekend in Kathmandu',
          ),
        ),
        null,
        DateTime.utc(2026, 10, 2),
      );
      await app.workspace.toggleFinding(after.result.url, 'Meta description');
      app.audit.restore(before);
      await pumpTestApp(tester, harness: app);
      expect(find.text('Start fix'), findsNothing);
      expect(
        tester.widget<FixChecklist>(find.byType(FixChecklist)).readOnly,
        isTrue,
      );
      expect(find.text('Verified (0)'), findsOneWidget);
      app.audit.restore(after);
      await tester.pumpAndSettle();
      expect(find.text('Start fix'), findsWidgets);
      expect(find.text('Verified (1)'), findsOneWidget);
      expect(find.text('Move to To do'), findsOneWidget);
      expect(
        tester.widget<FixChecklist>(find.byType(FixChecklist)).readOnly,
        isFalse,
      );
    },
  );

  testWidgets(
    'expanded schema evidence preserves independent scroll state at large text',
    (tester) async {
      final app = AppHarness();
      await app.settings.update(themeMode: ThemeMode.dark, reduceMotion: true);
      app.audit.restore(
        AuditHistoryEntry(
          id: 'schema',
          createdAt: DateTime.utc(2026, 10, 2),
          result: auditResult(),
        ),
      );
      await pumpTestApp(
        tester,
        harness: app,
        size: const Size(320, 568),
        textScale: 1.6,
      );
      await selectAuditTab(tester, 'Technical & Links');
      await revealByScrolling(
        tester,
        find.text('JSON-LD script 1'),
        horizontalFraction: .98,
      );
      await tester.tap(find.text('JSON-LD script 1').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Formatted JSON tree'), findsOneWidget);
      await selectAuditTab(tester, 'Overview');
      await selectAuditTab(tester, 'Technical & Links');
      expect(find.text('Formatted JSON tree'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved workspace errors offer a working recovery action', (
    tester,
  ) async {
    final app = AppHarness(store: MemoryStore()..failReads = true);
    await pumpTestApp(tester, harness: app);
    await selectDestination(tester, 'Projects');
    expect(find.text('Saved data unavailable'), findsOneWidget);
    app.store.failReads = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Your websites, organized'), findsOneWidget);
    expect(find.text('Saved data unavailable'), findsNothing);
  });

  testWidgets(
    'retry save persists the displayed audit and disables duplicate retries',
    (tester) async {
      final clients = [
        TrackingClient(pageResponse),
        TrackingClient(fileResponse),
      ].iterator;
      final app = AppHarness(
        clientFactory: () {
          if (!clients.moveNext()) throw StateError('Unexpected HTTP client');
          return clients.current;
        },
      );
      await pumpTestApp(tester, harness: app);
      app.store.failWrites = true;
      final run = app.audit.run(Uri.parse('https://example.com/guide'));
      await tester.pumpAndSettle();
      await run;
      expect(app.workspace.history, isEmpty);
      final result = app.audit.result;
      final at = app.audit.auditedAt;
      await revealByScrolling(tester, find.text('Retry save'));
      final release = Completer<void>();
      app.store.failWrites = false;
      app.store.beforeWrite = (_) => release.future;
      await tester.tap(find.text('Retry save'));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      release.complete();
      await tester.pumpAndSettle();
      expect(find.text('Retry save'), findsNothing);
      expect(app.workspace.history.single.result, same(result));
      expect(app.workspace.history.single.createdAt, at);
      expect(app.workspace.history.single.siteFiles, isNotNull);
      await selectDestination(tester, 'Projects');
      await selectAuditTab(tester, 'Audit history');
      expect(find.text('View snapshot'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
