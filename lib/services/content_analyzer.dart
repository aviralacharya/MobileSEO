import 'package:html/dom.dart' as dom;

class KeywordMetric {
  const KeywordMetric(this.term, this.count, this.density);
  final String term;
  final int count;
  final double density;
}

class ContentMetrics {
  const ContentMetrics({
    required this.wordCount,
    required this.textToHtmlRatio,
    required this.keywords,
    required this.bigrams,
  });
  const ContentMetrics.empty()
    : wordCount = 0,
      textToHtmlRatio = 0,
      keywords = const [],
      bigrams = const [];
  final int wordCount;
  final double textToHtmlRatio;
  final List<KeywordMetric> keywords, bigrams;
  bool get isThinContent => wordCount < 300;

  factory ContentMetrics.fromDocument(dom.Document document) {
    final body = document.body;
    if (body == null) return const ContentMetrics.empty();
    var visible = body.text;
    for (final node in body.querySelectorAll(
      'script,style,noscript,template',
    )) {
      final text = node.text;
      if (text.isNotEmpty) visible = visible.replaceFirst(text, ' ');
    }
    final words = RegExp(
      r"[\p{L}\p{N}']+",
      unicode: true,
    ).allMatches(visible.toLowerCase()).map((m) => m.group(0)!).toList();
    final stop = {
      'the',
      'and',
      'is',
      'in',
      'to',
      'of',
      'a',
      'an',
      'for',
      'on',
      'with',
      'by',
      'at',
      'from',
      'as',
      'or',
      'it',
      'this',
      'that',
      'are',
      'be',
      'was',
      'were',
      'will',
      'you',
      'your',
      'we',
      'our',
      'i',
      'he',
      'she',
      'they',
      'them',
      'their',
      'not',
      'but',
      'if',
      'then',
      'than',
      'so',
      'do',
      'does',
      'did',
      'have',
      'has',
      'had',
      'can',
      'could',
      'would',
      'should',
      'about',
      'into',
      'over',
      'after',
      'before',
      'up',
      'out',
      'more',
      'most',
      'some',
      'any',
      'all',
      'each',
      'other',
      'such',
      'no',
      'yes',
      'very',
      'also',
    };
    final eligible = words.where((w) => !stop.contains(w)).toList();
    final singles = <String, int>{};
    for (final w in eligible) {
      singles[w] = (singles[w] ?? 0) + 1;
    }
    final pairs = <String, int>{};
    for (var i = 0; i < words.length - 1; i++) {
      final a = words[i], b = words[i + 1];
      if (!stop.contains(a) && !stop.contains(b)) {
        final k = '$a $b';
        pairs[k] = (pairs[k] ?? 0) + 1;
      }
    }
    List<KeywordMetric> top(Map<String, int> counts) =>
        (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .map(
              (e) => KeywordMetric(
                e.key,
                e.value,
                words.isEmpty ? 0 : e.value * 100 / words.length,
              ),
            )
            .toList(growable: false);
    final html = document.outerHtml;
    final double ratio = html.isEmpty
        ? 0.0
        : visible.trim().length * 100.0 / html.length;
    return ContentMetrics(
      wordCount: words.length,
      textToHtmlRatio: ratio,
      keywords: top(singles),
      bigrams: top(pairs),
    );
  }
}
