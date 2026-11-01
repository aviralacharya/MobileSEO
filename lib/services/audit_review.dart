import '../utils/page_identity.dart';
import 'seo_audit_service.dart';

enum FindingSeverity { critical, improvement, passed }

int selectedCoreFixes(SeoAuditResult result, Set<String> inProgress) =>
    reviewAudit(result)
        .where(
          (finding) =>
              finding.scored &&
              !finding.passed &&
              inProgress.contains(finding.id),
        )
        .length;

int projectedAuditScore(SeoAuditResult result, Set<String> inProgress) =>
    result.scoreWithFixes(selectedCoreFixes(result, inProgress));

class AuditFinding {
  const AuditFinding({
    required this.id,
    required this.title,
    required this.evidence,
    required this.recommendation,
    required this.severity,
    required this.category,
    required this.effort,
    this.fixType,
    this.scored = false,
  });

  final String id, title, evidence, recommendation, category, effort;
  final FindingSeverity severity;
  final String? fixType;
  final bool scored;
  bool get passed => severity == FindingSeverity.passed;
  String get severityLabel => switch (severity) {
    FindingSeverity.critical => 'Critical',
    FindingSeverity.improvement => 'Improvement',
    FindingSeverity.passed => 'Passed',
  };
}

/// One set of findings shared by the dashboard, comparisons and exports.
/// Extended diagnostics are explicit; they don't silently change the core score.
List<AuditFinding> reviewAudit(SeoAuditResult result) {
  final findings = <AuditFinding>[
    for (final check in result.checks)
      AuditFinding(
        id: check.label,
        title: check.label,
        evidence: check.value,
        recommendation: check.note,
        severity: check.status == AuditStatus.good
            ? FindingSeverity.passed
            : (check.label == 'Meta title' && result.title == null) ||
                  (check.label == 'H1 heading' && result.h1Count == 0)
            ? FindingSeverity.critical
            : FindingSeverity.improvement,
        category: switch (check.label) {
          'Meta title' || 'Meta description' => 'Metadata',
          'Schema markup' => 'Technical',
          _ => 'Content',
        },
        effort: switch (check.label) {
          'Schema markup' => '15–30 min',
          'Image SEO' => '10–30 min',
          _ => '5–15 min',
        },
        fixType: switch (check.label) {
          'Meta title' => 'title',
          'Meta description' => 'description',
          'Schema markup' => 'schema',
          _ => null,
        },
        scored: true,
      ),
  ];
  final directives = [
    result.indexation.robotsMeta ?? '',
    result.indexation.googlebotMeta ?? '',
  ].join(', ').toLowerCase().split(RegExp(r'[\s,;]+'));
  final noindex = directives.contains('noindex') || directives.contains('none');
  findings.add(
    AuditFinding(
      id: 'Indexing directives',
      title: 'Indexing directives',
      evidence: directives.where((value) => value.isNotEmpty).join(', ').isEmpty
          ? 'No restrictive HTML robots directive found.'
          : directives.where((value) => value.isNotEmpty).join(', '),
      recommendation: noindex
          ? 'Remove noindex only if this page should appear in search. Re-audit after publishing.'
          : 'Keep directives aligned with your intent. HTML directives alone do not confirm search-engine indexing.',
      severity: noindex ? FindingSeverity.critical : FindingSeverity.passed,
      category: 'Technical',
      effort: '5–15 min',
    ),
  );
  final mobile =
      result.indexation.viewport?.contains('width=device-width') ?? false;
  findings.add(
    AuditFinding(
      id: 'Mobile viewport',
      title: 'Mobile viewport',
      evidence: result.indexation.viewport ?? 'No viewport meta tag found.',
      recommendation: 'Use a device-width viewport and check the layout on a narrow screen.',
      severity: mobile ? FindingSeverity.passed : FindingSeverity.improvement,
      category: 'Technical',
      effort: '5–15 min',
      fixType: 'viewport',
    ),
  );
  findings.add(
    AuditFinding(
      id: 'Social sharing',
      title: 'Social sharing',
      evidence:
          '${result.openGraph.presentCount} of 3 core Open Graph tags present.',
      recommendation: 'Provide an accurate og:title, og:description and absolute og:image URL.',
      severity: result.openGraph.isComplete
          ? FindingSeverity.passed
          : FindingSeverity.improvement,
      category: 'Metadata',
      effort: '5–15 min',
      fixType: 'open_graph',
    ),
  );
  findings.sort((a, b) {
    final severity = a.severity.index.compareTo(b.severity.index);
    return severity == 0 ? a.title.compareTo(b.title) : severity;
  });
  return List.unmodifiable(findings);
}

class AuditComparison {
  AuditComparison({required this.before, required this.after}) {
    if (!samePage(before.url, after.url)) {
      throw ArgumentError('Audit comparisons require the same page URL.');
    }
    final old = {for (final item in reviewAudit(before)) item.id: item};
    final current = reviewAudit(after);
    resolved = List.unmodifiable(
      current.where((item) => item.passed && old[item.id]?.passed == false),
    );
    introduced = List.unmodifiable(
      current.where((item) => !item.passed && old[item.id]?.passed != false),
    );
    remaining = List.unmodifiable(
      current.where((item) => !item.passed && old[item.id]?.passed == false),
    );
  }

  final SeoAuditResult before, after;
  late final List<AuditFinding> resolved, introduced, remaining;
  int get scoreChange => after.score - before.score;
}
