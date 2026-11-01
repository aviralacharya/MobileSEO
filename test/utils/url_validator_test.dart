import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_seo/utils/url_validator.dart';

void main() {
  group('valid input', () {
    test('adds https:// when the scheme is missing', () {
      final result = UrlValidator.validate('example.com');

      expect(result.isValid, isTrue);
      expect(result.message, isNull);
      expect(result.uri.toString(), 'https://example.com');
    });

    test('keeps scheme, port, path, query and fragment', () {
      final result = UrlValidator.validate(
        '  http://example.com:8080/blog?q=seo#top  ',
      );

      expect(result.uri.toString(), 'http://example.com:8080/blog?q=seo#top');
    });

    test('accepts host:port, localhost and IPv4 for development', () {
      expect(UrlValidator.validate('localhost:3000').isValid, isTrue);
      expect(UrlValidator.validate('127.0.0.1:8080').isValid, isTrue);
      expect(
        UrlValidator.validate('https://sub.example.co.uk').isValid,
        isTrue,
      );
    });
  });

  group('invalid input', () {
    test('rejects empty text', () {
      expect(
        UrlValidator.validate('   ').message,
        'Enter a website URL to audit.',
      );
    });

    test('rejects spaces', () {
      expect(
        UrlValidator.validate('not a url').message,
        'URLs cannot contain spaces.',
      );
    });

    test('rejects non-http schemes', () {
      expect(
        UrlValidator.validate('ftp://example.com').message,
        'Only http:// and https:// links can be audited.',
      );
      expect(UrlValidator.validate('javascript:alert(1)').isValid, isFalse);
    });

    test('rejects a bare word without a domain', () {
      expect(
        UrlValidator.validate('example').message,
        'Enter a full domain, like example.com.',
      );
      expect(
        UrlValidator.validate('example.c').message,
        'Enter a full domain, like example.com.',
      );
    });

    test('rejects malformed domains and bad IPs', () {
      expect(UrlValidator.validate('example..com').isValid, isFalse);
      expect(UrlValidator.validate('-example.com').isValid, isFalse);
      expect(UrlValidator.validate('999.1.1.1').isValid, isFalse);
    });
  });
}
