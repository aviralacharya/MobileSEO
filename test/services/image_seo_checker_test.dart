import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:mobile_seo/services/image_seo_checker.dart';

ImageSeoReport _check(String body) {
  return checkImageSeo(html_parser.parse('<html><body>$body</body></html>'));
}

void main() {
  test('counts images and lists the ones without alt text', () {
    final report = _check('''
      <img src="a.jpg" alt="A cat">
      <img src="b.jpg">
      <img src="c.jpg" alt="A dog">
      <img src="d.jpg" alt="   ">
    ''');

    expect(report.totalImages, 4);
    expect(report.missingAltCount, 2);
    expect(report.imagesWithAlt, 2);
    expect(report.coveragePercent, 50);
    expect(report.isHealthy, isFalse);
    expect(report.imagesMissingAlt.map((i) => i.src), ['b.jpg', 'd.jpg']);
    expect(report.summary, '2 out of 4 images missing alt text');
  });

  test('distinguishes a missing alt attribute from an empty one', () {
    final report = _check(
      '<img src="missing.jpg"><img src="empty.jpg" alt="">',
    );

    expect(report.missingAltCount, 2);
    expect(report.imagesMissingAlt[0].hasEmptyAlt, isFalse);
    expect(report.imagesMissingAlt[1].hasEmptyAlt, isTrue);
  });

  test('falls back to lazy-load attributes and srcset for the source', () {
    final report = _check('''
      <img data-src="lazy.jpg">
      <img data-lazy-src="lazier.jpg">
      <img data-original="original.jpg">
      <img srcset="small.jpg 1x, large.jpg 2x">
      <img data-srcset="responsive.jpg 480w, big.jpg 960w">
      <img>
    ''');

    expect(report.totalImages, 6);
    expect(report.missingAltCount, 6);
    expect(report.imagesMissingAlt.map((i) => i.src), [
      'lazy.jpg',
      'lazier.jpg',
      'original.jpg',
      'small.jpg',
      'responsive.jpg',
      '(no src)',
    ]);
  });

  test('reports a fully covered page as healthy', () {
    final report = _check(
      '<img src="a.jpg" alt="One"><img src="b.jpg" alt="Two">',
    );

    expect(report.missingAltCount, 0);
    expect(report.coveragePercent, 100);
    expect(report.isHealthy, isTrue);
    expect(report.summary, 'All 2 images have alt text');
  });

  test('treats a page without images as fully covered', () {
    final report = _check('<p>No pictures here</p>');

    expect(report.totalImages, 0);
    expect(report.missingAltCount, 0);
    expect(report.coveragePercent, 100);
    expect(report.isHealthy, isTrue);
    expect(report.summary, 'No images found on this page');
  });
}
