/// Result of validating the URL text a user typed.
class UrlValidationResult {
  const UrlValidationResult.valid(this.uri) : message = null;
  const UrlValidationResult.invalid(this.message) : uri = null;

  /// Absolute, normalised URL when valid.
  final Uri? uri;

  /// User-facing explanation when invalid.
  final String? message;

  bool get isValid => uri != null;
}

/// Validates and normalises user-entered URLs without touching the network.
///
/// Accepts `example.com` (adds `https://`), full `http(s)://` URLs, `localhost`
/// and IPv4 hosts. Rejects empty input, spaces, other schemes and bare words.
class UrlValidator {
  UrlValidator._();

  static final RegExp _schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:');
  static final RegExp _hostWithPortPattern =
      RegExp(r'^[a-zA-Z0-9.\-]+:\d{1,5}(?:[/?#]|$)');
  static final RegExp _domainPattern =
      RegExp(r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$');
  static final RegExp _ipv4Pattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  static UrlValidationResult validate(String input) {
    final text = input.trim();

    if (text.isEmpty) {
      return const UrlValidationResult.invalid(
        'Enter a website URL to audit.',
      );
    }
    if (RegExp(r'\s').hasMatch(text)) {
      return const UrlValidationResult.invalid(
        'URLs cannot contain spaces.',
      );
    }

    // "localhost:3000" looks like a scheme but is a host + port, so only
    // treat the prefix as a scheme when it is not host:port shaped.
    final hasExplicitScheme = _schemePattern.hasMatch(text) &&
        !_hostWithPortPattern.hasMatch(text);
    final candidate = hasExplicitScheme ? text : 'https://$text';
    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      return const UrlValidationResult.invalid(
        'That does not look like a valid URL.',
      );
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return const UrlValidationResult.invalid(
        'Only http:// and https:// links can be audited.',
      );
    }
    if (uri.host.isEmpty) {
      return const UrlValidationResult.invalid(
        'That does not look like a valid URL.',
      );
    }
    if (!_isValidHost(uri.host)) {
      return const UrlValidationResult.invalid(
        'Enter a full domain, like example.com.',
      );
    }

    return UrlValidationResult.valid(uri);
  }

  static bool _isValidHost(String host) {
    final value = host.toLowerCase();
    if (value == 'localhost') return true;

    if (_ipv4Pattern.hasMatch(value)) {
      return value.split('.').every((part) {
        final octet = int.tryParse(part);
        return octet != null && octet >= 0 && octet <= 255;
      });
    }

    return _domainPattern.hasMatch(value);
  }
}
