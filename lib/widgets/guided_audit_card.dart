import 'package:flutter/material.dart';

import '../services/audit_review.dart';
import '../services/fix_guides.dart';
import '../services/seo_audit_service.dart';
import 'app_widgets.dart';

class FirstAuditCard extends StatelessWidget {
  const FirstAuditCard({super.key, this.onSample, this.onDismiss});
  final VoidCallback? onSample, onDismiss;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuideHeading(title: 'Your first audit', onDismiss: onDismiss),
        const SizedBox(height: 8),
        Text(
          'Ready when you are',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Check one page, follow a practical fix, and verify what changed.',
        ),
        const SizedBox(height: 16),
        const _GuideSteps(step: 0),
        const SizedBox(height: 16),
        const Text(
          'Start with a public page URL above. The audit checks its returned HTML and explains what to improve next.',
        ),
        if (onSample != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onSample,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Explore sample audit'),
          ),
          const SizedBox(height: 6),
          Text(
            'No website needed for the offline sample.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}

class GuidedAuditCard extends StatelessWidget {
  const GuidedAuditCard({
    super.key,
    required this.result,
    required this.isSample,
    required this.onOpenFinding,
    required this.onUseOwnPage,
    this.reviewedFindingId,
    this.comparison,
    this.onReaudit,
    this.onSaveProject,
    this.onDismiss,
    this.busy = false,
  });

  final SeoAuditResult result;
  final bool isSample, busy;
  final String? reviewedFindingId;
  final AuditComparison? comparison;
  final ValueChanged<AuditFinding> onOpenFinding;
  final VoidCallback onUseOwnPage;
  final VoidCallback? onReaudit, onSaveProject, onDismiss;

  @override
  Widget build(BuildContext context) {
    final findings = reviewAudit(result);
    final open = findings.where(
      (finding) => !finding.passed && FixGuides.supports(finding.id),
    );
    final reviewed = open
        .where((finding) => finding.id == reviewedFindingId)
        .firstOrNull;
    final next = reviewed ?? open.firstOrNull;
    final verified = isSample
        ? null
        : comparison?.resolved
              .where(
                (finding) =>
                    reviewedFindingId == null ||
                    finding.id == reviewedFindingId,
              )
              .firstOrNull;
    final title = verified != null
        ? 'A real improvement, verified'
        : next == null
        ? 'You have a useful baseline'
        : reviewed == null
        ? 'Turn this result into a next step'
        : isSample
        ? 'Try this workflow on your own page'
        : 'Publish your change, then recheck';
    final detail = verified != null
        ? '${verified.title} failed in the earlier audit and passes in this one. Your comparison records the evidence.'
        : next == null
        ? 'All reviewed checks are passing. Keep this baseline and recheck after your next website update.'
        : reviewed == null
        ? 'Start with ${next.title.toLowerCase()}. Open its evidence and choose WordPress, Shopify or HTML instructions.'
        : isSample
        ? 'You opened the ${reviewed.title.toLowerCase()} guide. Sample results are fixed examples; audit your own URL to verify a published change.'
        : 'Follow the ${reviewed.title.toLowerCase()} guide on your website. Rechecking is what confirms the fix; opening a guide does not change your measured score.';
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GuideHeading(
            title: isSample ? 'Practice your first audit' : 'Your next step',
            onDismiss: onDismiss,
          ),
          const SizedBox(height: 10),
          _GuideSteps(
            step: verified != null
                ? 3
                : reviewed != null
                ? 2
                : 1,
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(detail),
          if (reviewed == null && verified == null) ...[
            const SizedBox(height: 8),
            Text(
              'The score covers six on-page checks. Additional findings are separate; it is not a search-ranking prediction.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          if (verified != null)
            FilledButton.tonalIcon(
              onPressed: onDismiss,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Finish guide'),
            )
          else if (next != null && reviewed == null)
            FilledButton.tonalIcon(
              onPressed: () => onOpenFinding(next),
              icon: const Icon(Icons.route_outlined),
              label: const Text('Walk me through a fix'),
            )
          else if (isSample)
            FilledButton.tonalIcon(
              onPressed: onUseOwnPage,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Try your own page'),
            )
          else if (next != null && onReaudit != null)
            FilledButton.tonalIcon(
              onPressed: busy ? null : onReaudit,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Recheck this page'),
            )
          else if (onSaveProject != null)
            OutlinedButton.icon(
              onPressed: onSaveProject,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Keep this page in Projects'),
            ),
          if (reviewed != null && verified == null)
            TextButton(
              onPressed: () => onOpenFinding(reviewed),
              child: const Text('Read the fix guide again'),
            ),
        ],
      ),
    );
  }
}

class _GuideHeading extends StatelessWidget {
  const _GuideHeading({required this.title, this.onDismiss});
  final String title;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.explore_outlined,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.labelLarge),
      ),
      IconButton(
        tooltip: 'Hide audit guide',
        onPressed: onDismiss,
        icon: const Icon(Icons.close_rounded, size: 20),
      ),
    ],
  );
}

class _GuideSteps extends StatelessWidget {
  const _GuideSteps({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['Check a page', 'Open a fix guide', 'Recheck'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < labels.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: index <= step
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}. ${labels[index]}',
              semanticsLabel:
                  '${labels[index]}, ${index < step
                      ? 'complete'
                      : index == step
                      ? 'next step'
                      : 'later'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: index <= step
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: index == step ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }
}
