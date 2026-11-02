import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/services/app_settings.dart';
import 'package:mobile_seo/services/audit_review.dart';
import 'package:mobile_seo/services/fix_guides.dart';
import 'package:mobile_seo/widgets/fix_guide_section.dart';
import 'package:mobile_seo/widgets/guided_audit_card.dart';

import 'support/app_harness.dart';
import 'support/test_fixtures.dart';

Finder input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets(
    'a guided fix preserves HTML drafts and verifies only a later same-page audit',
    (tester) async {
      const target = 'https://example.com/guide?lang=en';
      final missingTitle = healthyHtml.replaceFirst(
        RegExp(r'<title>.*?</title>'),
        '',
      );
      final pages = [
        TrackingClient((request) => pageResponse(request, html: missingTitle)),
        TrackingClient(fileResponse),
        TrackingClient(pageResponse),
        TrackingClient(fileResponse),
      ];
      final clients = pages.iterator;
      final app = AppHarness(
        clientFactory: () {
          if (!clients.moveNext()) {
            throw StateError('Unexpected network request');
          }
          return clients.current;
        },
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await pumpTestApp(tester, harness: app);
      await tester.enterText(find.byType(TextField), target);
      await tester.tap(find.text('Run SEO Audit'));
      await tester.pumpAndSettle();
      final before = app.audit.result!;
      expect(before.score, 83);
      await revealByScrolling(tester, find.text('Walk me through a fix'));
      await tester.tap(find.text('Walk me through a fix'));
      await tester.pumpAndSettle();
      await revealByScrolling(
        tester,
        find.widgetWithText(ChoiceChip, 'WordPress'),
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'WordPress'))
            .selected,
        isTrue,
      );
      expect(find.text('Page or post editor / Yoast SEO'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Shopify'));
      await tester.pumpAndSettle();
      expect(
        find.text('Shopify admin / content item / Search engine listing'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'HTML'));
      await tester.pumpAndSettle();
      await revealByScrolling(tester, input('Page title'));
      await tester.enterText(
        input('Page title'),
        'A useful <guide> & practical tips',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await revealByScrolling(
        tester,
        find.widgetWithText(ChoiceChip, 'WordPress'),
        upwards: true,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'WordPress'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'HTML'));
      await tester.pumpAndSettle();
      await revealByScrolling(tester, input('Page title'));
      expect(
        tester.widget<TextField>(input('Page title')).controller!.text,
        'A useful <guide> & practical tips',
      );
      await revealByScrolling(tester, find.text('Copy Code'));
      await tester.tap(find.text('Copy Code'));
      await tester.pumpAndSettle();
      expect(
        copied,
        '<title>A useful &lt;guide&gt; &amp; practical tips</title>',
      );
      expect(app.audit.result, same(before));
      expect(app.audit.result!.score, 83);
      expect(app.workspace.projects, isEmpty);
      expect(app.workspace.history, hasLength(1));

      await revealByScrolling(
        tester,
        find.text('I’ve published changes — recheck'),
      );
      await tester.tap(find.text('I’ve published changes — recheck'));
      await tester.pumpAndSettle();
      expect(find.byType(FixGuideSection), findsNothing);
      expect(pages[2].requests.single.url.toString(), target);
      expect(app.workspace.history, hasLength(2));
      expect(app.audit.result!.score, 100);
      expect(
        AuditComparison(
          before: before,
          after: app.audit.result!,
        ).resolved.single.id,
        'Meta title',
      );
      expect(find.text('A real improvement, verified'), findsOneWidget);
      await revealByScrolling(tester, find.text('Finish guide'));
      await tester.tap(find.text('Finish guide'));
      await tester.pumpAndSettle();
      expect(find.byType(GuidedAuditCard), findsNothing);
      final restoredSettings = AppSettings(store: app.store);
      addTearDown(restoredSettings.dispose);
      await restoredSettings.load();
      expect(restoredSettings.showAuditGuide, isFalse);
      expect(restoredSettings.websitePlatform, WebsitePlatform.html);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'sample guides stay offline and readable at large text (${dark ? 'dark' : 'light'})',
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
            await revealByScrolling(tester, find.text('Explore sample audit'));
            await tester.tap(find.text('Explore sample audit'));
            await tester.pumpAndSettle();
            final score = app.audit.result!.score;
            await revealByScrolling(tester, find.text('Walk me through a fix'));
            await tester.tap(find.text('Walk me through a fix'));
            await tester.pumpAndSettle();
            for (final label in ['WordPress', 'Shopify', 'HTML']) {
              final chip = find.widgetWithText(ChoiceChip, label);
              await revealByScrolling(tester, chip);
              await tester.tap(chip.hitTestable());
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            await revealByScrolling(
              tester,
              find.textContaining('Practice guide ·'),
            );
            expect(find.text('I’ve published changes — recheck'), findsNothing);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.text('A real improvement, verified'), findsNothing);
            expect(app.audit.result!.score, score);
            await revealByScrolling(
              tester,
              find.text('Try your own page'),
              upwards: true,
            );
            await tester.tap(find.text('Try your own page'));
            await tester.pumpAndSettle();
            expect(find.byType(TextField), findsOneWidget);
            expect(
              tester
                  .widget<TextField>(find.byType(TextField))
                  .focusNode!
                  .hasFocus,
              isTrue,
            );
            expect(app.workspace.history, isEmpty);
            expect(app.workspace.projects, isEmpty);
            expect(networkClients, 0);
            expect(tester.takeException(), isNull);
          },
          createHttpClient: (_) {
            networkClients++;
            throw StateError('Sample guides must be offline');
          },
        );
      },
    );
  }

  testWidgets(
    'hidden guidance can be restored from Settings without resetting the workspace',
    (tester) async {
      final app = AppHarness();
      await app.settings.update(reduceMotion: true);
      await pumpTestApp(tester, harness: app);
      await revealByScrolling(tester, find.byTooltip('Hide audit guide'));
      await tester.tap(find.byTooltip('Hide audit guide'));
      await tester.pumpAndSettle();
      expect(find.byType(FirstAuditCard), findsNothing);
      await selectDestination(tester, 'Settings');
      await revealByScrolling(tester, find.text('Guided audit hints'));
      await tester.tap(find.text('Guided audit hints'));
      await tester.pumpAndSettle();
      await selectDestination(tester, 'Dashboard');
      expect(find.byType(FirstAuditCard), findsOneWidget);
      expect(app.settings.showAuditGuide, isTrue);
      expect(app.workspace.history, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
