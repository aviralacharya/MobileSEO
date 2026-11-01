import 'package:flutter/material.dart';

import '../services/audit_history_service.dart';
import '../services/audit_review.dart';
import '../utils/page_identity.dart';
import '../widgets/app_widgets.dart';

class AuditComparisonScreen extends StatelessWidget {
  const AuditComparisonScreen({
    super.key,
    required this.before,
    required this.after,
  });
  final AuditHistoryEntry before, after;

  @override
  Widget build(BuildContext context) {
    final comparison = AuditComparison(
      before: before.result,
      after: after.result,
    );
    final theme = Theme.of(context);
    final change = comparison.scoreChange;
    final previous = {
      for (final finding in reviewAudit(before.result)) finding.id: finding,
    };
    return Scaffold(
      appBar: AppBar(title: const BrandTitle(title: 'Before & after')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Same page. Measured progress.',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        after.result.url,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 32,
                        runSpacing: 16,
                        children: [
                          _SnapshotScore(label: 'Before', entry: before),
                          _SnapshotScore(label: 'After', entry: after),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${change > 0 ? '+' : ''}$change measured points',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: change < 0
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Changes are based on the HTML returned by each audit. Only a previously failing check that now passes is verified.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ComparisonCounts(comparison: comparison),
                const SizedBox(height: 16),
                _Changes(
                  title: 'Resolved · Verified by re-audit',
                  icon: Icons.verified_outlined,
                  findings: comparison.resolved,
                  previous: previous,
                  empty: 'No previously failing checks have passed yet.',
                ),
                const SizedBox(height: 16),
                _Changes(
                  title: 'New issues',
                  icon: Icons.new_releases_outlined,
                  findings: comparison.introduced,
                  previous: previous,
                  empty: 'No new issues detected.',
                ),
                const SizedBox(height: 16),
                _Changes(
                  title: 'Still needs attention',
                  icon: Icons.pending_actions_outlined,
                  findings: comparison.remaining,
                  previous: previous,
                  empty: 'No issues remain from the earlier audit.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ComparisonCounts extends StatelessWidget {
  const ComparisonCounts({super.key, required this.comparison});
  final AuditComparison comparison;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      Chip(
        avatar: const Icon(Icons.verified_outlined, size: 18),
        label: Text('${comparison.resolved.length} resolved'),
      ),
      Chip(
        avatar: const Icon(Icons.add_circle_outline, size: 18),
        label: Text('${comparison.introduced.length} new'),
      ),
      Chip(
        avatar: const Icon(Icons.pending_outlined, size: 18),
        label: Text('${comparison.remaining.length} remaining'),
      ),
    ],
  );
}

class _SnapshotScore extends StatelessWidget {
  const _SnapshotScore({required this.label, required this.entry});
  final String label;
  final AuditHistoryEntry entry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      Text(
        '${entry.result.score}/100',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      Text(
        formatAuditDate(entry.createdAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _Changes extends StatelessWidget {
  const _Changes({
    required this.title,
    required this.icon,
    required this.findings,
    required this.previous,
    required this.empty,
  });
  final String title, empty;
  final IconData icon;
  final List<AuditFinding> findings;
  final Map<String, AuditFinding> previous;
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (findings.isEmpty) Text(empty),
        for (final finding in findings) ...[
          ExpansionTile(
            key: PageStorageKey('comparison-${finding.id}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 16),
            title: Text(finding.title),
            subtitle: Text(
              finding.passed ? 'Now passing' : finding.severityLabel,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SelectableText(
                      previous[finding.id]?.evidence ?? 'Not recorded',
                      key: PageStorageKey('evidence-before-${finding.id}'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'After',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SelectableText(
                      finding.evidence,
                      key: PageStorageKey('evidence-after-${finding.id}'),
                    ),
                    if (!finding.passed) ...[
                      const SizedBox(height: 10),
                      Text(finding.recommendation),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
