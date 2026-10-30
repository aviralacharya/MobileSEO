import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:mobile_seo/services/open_graph_checker.dart';

OpenGraphReport _check(String head) {
  return checkOpenGraph(
    html_parser.parse('<html><head>$head</head><body></body></html>'),
  );
}

void main() {
  test('extracts all three tags and trims their values', () {
    final report = _check('''
      <meta property="og:title" content="  Example Site  ">
      <meta property="og:description" content="A page about SEO.">
      <meta property="og:image" content="https://example.com/preview.png">
    ''');

    expect(report.title, 'Example Site');
    expect(report.description, 'A page about SEO.');
    expect(report.image, 'https://example.com/preview.png');
    expect(report.presentCount, 3);
    expect(report.missingCount, 0);
    expect(report.isComplete, isTrue);
  });

  test('reports each missing tag individually', () {
    final report = _check('''
      <meta property="og:title" content="Example Site">
    ''');

    expect(report.title, 'Example Site');
    expect(report.description, isNull);
    expect(report.image, isNull);
    expect(report.presentCount, 1);
    expect(report.missingCount, 2);
    expect(report.isComplete, isFalse);

    final tags = report.tags;
    expect(tags.map((tag) => tag.property), [
      'og:title',
      'og:description',
      'og:image',
    ]);
    expect(tags.map((tag) => tag.isPresent), [isTrue, isFalse, isFalse]);
  });

  test('treats a blank content attribute as missing', () {
    final report = _check('''
      <meta property="og:title" content="   ">
      <meta property="og:description" content="">
      <meta property="og:image">
    ''');

    expect(report.presentCount, 0);
    expect(report.isComplete, isFalse);
    expect(report.tags.every((tag) => !tag.isPresent), isTrue);
  });

  test('accepts name= instead of property= and ignores case', () {
    final report = _check('''
      <meta name="og:title" content="Named title">
      <meta property="OG:Description" content="Upper-case property">
      <meta property="og:image" content="https://example.com/i.png">
    ''');

    expect(report.title, 'Named title');
    expect(report.description, 'Upper-case property');
    expect(report.presentCount, 3);
  });

  test('ignores unrelated meta tags and uses the first non-empty value', () {
    final report = _check('''
      <meta name="description" content="Regular meta description">
      <meta name="twitter:title" content="Twitter title">
      <meta property="og:title" content="">
      <meta property="og:title" content="First real title">
      <meta property="og:title" content="Second title">
    ''');

    expect(report.title, 'First real title');
    expect(report.description, isNull);
    expect(report.image, isNull);
    expect(report.isComplete, isFalse);
  });

  test('returns an empty report when there are no meta tags', () {
    final report = _check('');

    expect(report.title, isNull);
    expect(report.description, isNull);
    expect(report.image, isNull);
    expect(report.presentCount, 0);
    expect(report.missingCount, OpenGraphReport.tagCount);
    expect(report.isComplete, isFalse);
  });
}
