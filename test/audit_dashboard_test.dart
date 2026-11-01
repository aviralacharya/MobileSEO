import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:mobile_seo/screens/audit_dashboard_screen.dart';
import 'package:mobile_seo/controllers/audit_controller.dart';
import 'package:mobile_seo/services/seo_audit_service.dart';
import 'package:mobile_seo/services/seo_scraper_service.dart';
import 'package:mobile_seo/theme/app_theme.dart';

import 'support/app_harness.dart';

/// Result-state layout checks that run without touching the network.
SeoAuditResult _result() => const SeoAuditService().analyze(
  ScrapedPage(
    uri: Uri.parse('https://example.com/a-long-enough-article-path'),
    document: html_parser.parse('''
      <html>
        <head>
          <title>A perfectly sized page title for search results</title>
          <meta name="description" content="A description that is long enough to be useful.">
          <meta property="og:image" content="https://example.com/preview.png">
        </head>
        <body>
          <h1>Main heading</h1>
          <h2>Section</h2>
          <img src="a.png" alt="A described image">
        </body>
      </html>
    '''),
    statusCode: 200,
  ),
);

Widget _app(SeoAuditResult result) {
  final controller = TextEditingController(text: result.url);
  addTearDown(controller.dispose);
  return MaterialApp(
    theme: AppTheme.build(Brightness.light),
    darkTheme: AppTheme.build(Brightness.dark),
    home: Scaffold(
      body: AuditDashboardScreen(
        urlController: controller,
        isLoading: false,
        urlError: null,
        errorMessage: null,
        canRetry: true,
        result: result,
        source: AuditSource.sample,
        siteFiles: null,
        checkedFixes: const {},
        tabIndex: 0,
        history: const [],
        onOpenHistory: () {},
        onRun: () {},
        onRetry: () {},
        onUrlEdited: () {},
        onToggleFix: (_) {},
        onResetFixes: () {},
        onTabChanged: (_) {},
      ),
    ),
  );
}

void main() {
  for (final size in const [Size(320, 568), Size(412, 892)]) {
    for (final scale in const [1.0, 1.6]) {
      testWidgets('result layout at $size x$scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(_app(_result()));
        await tester.pumpAndSettle();

        // Collapsed search summary plus the first result cards.
        expect(find.text('Audited page'), findsOneWidget);
        expect(find.text('Fix checklist'), findsOneWidget);
      });
    }
  }

  testWidgets('opens a card detail sheet', (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_result()));
    await tester.pumpAndSettle();

    await revealByScrolling(tester, find.text('View fix').first);
    await tester.tap(find.text('View fix').first);
    await tester.pumpAndSettle();

    expect(find.text('Evidence'), findsOneWidget);
    expect(find.text('How to improve it'), findsOneWidget);
  });
}
