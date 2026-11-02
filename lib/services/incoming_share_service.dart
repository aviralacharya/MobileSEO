import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/url_validator.dart';

/// A share is a draft, never permission to start a network request.
class SharedPages {
  const SharedPages._(this.urls, this.error);

  final List<Uri> urls;
  final String? error;

  static final _links = RegExp(
    r'''https?://[^\s<>"\x00-\x1f]+''',
    caseSensitive: false,
  );

  factory SharedPages.fromText(String text) {
    if (text.length > 32768) {
      return const SharedPages._(
        [],
        'Share the page address instead of its full content, or paste a URL below.',
      );
    }
    final whole = UrlValidator.validate(text);
    if (whole.isValid) return SharedPages._([whole.uri!], null);

    final urls = <String, Uri>{};
    for (final match in _links.allMatches(text)) {
      // Do not extract an HTTP substring from another scheme or a word.
      if (match.start > 0 &&
          !RegExp(r'''[\s(\[{'"<]''').hasMatch(text[match.start - 1])) {
        continue;
      }
      var candidate = match.group(0)!;
      // Browser shares often include a title on a separate line. Preserve the
      // complete URL on such lines, including queries and trailing punctuation.
      final line = text
          .substring(text.lastIndexOf('\n', match.start - 1) + 1)
          .split('\n')
          .first
          .trim();
      if (line != candidate) {
        candidate = candidate.replaceFirst(RegExp(r'''[.,;!'”’]+$'''), '');
        for (final pair in [('(', ')'), ('[', ']'), ('{', '}')]) {
          while (candidate.endsWith(pair.$2) &&
              pair.$2.allMatches(candidate).length >
                  pair.$1.allMatches(candidate).length) {
            candidate = candidate.substring(0, candidate.length - 1);
          }
        }
      }
      final validation = UrlValidator.validate(candidate);
      if (validation.isValid) {
        final uri = validation.uri!;
        urls.putIfAbsent(uri.toString(), () => uri);
      }
    }
    return urls.isEmpty
        ? const SharedPages._(
            [],
            'No web page link was found. Share an http or https address, or paste a URL below.',
          )
        : SharedPages._(List.unmodifiable(urls.values), null);
  }
}

/// Drains the Android inbox on startup and on warm-share notifications.
/// Native code retains early shares until Dart is listening; a notification
/// during a drain schedules another pass rather than racing the first pass.
class IncomingShareService {
  IncomingShareService({
    this._channel = const MethodChannel('mobile_seo/incoming_share'),
  });

  final MethodChannel _channel;
  final _shares = StreamController<SharedPages>.broadcast();
  bool _started = false, _disposed = false;
  bool _draining = false, _drainAgain = false;

  Stream<SharedPages> get shares => _shares.stream;

  Future<void> start() async {
    if (_started ||
        _disposed ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shareAvailable') await _drain();
    });
    await _drain();
  }

  Future<void> _drain() async {
    if (_disposed) return;
    if (_draining) {
      _drainAgain = true;
      return;
    }
    _draining = true;
    try {
      do {
        _drainAgain = false;
        final texts = await _channel.invokeListMethod<String>(
          'takePendingShares',
        );
        if (_disposed) return;
        for (final text in texts ?? <String>[]) {
          _shares.add(SharedPages.fromText(text));
        }
      } while (_drainAgain && !_disposed);
    } on MissingPluginException {
      // Browser, desktop and older native hosts can still use the URL field.
    } on PlatformException {
      if (!_disposed) _shares.add(SharedPages.fromText(''));
    } finally {
      _draining = false;
    }
  }

  void dispose() {
    _disposed = true;
    if (_started) _channel.setMethodCallHandler(null);
    _shares.close().ignore();
  }
}
