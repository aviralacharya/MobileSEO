import 'package:flutter/material.dart';

import '../services/audit_review.dart';
import '../services/seo_audit_service.dart';
import 'app_sheet.dart';
import 'app_widgets.dart';
import 'fix_code_generator.dart';

class FindingBadge extends StatelessWidget {
  const FindingBadge({super.key, required this.finding});
  final AuditFinding finding;
  @override
  Widget build(BuildContext context) {
    final palette = finding.severity == FindingSeverity.critical
        ? StatusPalette.critical(context)
        : StatusPalette.of(
            context,
            finding.passed ? AuditStatus.good : AuditStatus.warning,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(palette.icon, size: 14, color: palette.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              finding.severityLabel,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showFindingDetails(
  BuildContext context,
  AuditFinding finding,
  SeoAuditResult result,
) => AppSheet.show<void>(
  context: context,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .72,
    minChildSize: .4,
    maxChildSize: .94,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        Text(finding.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FindingBadge(finding: finding),
            Text('${finding.category} · ${finding.effort} estimated'),
          ],
        ),
        const SizedBox(height: 20),
        Text('Evidence', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        SelectableText(finding.evidence),
        const SizedBox(height: 10),
        SelectableText(
          result.url,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Text(
          'How to improve it',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(finding.recommendation),
        const SizedBox(height: 12),
        Text(
          finding.scored
              ? 'This is one of the six core score checks.'
              : 'This extended diagnostic does not change the core score.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Make changes on your website, publish, and re-audit this page to verify the result.',
        ),
        if (!finding.passed && finding.fixType != null) ...[
          const SizedBox(height: 24),
          FixCodeGenerator(
            type: finding.fixType!,
            url: result.url,
            title: result.title ?? '',
            description: result.description ?? '',
            image: result.openGraph.image ?? '',
            schemaTypes: result.schemaTypes,
          ),
        ],
      ],
    ),
  ),
);

class FindingCounts extends StatelessWidget {
  const FindingCounts({super.key, required this.findings});
  final List<AuditFinding> findings;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final severity in FindingSeverity.values)
        Chip(
          avatar: Icon(switch (severity) {
            FindingSeverity.critical => Icons.error_outline_rounded,
            FindingSeverity.improvement => Icons.tips_and_updates_outlined,
            FindingSeverity.passed => Icons.check_circle_outline_rounded,
          }, size: 18),
          label: Text(
            '${findings.where((finding) => finding.severity == severity).length} ${switch (severity) {
              FindingSeverity.critical => 'critical',
              FindingSeverity.improvement => 'improvements',
              FindingSeverity.passed => 'passed',
            }}',
          ),
        ),
    ],
  );
}

class TopRecommendations extends StatelessWidget {
  const TopRecommendations({super.key, required this.result});
  final SeoAuditResult result;
  @override
  Widget build(BuildContext context) {
    final findings = reviewAudit(result)
        .where((finding) => !finding.passed)
        .take(3)
        .toList();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your next best fixes',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            findings.isEmpty
                ? 'All reviewed checks are passing. Keep monitoring as your page changes.'
                : 'Start with these ${findings.length} recommendations.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (var index = 0; index < findings.length; index++) ...[
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 15,
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        findings[index].title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        findings[index].evidence,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FindingBadge(finding: findings[index]),
                          Text(
                            findings[index].effort,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => showFindingDetails(
                          context,
                          findings[index],
                          result,
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('View fix'),
                      ),
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
}

/// Tracking a task never modifies a measured score or verifies a finding.
class FixChecklist extends StatefulWidget {
  const FixChecklist({
    super.key,
    required this.result,
    required this.inProgress,
    required this.verified,
    required this.onToggle,
    this.onReset,
    this.onReaudit,
    this.readOnly = false,
  });
  final SeoAuditResult result;
  final Set<String> inProgress, verified;
  final ValueChanged<String> onToggle;
  final VoidCallback? onReset, onReaudit;
  final bool readOnly;
  @override
  State<FixChecklist> createState() => _FixChecklistState();
}

class _FixChecklistState extends State<FixChecklist> {
  String _filter = 'Open';

  String _status(AuditFinding finding) => finding.passed
      ? widget.verified.contains(finding.id)
            ? 'Verified'
            : 'Passed'
      : widget.inProgress.contains(finding.id)
      ? 'In progress'
      : 'To do';

  @override
  Widget build(BuildContext context) {
    final findings = reviewAudit(widget.result);
    final filtered = findings
        .where(
          (finding) =>
              _filter == 'Open' ? !finding.passed : _status(finding) == _filter,
        )
        .toList();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Fix checklist',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            widget.readOnly
                ? 'Historical snapshot. Re-audit to track fixes against current results.'
                : 'To do, In progress, then Verified by a later audit.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final filter in [
                'Open',
                'To do',
                'In progress',
                'Verified',
                'Passed',
              ])
                ChoiceChip(
                  label: Text(
                    '$filter (${findings.where((finding) => filter == 'Open' ? !finding.passed : _status(finding) == filter).length})',
                  ),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                _filter == 'Verified'
                    ? 'A re-audit verifies fixes when previously failing checks pass.'
                    : 'No checks in this view.',
              ),
            ),
          for (final finding in filtered) ...[
            const Divider(height: 20),
            Text(finding.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FindingBadge(finding: finding),
                Text(
                  _status(finding),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              finding.evidence,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      showFindingDetails(context, finding, widget.result),
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('Evidence & fix'),
                ),
                if (!finding.passed && !widget.readOnly)
                  TextButton.icon(
                    onPressed: () => widget.onToggle(finding.id),
                    icon: Icon(
                      widget.inProgress.contains(finding.id)
                          ? Icons.undo_rounded
                          : Icons.playlist_add_check_rounded,
                      size: 18,
                    ),
                    label: Text(
                      widget.inProgress.contains(finding.id)
                          ? 'Move to To do'
                          : 'Start fix',
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (widget.onReaudit != null)
                FilledButton.tonalIcon(
                  onPressed: widget.onReaudit,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Re-audit to verify'),
                ),
              if (!widget.readOnly &&
                  widget.inProgress.isNotEmpty &&
                  widget.onReset != null)
                TextButton(
                  onPressed: widget.onReset,
                  child: const Text('Reset in-progress'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
