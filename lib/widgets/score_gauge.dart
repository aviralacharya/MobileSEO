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
/// A new measured score animates both the arc and the number.
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
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: clamped / 100),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : duration,
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
                  Padding(
                    padding: EdgeInsets.all(size * 0.2),
                    // Keeps the number readable inside the ring even at large
                    // accessibility text scales instead of overflowing.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
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
                    ),
                  ),
                ],
              );
            },
          ),
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
      canvas.drawArc(
        rect,
        _start,
        _sweep * value.clamp(0.0, 1.0),
        false,
        progress,
      );
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
    this.projectedScore,
    this.selectedCoreChecks = 0,
  });

  final SeoAuditResult result;

  final int? projectedScore;
  final int selectedCoreChecks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final band = ScoreBand.of(result.score);

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ScoreGauge(score: result.score, size: 104),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Measured SEO score',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      band.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: band.color(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.passedCount} of ${result.checks.length} core checks passed',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (projectedScore != null && selectedCoreChecks > 0) ...[
            const Divider(height: 28),
            Text(
              'Projected: $projectedScore/100',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'If $selectedCoreChecks selected core checks pass. Re-audit after publishing to measure the change.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Based on the returned HTML. Extended diagnostics are listed separately from the six-check score.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
