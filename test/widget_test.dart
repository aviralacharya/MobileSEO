import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_seo/main.dart';

/// The default test surface is 800x600, which is shorter than most phones and
/// leaves no room for the tab body under the collapsing header. Pump at a
/// realistic portrait phone size so the layout under test is the real one.
Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SeoAuditApp());
}

void main() {
  testWidgets('renders the audit dashboard', (tester) async {
    await pumpApp(tester);

    expect(find.text('Audit a page'), findsOneWidget);
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget); // hint text
    expect(find.text('Run SEO Audit'), findsOneWidget);
    expect(find.text('Ready when you are'), findsOneWidget);
  });

  testWidgets('blocks empty input before hitting the network', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Run SEO Audit'));
    await tester.pump();

    expect(find.text('Enter a website URL to audit.'), findsOneWidget);
    expect(find.text('Auditing…'), findsNothing);
  });

  testWidgets('shows an inline error for a bare word', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'example');
    await tester.tap(find.widgetWithText(FilledButton, 'Run SEO Audit'));
    await tester.pump();

    expect(find.text('Enter a full domain, like example.com.'), findsOneWidget);
    expect(find.text('Auditing…'), findsNothing);
  });

  testWidgets('clears the validation error when the user edits', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'example');
    await tester.tap(find.widgetWithText(FilledButton, 'Run SEO Audit'));
    await tester.pump();
    expect(find.text('Enter a full domain, like example.com.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.pump();
    expect(find.text('Enter a full domain, like example.com.'), findsNothing);
  });

  testWidgets('keeps one URL field while switching result tabs', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('On-Page & Content'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('No page audited yet'), findsOneWidget);

    // The tab bar scrolls horizontally; swipe it so the last tab is tappable.
    // (Avoid dragUntilVisible: it also scrolls the outer header, which would
    // move the shared search field out of view.)
    await tester.drag(find.byType(TabBar), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Technical & Links'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('No page audited yet'), findsOneWidget);
  });

  testWidgets('keeps the typed URL when visiting another destination', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.pump();

    await tester.tap(find.text('Previews'));
    await tester.pumpAndSettle();
    expect(find.text('SERP & Social Previews'), findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'example.com'), findsOneWidget);
  });

  testWidgets('opens the audit history sheet', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Audit history'));
    await tester.pumpAndSettle();

    expect(find.text('Audit history'), findsOneWidget);
    expect(find.text('0 saved'), findsOneWidget);
  });

  testWidgets('keeps the tab body reachable on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const SeoAuditApp());

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Ready when you are'), findsOneWidget);
  });

  testWidgets('renders in dark mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    expect(find.text('Audit a page'), findsOneWidget);
    expect(find.text('Ready when you are'), findsOneWidget);
  });
}
