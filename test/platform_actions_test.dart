import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/services/sample_audit.dart';
import 'package:mobile_seo/widgets/report_export_sheet.dart';
import 'package:mobile_seo/widgets/support_card.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets(
    'support opens the correct email and offers a clipboard fallback',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      String? launched, copied;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          launched = (call.arguments as Map)['url'] as String;
          return false;
        },
      );
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SupportCard())),
      );
      await tester.tap(find.text('Email support'));
      await tester.pumpAndSettle();
      expect(Uri.parse(launched!).scheme, 'mailto');
      expect(Uri.parse(launched!).path, supportEmail);
      expect(
        Uri.parse(launched!).queryParameters['subject'],
        'MobileSEO support',
      );
      expect(find.textContaining('No email app available'), findsOneWidget);
      await tester.tap(find.text('Copy email'));
      await tester.pumpAndSettle();
      expect(copied, supportEmail);
    },
  );

  testWidgets(
    'report sharing sends a UTF-8 CSV file with a valid popover origin',
    (tester) async {
      final output = Directory('build').createTempSync('share-test-');
      addTearDown(() => output.deleteSync(recursive: true));
      final messenger = tester.binding.defaultBinaryMessenger;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showReportExport(
                  context,
                  result: SampleAudit.create(),
                  source: 'Sample audit',
                ),
                child: const Text('Export'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSV'));
      await tester.pumpAndSettle();
      await revealByScrolling(tester, find.text('Share CSV'));
      await tester.runAsync(() async {
        // File preparation and its completion signal must use real async I/O.
        final shared = Completer<Map<dynamic, dynamic>>();
        messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => output.absolute.path,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async {
            expect(call.method, 'share');
            shared.complete(call.arguments as Map);
            return '';
          },
        );
        await tester.tap(find.text('Share CSV'));
        final params = await shared.future.timeout(const Duration(seconds: 10));
        expect(params['subject'], startsWith('Sample · SEO report'));
        expect(params['originWidth'] as double, greaterThan(0));
        expect(params['originHeight'] as double, greaterThan(0));
        expect(params['mimeTypes'], ['text/csv']);
        final path = (params['paths'] as List).single as String;
        expect(path, endsWith('.csv'));
        expect(
          utf8.decode(await File(path).readAsBytes()),
          contains('"Sample audit"'),
        );
      });
      await tester.pumpAndSettle();
      expect(find.text('Share CSV'), findsOneWidget);
      expect(find.textContaining('Could not create'), findsNothing);
    },
  );
}
