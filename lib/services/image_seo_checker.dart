import 'package:html/dom.dart' as dom;

/// One `<img>` that is missing usable alt text.
class ImageIssue {
  const ImageIssue({required this.src, required this.hasEmptyAlt});

  /// Best-known source (`src`, lazy-load attributes or first `srcset` entry).
  final String src;

  /// True when `alt=""` is present (often intentional/decorative),
  /// false when the attribute is missing entirely.
  final bool hasEmptyAlt;
}

/// Result of scanning a document for image alt-text coverage.
class ImageSeoReport {
  const ImageSeoReport({
    required this.totalImages,
    required this.imagesMissingAlt,
  });

  const ImageSeoReport.empty()
      : totalImages = 0,
        imagesMissingAlt = const [];

  final int totalImages;
  final List<ImageIssue> imagesMissingAlt;

  /// Number of images that are missing alt text.
  int get missingAltCount => imagesMissingAlt.length;

  /// Number of images that do have alt text.
  int get imagesWithAlt => totalImages - missingAltCount;

  /// 0–100, rounded. A page without images counts as fully covered.
  int get coveragePercent =>
      totalImages == 0 ? 100 : ((imagesWithAlt / totalImages) * 100).round();

  /// True when there is nothing to fix.
  bool get isHealthy => missingAltCount == 0;

  /// e.g. "2 out of 7 images missing alt text".
  String get summary {
    if (totalImages == 0) return 'No images found on this page';
    if (missingAltCount == 0) {
      return 'All $totalImages images have alt text';
    }
    return '$missingAltCount out of $totalImages images missing alt text';
  }
}

/// Extracts every `<img>` in [document], counts them and lists the ones
/// without alt text.
///
/// An image counts as missing alt text when the attribute is absent or blank
/// (`alt=""` or whitespace only).
ImageSeoReport checkImageSeo(dom.Document document) {
  final images = document.querySelectorAll('img');

  final missing = <ImageIssue>[];
  for (final image in images) {
    final alt = image.attributes['alt'];
    if (alt != null && alt.trim().isNotEmpty) continue;

    missing.add(
      ImageIssue(
        src: _bestSource(image),
        hasEmptyAlt: alt != null,
      ),
    );
  }

  return ImageSeoReport(
    totalImages: images.length,
    imagesMissingAlt: List.unmodifiable(missing),
  );
}

/// Handles lazy-loaded images that expose their URL via data attributes or
/// `srcset` instead of `src`.
String _bestSource(dom.Element image) {
  final attributes = image.attributes;
  final candidates = <String?>[
    attributes['src'],
    attributes['data-src'],
    attributes['data-lazy-src'],
    attributes['data-original'],
    _firstSrcset(attributes['srcset']),
    _firstSrcset(attributes['data-srcset']),
  ];

  for (final candidate in candidates) {
    if (candidate != null && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return '(no src)';
}

String? _firstSrcset(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  // "image.jpg 1x, image@2x.jpg 2x" -> "image.jpg"
  return value.split(',').first.trim().split(RegExp(r'\s+')).first;
}
