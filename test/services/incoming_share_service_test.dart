import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/services/incoming_share_service.dart';

import '../support/share_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'browser titles preserve complete URLs, ports, queries and fragments',
    () {
      const url =
          'https://example.com:8443/guide?q=seo%20tools&lang=ne#summary';
      for (final text in [url, 'A helpful page\n$url', 'Read this: <$url>']) {
        final pages = SharedPages.fromText(text);
        expect(pages.urls.map((uri) => uri.toString()), [url]);
        expect(pages.error, isNull);
      }
      expect(
        SharedPages.fromText('example.com/guide?a=1&b=2').urls.single
            .toString(),
        'https://example.com/guide?a=1&b=2',
      );
      expect(
        SharedPages.fromText('Title\nhttps://example.com/path?value=last.')
            .urls
            .single
            .toString(),
        'https://example.com/path?value=last.',
      );
    },
  );

  test(
    'shared prose, balanced URL punctuation and distinct links are handled',
    () {
      final pages = SharedPages.fromText(
        'Read (https://example.com/wiki/SEO_(guide)). '
        'Then https://example.com/page?a=1 and https://example.com/page?a=2. '
        'Again <https://example.com/page?a=1>',
      );
      expect(pages.urls.map((uri) => uri.toString()), [
        'https://example.com/wiki/SEO_(guide)',
        'https://example.com/page?a=1',
        'https://example.com/page?a=2',
      ]);
    },
  );

  test(
    'non-web text, nested schemes and oversized shares stay out of the form',
    () {
      for (final text in [
        '',
        'A title with no link',
        'mailto:person@example.com',
        'javascript:https://example.com',
        'file:///home/page.html',
        'content://example.com/path',
        'https://example.com/${'a' * 32768}',
      ]) {
        final pages = SharedPages.fromText(text);
        expect(
          pages.urls,
          isEmpty,
          reason: text.substring(0, text.length.clamp(0, 80)),
        );
        expect(pages.error, isNotNull);
      }
    },
  );

  test(
    'cold and warm shares are consumed once; intentional repeated shares work',
    () async {
      final inbox = ShareInbox(['Page title\nhttps://example.com/first']);
      final service = IncomingShareService();
      addTearDown(service.dispose);
      final received = <SharedPages>[];
      final first = Completer<void>(), second = Completer<void>();
      final subscription = service.shares.listen((pages) {
        received.add(pages);
        if (received.length == 1) first.complete();
        if (received.length == 2) second.complete();
      });
      addTearDown(subscription.cancel);
      await service.start();
      await first.future;
      await service.start();
      await notifyIncomingShare();
      expect(received, hasLength(1));
      await inbox.send('https://example.com/first');
      await second.future;
      expect(received, hasLength(2));
      expect(received.last.urls.single.path, '/first');
      expect(inbox.pending, isEmpty);
    },
  );

  test('a warm notification during the initial drain is not lost', () async {
    final initial = Completer<List<String>>();
    final requested = Completer<void>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var drains = 0;
    messenger.setMockMethodCallHandler(incomingShareChannel, (call) {
      drains++;
      if (drains == 1) {
        requested.complete();
        return initial.future;
      }
      return Future.value(['https://example.com/warm']);
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(incomingShareChannel, null),
    );
    final service = IncomingShareService();
    addTearDown(service.dispose);
    final paths = <String>[];
    final both = Completer<void>();
    final subscription = service.shares.listen((pages) {
      paths.add(pages.urls.single.path);
      if (paths.length == 2) both.complete();
    });
    addTearDown(subscription.cancel);
    final starting = service.start();
    await requested.future;
    await notifyIncomingShare();
    initial.complete(['https://example.com/cold']);
    await starting;
    await both.future;
    expect(drains, 2);
    expect(paths, ['/cold', '/warm']);
  });

  test(
    'disposing during a native response cannot deliver a late draft',
    () async {
      final response = Completer<List<String>>();
      final requested = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(incomingShareChannel, (_) {
        requested.complete();
        return response.future;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(incomingShareChannel, null),
      );
      final service = IncomingShareService();
      final received = <SharedPages>[];
      final subscription = service.shares.listen(received.add);
      addTearDown(subscription.cancel);
      final starting = service.start();
      await requested.future;
      service.dispose();
      response.complete(['https://example.com/late']);
      await starting;
      expect(received, isEmpty);
    },
  );
}
