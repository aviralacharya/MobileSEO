import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/seo_audit_service.dart';

/// How healthy a 0–100 score is, and the colour it should use.
enum ScoreBand {
  excellent,
  good,
  needsWork,
  critical;

  static ScoreBand of(int score) {
    if (score >= 90) return ScoreBand.excellent;
    if (score >= 80) return ScoreBand.good;
    if (score >= 50) return ScoreBand.needsWork;
    return ScoreBand.critical;
  }

  String get label {
    switch (this) {
      case ScoreBand.excellent:
        return 'Excellent';
      case ScoreBand.good:
        return 'Good';
      case ScoreBand.needsWork:
        return 'Needs work';
      case ScoreBand.critical:
        return 'Critical';
    }
  }

  IconData get icon {
    switch (this) {
      case ScoreBand.excellent:
      case ScoreBand.good:
        return Icons.verified_rounded;
      case ScoreBand.needsWork:
        return Icons.warning_amber_rounded;
      case ScoreBand.critical:
        return Icons.error_outline_rounded;
    }
  }

  Color color(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case ScoreBand.excellent:
      case ScoreBand.good:
        return isDark ? const Color(0xFF7BD88F) : const Color(0xFF1B873F);
      case ScoreBand.needsWork:
        return isDark ? const Color(0xFFFFC266) : const Color(0xFFB26A00);
      case ScoreBand.critical:
        return Theme.of(context).colorScheme.error;
    }
  }
}

/// Animated 270° arc gauge that shows a 0–100 SEO health score.
///
/// The value is tweened, so passing a new [score] — for example after the
/// user ticks a fix in the checklist — animates both the arc and the number.
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({
    super.key,
    required this.score,
    this.size = 168,
    this.duration = const Duration(milliseconds: 650),
  });

  /// 0–100. Values outside the range are clamped.
  final int score;
  final double size;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final clamped = score.clamp(0, 100);

    return Semantics(
      label: 'SEO health score $clamped out of 100',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: clamped / 100),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final band = ScoreBand.of((value * 100).round());
            final color = band.color(context);

            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GaugePainter(
                      value: value,
                      color: color,
                      trackColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(value * 100).round()}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'OF 100',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final Color color;
  final Color trackColor;

  /// Arc starts bottom-left and sweeps 270° clockwise.
  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.078;
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(rect, _start, _sweep, false, track);
    if (value > 0) {
      canvas.drawArc(rect, _start, _sweep * value.clamp(0.0, 1.0), false,
          progress);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Hero card for the Overview tab: the gauge plus a short summary.
class ScoreSummaryCard extends StatelessWidget {
  const ScoreSummaryCard({
    super.key,
    required this.result,
    required this.score,
    required this.fixedCount,
  });

  final SeoAuditResult result;

  /// Score to display, i.e. the real score plus any previewed fixes.
  final int score;

  /// How many failing checks the user has ticked in the checklist.
  final int fixedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final band = ScoreBand.of(score);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(band.icon, size: 18, color: band.color(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SEO health',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (fixedCount > 0)
                _PreviewBadge(
                  label: '+${score - result.score} pts preview',
                  color: band.color(context),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ScoreGauge(score: score),
          const SizedBox(height: 12),
          Text(
            band.label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: band.color(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.passedCount} of ${result.checks.length} checks passed'
            '${fixedCount > 0 ? ' · $fixedCount marked as fixed' : ''}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _UrlLine(url: result.url),
        ],
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlLine extends StatelessWidget {
  const _UrlLine({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
