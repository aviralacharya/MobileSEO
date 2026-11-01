import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/services/audit_history_service.dart';
import 'package:mobile_seo/utils/page_identity.dart';

import 'support/app_harness.dart';
import 'support/test_fixtures.dart';

Finder checkboxFor(AuditHistoryEntry entry) => find.byWidgetPredicate(
  (widget) =>
      widget is Checkbox &&
      widget.semanticLabel ==
          'Select ${entry.result.url}, ${formatAuditDate(entry.createdAt)} for comparison',
);

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'saved project editing and before/after evidence fit narrow large text (${dark ? 'dark' : 'light'})',
      (tester) async {
        final app = AppHarness();
        await app.settings.update(
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          reduceMotion: true,
        );
        final before = await app.workspace.record(
          auditResult(html: incompleteHtml),
          null,
          DateTime.utc(2026, 10, 1),
        );
        final after = await app.workspace.record(
          auditResult(),
          null,
          DateTime.utc(2026, 10, 2),
        );
        await app.workspace.saveProject(
          after.result.url,
          name: 'Kathmandu travel guide',
        );
        await pumpTestApp(
          tester,
          harness: app,
          size: const Size(320, 568),
          textScale: 1.6,
        );
        await selectDestination(tester, 'Projects');
        await revealByScrolling(tester, find.byTooltip('Add to favorites'));
        await tester.tap(find.byTooltip('Add to favorites').hitTestable());
        await tester.pumpAndSettle();
        expect(app.workspace.projects.single.favorite, isTrue);
        await revealByScrolling(
          tester,
          find.byTooltip('Project options'),
          upwards: true,
        );
        await tester.tap(find.byTooltip('Project options').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit project'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'Café Kathmandu travel',
        );
        await revealByScrolling(
          tester,
          find.text('Save project'),
          horizontalFraction: .98,
        );
        await tester.tap(find.text('Save project').hitTestable());
        await tester.pumpAndSettle();
        expect(app.workspace.projects.single.name, 'Café Kathmandu travel');
        expect(app.workspace.projects.single.url, after.result.url);
        expect(tester.takeException(), isNull, reason: 'Project editor');
        await revealByScrolling(tester, find.text('History'));
        await tester.tap(find.text('History').hitTestable());
        await tester.pumpAndSettle();
        expect(find.text('Selected page'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'History filters');
        for (final entry in [after, before]) {
          await revealByScrolling(
            tester,
            checkboxFor(entry),
            horizontalFraction: .98,
          );
          await tester.tap(checkboxFor(entry).hitTestable());
          await tester.pumpAndSettle();
        }
        await revealByScrolling(
          tester,
          find.text('Compare (2/2)'),
          upwards: true,
          horizontalFraction: .98,
        );
        await tester.tap(find.text('Compare (2/2)').hitTestable());
        await tester.pumpAndSettle();
        expect(find.text('Before & after'), findsOneWidget);
        expect(find.text('+67 measured points'), findsOneWidget);
        await revealByScrolling(
          tester,
          find.text('Meta title'),
          horizontalFraction: .98,
        );
        await tester.tap(find.text('Meta title').hitTestable());
        await tester.pumpAndSettle();
        expect(find.text('Short title'), findsOneWidget);
        expect(
          find.text('A practical guide to a weekend in Kathmandu'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'history search and comparison selection respect different pages on the same host',
    (tester) async {
      final app = AppHarness();
      final before = await app.workspace.record(
        auditResult(html: incompleteHtml),
        null,
        DateTime.utc(2026, 10, 1),
      );
      final after = await app.workspace.record(
        auditResult(),
        null,
        DateTime.utc(2026, 10, 2),
      );
      final other = await app.workspace.record(
        auditResult(url: 'https://example.com/another-page'),
        null,
        DateTime.utc(2026, 10, 3),
      );
      await pumpTestApp(tester, harness: app);
      await selectDestination(tester, 'Projects');
      await selectAuditTab(tester, 'Audit history');
      await revealByScrolling(tester, checkboxFor(after));
      await tester.tap(checkboxFor(after).hitTestable());
      await tester.pumpAndSettle();
      await revealByScrolling(tester, checkboxFor(other), upwards: true);
      await tester.tap(checkboxFor(other).hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Choose audits of the same page URL, including its path and query.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<Checkbox>(checkboxFor(other)).value, isFalse);
      await tester.enterText(find.byType(TextField), 'example.com/guide');
      await tester.pumpAndSettle();
      expect(checkboxFor(other), findsNothing);
      await revealByScrolling(tester, checkboxFor(before));
      await tester.tap(checkboxFor(before).hitTestable());
      await tester.pumpAndSettle();
      await revealByScrolling(
        tester,
        find.text('Compare (2/2)'),
        upwards: true,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Compare (2/2)'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
