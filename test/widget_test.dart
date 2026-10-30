import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_seo/main.dart';

void main() {
  testWidgets('renders the SEO audit home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SeoAuditApp());

    expect(find.text('SEO Audit'), findsOneWidget);
    expect(find.text('Audit a page'), findsOneWidget);
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget); // hint text
    expect(find.text('Run SEO Audit'), findsOneWidget);
    expect(find.text('Ready when you are'), findsOneWidget);
  });

  testWidgets('blocks empty input before hitting the network', (tester) async {
    await tester.pumpWidget(const SeoAuditApp());

    await tester.tap(find.widgetWithText(FilledButton, 'Run SEO Audit'));
    await tester.pump();

    expect(find.text('Enter a website URL to audit.'), findsOneWidget);
    expect(find.text('Auditing…'), findsNothing);
  });

  testWidgets('shows an inline error for a bare word', (tester) async {
    await tester.pumpWidget(const SeoAuditApp());

    await tester.enterText(find.byType(TextField), 'example');
    await tester.tap(find.widgetWithText(FilledButton, 'Run SEO Audit'));
    await tester.pump();

    expect(find.text('Enter a full domain, like example.com.'), findsOneWidget);
    expect(find.text('Auditing…'), findsNothing);
  });

  testWidgets('clears the validation error when the user edits', (tester) async {
    await tester.pumpWidget(const SeoAuditApp());

    await tester.enterText(find.byType(TextField), 'example');
    await tester.tap(find.widgetWithText(FilledButton, 'Run SEO Audit'));
    await tester.pump();
    expect(find.text('Enter a full domain, like example.com.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.pump();
    expect(find.text('Enter a full domain, like example.com.'), findsNothing);
  });
}
