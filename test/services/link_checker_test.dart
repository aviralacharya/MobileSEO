import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:mobile_seo/services/link_checker.dart';

const _html = '''
<html><body>
  <a href="/about">About</a>
  <a href="https://example.com/contact">Contact</a>
  <a href="https://other.com/x">Other site</a>
  <a href="//cdn.other.com/y">CDN</a>
  <a href="https://third.com/z" rel="nofollow noopener">Third</a>
  <a href="#">Top</a>
  <a href="">Empty</a>
  <a href="javascript:void(0)">JS</a>
  <a href="mailto:hi@example.com">Mail</a>
  <a href="tel:+15551234">Phone</a>
</body></html>
''';

LinkAudit _audit(String html, {String page = 'https://example.com/blog/post'}) {
  return checkLinks(html_parser.parse(html), Uri.parse(page));
}

void main() {
  test('counts internal and external links separately', () {
    final audit = _audit(_html);

    expect(audit.internal, 2);
    expect(audit.external, 3);
    expect(audit.total, 5);
    expect(audit.externalHosts, ['cdn.other.com', 'other.com', 'third.com']);
  });

  test('counts placeholder and non-navigational hrefs', () {
    final audit = _audit(_html);

    // href="#", href="" and javascript: are followed by mailto: and tel:.
    expect(audit.emptyHrefs, 5);
    expect(audit.hasEmptyHrefs, isTrue);
  });

  test('detects nofollow links', () {
    final audit = _audit(_html);

    expect(audit.nofollow, 1);
  });

  test('reports an empty page as having no links', () {
    final audit = _audit('<html><body><p>No anchors here</p></body></html>');

    expect(audit.hasLinks, isFalse);
    expect(audit.total, 0);
    expect(audit.externalHosts, isEmpty);
  });

  test('resolves relative hrefs against the audited page', () {
    final audit = _audit(
      '<html><body><a href="https://example.com:443/one">One</a>'
      '<a href="/two">Two</a></body></html>',
    );

    expect(audit.internal, 2);
    expect(audit.external, 0);
  });
}
