import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/theme/app_theme.dart';
import 'package:mobile_seo/widgets/audit_cards.dart';

import 'support/app_harness.dart';

const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

Widget _page(String url, {bool enabled = true}) => MaterialApp(
  theme: AppTheme.build(Brightness.dark),
  home: Scaffold(
    body: SingleChildScrollView(
      child: CoreWebVitalsCard(
        auditedUrl: url,
        localFetchTimeMs: 120,
        enabled: enabled,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'opens the complete audited URL in an external mobile PageSpeed report',
    (tester) async {
      const target =
          'https://example.com:8443/guide?q=seo%20audit&lang=ne#summary';
      final launches = <Map<dynamic, dynamic>>[];
      var networkClients = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _launcher,
        (call) async {
          expect(call.method, 'launch');
          launches.add(call.arguments as Map);
          return true;
        },
      );
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(_page(target));
          expect(launches, isEmpty);
          await tester.tap(find.text('Run PageSpeed'));
          await tester.pumpAndSettle();
          final arguments = launches.single;
          final destination = Uri.parse(arguments['url'] as String);
          expect(destination.scheme, 'https');
          expect(destination.host, 'pagespeed.web.dev');
          expect(destination.path, '/analysis');
          expect(destination.queryParameters['url'], target);
          expect(destination.queryParameters['form_factor'], 'mobile');
          expect(arguments['useWebView'], isFalse);
          expect(arguments['useSafariVC'], isFalse);
          expect(arguments['universalLinksOnly'], isFalse);
          expect(find.text('Run PageSpeed'), findsOneWidget);
          expect(networkClients, 0);
        },
        createHttpClient: (_) {
          networkClients++;
          throw StateError('PageSpeed must run in the external browser');
        },
      );
    },
  );

  testWidgets(
    'a browser launch failure offers the same copyable link at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      String? launched, copied;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_launcher, (call) async {
        launched = (call.arguments as Map)['url'] as String;
        return false;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      await tester.pumpWidget(_page('https://example.com/guide?a=1&b=2'));
      await revealByScrolling(tester, find.text('Run PageSpeed'));
      await tester.tap(find.text('Run PageSpeed'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not open your browser'),
        findsOneWidget,
      );
      await revealByScrolling(tester, find.text('Copy PageSpeed link'));
      await tester.tap(find.text('Copy PageSpeed link'));
      await tester.pumpAndSettle();
      expect(copied, launched);
      expect(find.text('PageSpeed link copied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late launch failures cannot affect a new page and samples stay offline',
    (tester) async {
      final pending = Completer<bool>();
      final targets = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _launcher,
        (call) async {
          final destination = Uri.parse(
            (call.arguments as Map)['url'] as String,
          );
          final target = destination.queryParameters['url']!;
          targets.add(target);
          if (target.endsWith('/old')) return pending.future;
          return true;
        },
      );
      await tester.pumpWidget(_page('https://example.com/old'));
      await tester.tap(find.text('Run PageSpeed'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(_page('https://example.com/new'));
      await tester.tap(find.text('Run PageSpeed'));
      await tester.pumpAndSettle();
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open your browser'), findsNothing);
      await tester.pumpWidget(
        _page('https://example.com/sample', enabled: false),
      );
      expect(find.text('Run PageSpeed'), findsNothing);
      expect(targets, ['https://example.com/old', 'https://example.com/new']);
      expect(tester.takeException(), isNull);
    },
  );
}
