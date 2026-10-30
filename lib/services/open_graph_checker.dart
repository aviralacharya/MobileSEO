import 'package:html/dom.dart' as dom;

/// One Open Graph tag and the value found on the page.
class OpenGraphTag {
  const OpenGraphTag({required this.property, this.value});

  /// e.g. `og:title`.
  final String property;

  /// Trimmed `content` value, or `null` when the tag is missing or blank.
  final String? value;

  bool get isPresent => value != null;
}

/// Open Graph metadata used for social link previews.
class OpenGraphReport {
  const OpenGraphReport({this.title, this.description, this.image});

  const OpenGraphReport.empty()
      : title = null,
        description = null,
        image = null;

  final String? title;
  final String? description;
  final String? image;

  static const int tagCount = 3;

  /// Number of the three tags that are present with a non-blank value.
  int get presentCount =>
      [title, description, image].where((value) => value != null).length;

  int get missingCount => tagCount - presentCount;

  bool get isComplete => presentCount == tagCount;

  /// The three tags in display order, missing ones included.
  List<OpenGraphTag> get tags => List.unmodifiable([
        OpenGraphTag(property: 'og:title', value: title),
        OpenGraphTag(property: 'og:description', value: description),
        OpenGraphTag(property: 'og:image', value: image),
      ]);
}

/// Extracts `og:title`, `og:description` and `og:image` from [document].
///
/// Both `property` and `name` attributes are accepted (some sites use
/// `name="og:title"`), matching is case-insensitive, and a blank `content`
/// counts as missing. The first non-empty value wins if a tag is repeated.
OpenGraphReport checkOpenGraph(dom.Document document) {
  final values = <String, String>{};

  for (final meta in document.querySelectorAll('meta')) {
    final rawKey =
        meta.attributes['property'] ?? meta.attributes['name'] ?? '';
    final key = rawKey.trim().toLowerCase();
    if (!values.containsKey(key) && _tracked.contains(key)) {
      final content = meta.attributes['content']?.trim();
      if (content != null && content.isNotEmpty) {
        values[key] = content;
      }
    }
  }

  return OpenGraphReport(
    title: values['og:title'],
    description: values['og:description'],
    image: values['og:image'],
  );
}

const Set<String> _tracked = {'og:title', 'og:description', 'og:image'};
