import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/services/audit_history_service.dart';
import 'package:mobile_seo/services/audit_review.dart';
import 'package:mobile_seo/services/report_options.dart';
import 'package:mobile_seo/utils/page_identity.dart';

import '../support/test_fixtures.dart';

void main() {
  test(
    'page identities ignore fragments and host case but keep page boundaries',
    () {
      expect(
        samePage(' https://EXAMPLE.com#top ', 'https://example.com/'),
        isTrue,
      );
      for (final other in [
        'http://example.com/guide',
        'https://example.com:8443/guide',
        'https://example.com/Guide',
        'https://example.com/guide/',
        'https://example.com/guide?lang=en',
        'https://other.com/guide',
      ]) {
        expect(
          samePage('https://example.com/guide', other),
          isFalse,
          reason: other,
        );
        expect(
          () => AuditComparison(
            before: auditResult(),
            after: auditResult(url: other),
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test('only selected failing core checks increase a projection', () {
    final result = auditResult(html: incompleteHtml);
    final measured = result.score;
    expect(measured, 33);
    expect(
      projectedAuditScore(result, {
        'Mobile viewport',
        'Social sharing',
        'H1 heading',
        'unknown',
      }),
      measured,
    );
    expect(projectedAuditScore(result, {'Meta title', 'Mobile viewport'}), 50);
    expect(
      projectedAuditScore(result, reviewAudit(result).map((f) => f.id).toSet()),
      100,
    );
    expect(result.score, measured);
    expect(selectedCoreFixes(result, {'Meta title', 'H1 heading'}), 1);
  });

  test(
    'verification requires a failing-to-passing transition on a later audit',
    () {
      final before = auditResult(html: incompleteHtml);
      final after = auditResult(
        html: incompleteHtml
            .replaceFirst(
              'Short title',
              'A practical guide to a weekend in Kathmandu',
            )
            .replaceFirst('<h1>City guide</h1>', ''),
      );
      final comparison = AuditComparison(before: before, after: after);
      expect(comparison.resolved.map((f) => f.id), ['Meta title']);
      expect(comparison.introduced.map((f) => f.id), ['H1 heading']);
      expect(
        comparison.remaining.map((f) => f.id),
        contains('Meta description'),
      );
      expect(comparison.scoreChange, 0);
      final options = ReportOptions(
        inProgress: const {'Meta description', 'Meta title'},
        before: AuditHistoryEntry(
          id: 'old',
          createdAt: DateTime.utc(2026),
          result: before,
        ),
      );
      final findings = {for (final f in reviewAudit(after)) f.id: f};
      expect(options.workflow(findings['Meta title']!, comparison), 'Verified');
      expect(options.workflow(findings['H2 headings']!, comparison), 'Passed');
      expect(
        options.workflow(findings['Meta description']!, comparison),
        'In progress',
      );
      expect(options.workflow(findings['H1 heading']!, comparison), 'To do');
      expect(options.workflow(findings['Meta title']!, null), 'Passed');
    },
  );
}
