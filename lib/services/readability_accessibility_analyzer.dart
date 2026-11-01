import 'package:html/dom.dart' as dom;

class AccessibilityIssue {
  const AccessibilityIssue({
    required this.category,
    required this.count,
    required this.description,
  });

  final String category;
  final int count;
  final String description;
}

class ReadabilityAccessibilityReport {
  const ReadabilityAccessibilityReport({
    this.sentenceCount = 0,
    this.wordCount = 0,
    this.syllableCount = 0,
    this.fleschScore = 0,
    this.readingLevel = 'Not enough text to score',
    this.gradeLevel = '—',
    this.issues = const [],
  });

  final int sentenceCount;
  final int wordCount;
  final int syllableCount;
  final double fleschScore;
  final String readingLevel;
  final String gradeLevel;
  final List<AccessibilityIssue> issues;

  int get accessibilityIssueCount =>
      issues.fold(0, (total, issue) => total + issue.count);

  factory ReadabilityAccessibilityReport.fromDocument(dom.Document document) {
    final body = document.body;
    var text = body?.text ?? '';
    if (body != null) {
      for (final node in body.querySelectorAll(
        'script,style,noscript,template',
      )) {
        if (node.text.isNotEmpty) text = text.replaceFirst(node.text, ' ');
      }
    }
    final words = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?")
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .toList(growable: false);
    final sentenceCount = RegExp(r'[.!?]+').allMatches(text).length;
    final syllables = words.fold<int>(0, (sum, word) => sum + _syllables(word));
    final hasEnoughText = words.isNotEmpty && sentenceCount > 0;
    final score = hasEnoughText
        ? (206.835 -
                  1.015 * words.length / sentenceCount -
                  84.6 * syllables / words.length)
              .clamp(-100.0, 120.0)
              .toDouble()
        : 0.0;

    final buttons = document.querySelectorAll('button').where((button) {
      final hasText = _hasMeaningfulText(button.text);
      final hasLabel = _hasMeaningfulText(button.attributes['aria-label']);
      return !hasText && !hasLabel;
    }).length;

    final inputs = document.querySelectorAll('input').where((input) {
      final type = (input.attributes['type'] ?? '').toLowerCase();
      if (type == 'hidden' ||
          type == 'submit' ||
          type == 'button' ||
          type == 'reset') {
        return false;
      }
      if (_hasMeaningfulText(input.attributes['aria-label'])) return false;
      final id = input.id.trim();
      final explicitlyLabelled =
          id.isNotEmpty &&
          document
              .querySelectorAll('label[for]')
              .any((label) => label.attributes['for'] == id);
      var ancestor = input.parent;
      var wrappedByLabel = false;
      while (ancestor != null) {
        if (ancestor.localName == 'label') {
          wrappedByLabel = true;
          break;
        }
        ancestor = ancestor.parent;
      }
      return !explicitlyLabelled && !wrappedByLabel;
    }).length;

    final genericAnchors = document.querySelectorAll('a[href]').where((link) {
      final imageAlt = link.querySelector('img')?.attributes['alt'] ?? '';
      final anchor =
          (link.attributes['aria-label'] ??
                  (link.text.trim().isNotEmpty ? link.text : imageAlt))
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ');
      return anchor.isEmpty ||
          const {
            'click here',
            'here',
            'read more',
            'learn more',
            'more',
            'click',
            'this link',
          }.contains(anchor);
    }).length;

    final issues = <AccessibilityIssue>[];
    if (buttons > 0) {
      issues.add(
        AccessibilityIssue(
          category: 'Unlabelled buttons',
          count: buttons,
          description: 'Add visible text or an aria-label to each button.',
        ),
      );
    }
    if (inputs > 0) {
      issues.add(
        AccessibilityIssue(
          category: 'Unlabelled inputs',
          count: inputs,
          description: 'Associate each input with a <label> or aria-label.',
        ),
      );
    }
    if (genericAnchors > 0) {
      issues.add(
        AccessibilityIssue(
          category: 'Empty or generic links',
          count: genericAnchors,
          description:
              'Use descriptive link text that explains its destination.',
        ),
      );
    }

    final level = _readingClassification(score, hasEnoughText);
    return ReadabilityAccessibilityReport(
      sentenceCount: sentenceCount,
      wordCount: words.length,
      syllableCount: syllables,
      fleschScore: score,
      readingLevel: level.$1,
      gradeLevel: level.$2,
      issues: List.unmodifiable(issues),
    );
  }

  static (String, String) _readingClassification(double score, bool enough) {
    if (!enough) return ('Not enough text to score', '—');
    if (score >= 90) return ('Very easy to read', '5th Grade');
    if (score >= 80) return ('Easy to read', '6th Grade');
    if (score >= 70) return ('Fairly easy to read', '7th Grade');
    if (score >= 60) return ('Standard', '8th–9th Grade');
    if (score >= 50) return ('Fairly difficult', '10th–12th Grade');
    if (score >= 30) return ('Difficult', 'College level');
    return ('Very difficult', 'College graduate level');
  }

  static bool _hasMeaningfulText(String? value) =>
      value != null && value.trim().isNotEmpty;

  static int _syllables(String word) {
    final cleaned = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (cleaned.isEmpty) return 0;
    final groups = RegExp(r'[aeiouy]+').allMatches(cleaned).length;
    var count = groups;
    if (cleaned.endsWith('e') && !cleaned.endsWith('le') && count > 1) {
      count--;
    }
    if (cleaned.endsWith('es') && count > 1 && !cleaned.endsWith('ses')) {
      count--;
    }
    return count < 1 ? 1 : count;
  }
}
