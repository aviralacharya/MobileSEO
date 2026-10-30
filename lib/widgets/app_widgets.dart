import 'package:flutter/material.dart';

import '../services/seo_audit_service.dart';

/// Rounded surface used for every block of content in the app.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small tinted square used behind an icon in card headers.
class IconBubble extends StatelessWidget {
  const IconBubble({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
    );
  }
}

/// Brand block used as the title of every screen's app bar.
class BrandTitle extends StatelessWidget {
  const BrandTitle({
    super.key,
    required this.title,
    this.subtitle = 'MobileSEO',
    this.icon = Icons.travel_explore_rounded,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Green "Good" / amber "Needs work" pill.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final AuditStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = StatusPalette.of(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(palette.icon, size: 14, color: palette.color),
          const SizedBox(width: 6),
          Text(
            palette.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact green Pass / red Fail pill.
class PassFailChip extends StatelessWidget {
  const PassFailChip({super.key, required this.passed});

  final bool passed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = passed
        ? StatusPalette.of(context, AuditStatus.good).color
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            passed ? 'Pass' : 'Fail',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Colour, icon and label for an [AuditStatus].
class StatusPalette {
  const StatusPalette(this.color, this.icon, this.label);

  final Color color;
  final IconData icon;
  final String label;

  static StatusPalette of(BuildContext context, AuditStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case AuditStatus.good:
        return StatusPalette(
          isDark ? const Color(0xFF7BD88F) : const Color(0xFF1B873F),
          Icons.check_circle_rounded,
          'Good',
        );
      case AuditStatus.warning:
        return StatusPalette(
          isDark ? const Color(0xFFFFC266) : const Color(0xFFB26A00),
          Icons.warning_amber_rounded,
          'Needs work',
        );
    }
  }
}

/// Centred, width-limited message used for empty and success states.
class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Optional accent colour; defaults to the primary colour.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = tone ?? scheme.primary;

    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}
