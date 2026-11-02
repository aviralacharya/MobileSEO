import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_seo/controllers/audit_controller.dart';
import 'package:mobile_seo/screens/audit_dashboard_screen.dart';

import 'support/app_harness.dart';
import 'support/share_harness.dart';
import 'support/test_fixtures.dart';

void main() {
  testWidgets(
    'a cold share prepares the full URL and audits only after Run is tapped',
    (tester) async {
      const target =
          'https://example.com:8443/guide?topic=seo%20tools&lang=en#intro';
      ShareInbox(['A shared page title\n$target']);
      final page = TrackingClient(pageResponse);
      final files = TrackingClient(fileResponse);
      final clients = [page, files].iterator;
      final app = AppHarness(
        clientFactory: () {
          if (!clients.moveNext()) throw StateError('Unexpected audit');
          return clients.current;
        },
      );
      await pumpTestApp(tester, harness: app);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        target,
      );
      expect(find.textContaining('Shared link ready'), findsOneWidget);
      expect(app.audit.phase, AuditPhase.idle);
      expect(page.requests, isEmpty);
      expect(app.workspace.history, isEmpty);

      await tester.tap(find.text('Run SEO Audit'));
      await tester.pumpAndSettle();
      expect(page.requests.single.url.toString(), target);
      expect(app.audit.result!.url, target);
      expect(app.workspace.history, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a warm share brings up the form without replacing the displayed audit',
    (tester) async {
      final inbox = ShareInbox();
      final app = AppHarness();
      final entry = await app.workspace.record(
        auditResult(),
        null,
        DateTime.utc(2026, 10, 1),
      );
      app.audit.restore(entry);
      await pumpTestApp(tester, harness: app);
      await selectDestination(tester, 'Tools');

      await inbox.send('https://example.com/another?campaign=a&source=b');
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'https://example.com/another?campaign=a&source=b',
      );
      expect(app.audit.result, same(entry.result));
      expect(app.workspace.history, hasLength(1));
      expect(app.audit.source, AuditSource.saved);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'multiple and invalid shares are actionable at 320px with large text',
    (tester) async {
      final inbox = ShareInbox();
      final app = AppHarness();
      await app.settings.update(themeMode: ThemeMode.dark, reduceMotion: true);
      await pumpTestApp(
        tester,
        harness: app,
        size: const Size(320, 568),
        textScale: 1.6,
      );
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/draft',
      );
      await inbox.send(
        'First https://example.com/a\nSecond https://example.com/b?q=2',
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose a shared page'), findsOneWidget);
      final second = find.text('https://example.com/b?q=2');
      await revealByScrolling(tester, second);
      await tester.tap(second.hitTestable());
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'https://example.com/b?q=2',
      );
      expect(find.text('Choose a shared page'), findsNothing);

      await inbox.send('This is a note with no web address.');
      await tester.pumpAndSettle();
      expect(find.textContaining('No web page link was found'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'https://example.com/b?q=2',
      );
      await tester.tap(find.byTooltip('Dismiss shared link'));
      await tester.pumpAndSettle();
      expect(app.workspace.history, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only choosing the shared page supersedes a running audit; late responses stay stale',
    (tester) async {
      final inbox = ShareInbox();
      final oldResponse = Completer<http.Response>();
      final oldClient = TrackingClient((_) => oldResponse.future);
      final newClient = TrackingClient(pageResponse);
      final files = TrackingClient(fileResponse);
      final clients = [oldClient, newClient, files].iterator;
      final app = AppHarness(
        clientFactory: () {
          if (!clients.moveNext()) throw StateError('Unexpected client');
          return clients.current;
        },
      );
      await app.settings.update(reduceMotion: true);
      await pumpTestApp(tester, harness: app);
      await tester.enterText(find.byType(TextField), 'https://example.com/old');
      await tester.tap(find.text('Run SEO Audit'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(app.audit.running, isTrue);

      await inbox.send('https://example.com/new');
      await tester.pump();
      expect(oldClient.closed, isFalse);
      expect(newClient.requests, isEmpty);
      expect(
        tester
            .widget<AuditDashboardScreen>(find.byType(AuditDashboardScreen))
            .urlController
            .text,
        'https://example.com/old',
      );
      await tester.tap(find.text('Audit shared page'));
      await tester.pumpAndSettle();
      expect(oldClient.closed, isTrue);
      expect(app.audit.result!.url, 'https://example.com/new');
      oldResponse.complete(
        http.Response(
          incompleteHtml,
          200,
          headers: {'content-type': 'text/html'},
        ),
      );
      await tester.pumpAndSettle();
      expect(app.audit.result!.url, 'https://example.com/new');
      expect(
        app.workspace.history.single.result.url,
        'https://example.com/new',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
