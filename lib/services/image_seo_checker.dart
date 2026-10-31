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

/// Attributes and optimization signals collected for one image element.
class ImageAuditItem {
  const ImageAuditItem({
    required this.src,
    required this.alt,
    required this.loading,
    required this.width,
    required this.height,
    required this.format,
    required this.isModernFormat,
    required this.isLegacyFormat,
  });

  final String src;
  final String? alt;
  final String? loading;
  final String? width;
  final String? height;
  final String format;
  final bool isModernFormat;
  final bool isLegacyFormat;

  bool get hasAlt => alt != null && alt!.trim().isNotEmpty;
  bool get lazyLoaded => loading?.trim().toLowerCase() == 'lazy';
}

/// Result of scanning a document for image alt-text coverage.
class ImageSeoReport {
  const ImageSeoReport({
    required this.totalImages,
    required this.imagesMissingAlt,
    this.images = const [],
  });

  const ImageSeoReport.empty()
    : totalImages = 0,
      imagesMissingAlt = const [],
      images = const [];

  final int totalImages;
  final List<ImageIssue> imagesMissingAlt;
  final List<ImageAuditItem> images;

  /// Older saved audits may not include the detailed per-image fields.
  bool get hasImageDetails => images.length == totalImages;

  /// Number of images that are missing alt text.
  int get missingAltCount => imagesMissingAlt.length;

  /// Number of images that do have alt text.
  int get imagesWithAlt => totalImages - missingAltCount;
  int get missingLazyLoadingCount =>
      images.where((image) => !image.lazyLoaded).length;
  int get modernFormatCount =>
      images.where((image) => image.isModernFormat).length;
  int get legacyFormatCount =>
      images.where((image) => image.isLegacyFormat).length;

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
  final scanned = <ImageAuditItem>[];
  for (final image in images) {
    final alt = image.attributes['alt'];
    final src = _bestSource(image);
    final format = _imageFormat(src);
    final extension = format.toLowerCase();
    final modern = extension == 'webp' || extension == 'avif';
    final legacy = const {
      'png',
      'jpeg',
      'jpg',
      'gif',
      'bmp',
      'tif',
      'tiff',
    }.contains(extension);
    scanned.add(
      ImageAuditItem(
        src: src,
        alt: alt,
        loading: image.attributes['loading'],
        width: image.attributes['width'],
        height: image.attributes['height'],
        format: format,
        isModernFormat: modern,
        isLegacyFormat: legacy,
      ),
    );
    if (alt == null || alt.trim().isEmpty) {
      missing.add(ImageIssue(src: src, hasEmptyAlt: alt != null));
    }
  }

  return ImageSeoReport(
    totalImages: images.length,
    imagesMissingAlt: List.unmodifiable(missing),
    images: List.unmodifiable(scanned),
  );
}

String _imageFormat(String source) {
  final lowerSource = source.toLowerCase();
  if (RegExp(r'(?:fm|format)=avif(?:&|$)').hasMatch(lowerSource)) {
    return 'AVIF';
  }
  if (RegExp(r'(?:fm|format)=webp(?:&|$)').hasMatch(lowerSource)) {
    return 'WebP';
  }
  final path = Uri.tryParse(source)?.path ?? source.split('?').first;
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return 'Unknown';
  final extension = path.substring(dot + 1).toLowerCase();
  if (extension == 'svg') return 'SVG';
  if (extension == 'webp') return 'WebP';
  if (extension == 'avif') return 'AVIF';
  if (extension == 'jpg' || extension == 'jpeg') return 'JPEG';
  if (extension == 'png') return 'PNG';
  if (extension == 'gif') return 'GIF';
  if (extension == 'bmp') return 'BMP';
  if (extension == 'tif' || extension == 'tiff') return 'TIFF';
  return extension.toUpperCase();
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
