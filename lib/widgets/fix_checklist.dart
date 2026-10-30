import 'package:flutter/material.dart';

import '../services/seo_audit_service.dart';
import 'app_widgets.dart';

/// Interactive checklist of failing audit items.
///
/// Ticking an item does not change the audited page — it only tells the
/// caller "pretend this is fixed", so the score gauge can preview the gain.
class FixChecklist extends StatelessWidget {
  const FixChecklist({
    super.key,
    required this.fixes,
    required this.checked,
    required this.pointsPerFix,
    required this.onToggle,
    this.onReset,
  });

  /// Every failing check, in report order.
  final List<AuditCheck> fixes;

  /// Labels of the fixes the user has ticked off.
  final Set<String> checked;

  /// Points a single fix is worth on the current score.
  final int pointsPerFix;

  final ValueChanged<String> onToggle;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goodColor = StatusPalette.of(context, AuditStatus.good).color;

    if (fixes.isEmpty) {
      return MessageCard(
        icon: Icons.task_alt_rounded,
        title: 'Nothing to fix',
        message: 'Every check passed on this page. Keep an eye on it as the '
            'content changes.',
        tone: goodColor,
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.checklist_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Fix checklist',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _CountBadge(
                label: '${checked.length}/${fixes.length}',
                color: checked.isEmpty ? scheme.onSurfaceVariant : goodColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            checked.isEmpty
                ? 'Tick an issue to preview how your score improves.'
                : '${checked.length} of ${fixes.length} issues marked as fixed '
                    '— preview only, the live site is unchanged.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < fixes.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _FixTile(
              check: fixes[i],
              isChecked: checked.contains(fixes[i].label),
              points: pointsPerFix,
              onChanged: () => onToggle(fixes[i].label),
            ),
          ],
          if (checked.isNotEmpty && onReset != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Reset preview'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FixTile extends StatelessWidget {
  const _FixTile({
    required this.check,
    required this.isChecked,
    required this.points,
    required this.onChanged,
  });

  final AuditCheck check;
  final bool isChecked;
  final int points;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goodColor = StatusPalette.of(context, AuditStatus.good).color;
    final accent = isChecked ? goodColor : scheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: isChecked
            ? goodColor.withValues(alpha: 0.08)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: isChecked ? 0.45 : 0.7),
        ),
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: (_) => onChanged(),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.only(left: 4, right: 12, top: 2),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        activeColor: goodColor,
        title: Text(
          check.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            decoration: isChecked ? TextDecoration.lineThrough : null,
            decorationColor: scheme.onSurfaceVariant,
            color: isChecked ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            check.note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
        secondary: isChecked
            ? Icon(Icons.check_circle_rounded, color: goodColor, size: 20)
            : points > 0
                ? _CountBadge(label: '+$points pts', color: scheme.primary)
                : null,
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
