import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/seo_audit_service.dart';
import '../theme/app_theme.dart';
import 'app_sheet.dart';
import 'fix_code_generator.dart';

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
    this.faviconUrl,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? faviconUrl;

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
          child: faviconUrl == null
              ? Image.asset(
                  'assets/branding/mobileseo_icon.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      Icon(icon, color: theme.colorScheme.primary),
                )
              : Image.network(
                  faviconUrl!,
                  width: 24,
                  height: 24,
                  errorBuilder: (_, _, _) =>
                      Icon(icon, color: theme.colorScheme.primary),
                ),
        ),
        const SizedBox(width: 12),
        // Flexible so long titles and large text scales ellipsize instead of
        // overflowing the app bar on narrow screens.
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
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
        color: palette.background,
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
        : StatusPalette.critical(context).color;
    final background = passed
        ? StatusPalette.of(context, AuditStatus.good).background
        : StatusPalette.critical(context).background;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
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
  const StatusPalette(this.color, this.background, this.icon, this.label);

  final Color color;
  final Color background;
  final IconData icon;
  final String label;

  static StatusPalette critical(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return StatusPalette(
      dark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239),
      dark ? const Color(0xFF4C1D2B) : const Color(0xFFFFE4E6),
      Icons.error_rounded,
      'Critical',
    );
  }

  static StatusPalette of(BuildContext context, AuditStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case AuditStatus.good:
        return StatusPalette(
          isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
          isDark ? const Color(0xFF163326) : const Color(0xFFDCFCE7),
          Icons.check_circle_rounded,
          'Good',
        );
      case AuditStatus.warning:
        return StatusPalette(
          isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
          isDark ? const Color(0xFF3D2B0B) : const Color(0xFFFEF3C7),
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
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Switch to light theme' : 'Switch to dark theme',
      onPressed: AppTheme.toggle,
      icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
    );
  }
}

class AuditLoadingExperience extends StatefulWidget {
  const AuditLoadingExperience({super.key});
  @override
  State<AuditLoadingExperience> createState() => _AuditLoadingExperienceState();
}

class _AuditLoadingExperienceState extends State<AuditLoadingExperience>
    with SingleTickerProviderStateMixin {
  static const _steps = [
    'Connecting to server & checking SSL...',
    'Parsing HTML DOM & Meta tags...',
    'Scanning internal & external links...',
    'Analyzing keyword density & calculating score...',
  ];
  late final AnimationController _shimmer;
  Timer? _ticker;
  int _step = 0;
  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _ticker = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (mounted) setState(() => _step = (_step + 1) % _steps.length);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previousChildren, ?currentChild],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, .2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Align(
                    key: ValueKey(_step),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _steps[_step],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          RepaintBoundary(
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBlock(animation: _shimmer, width: 150, height: 18),
                  const SizedBox(height: 14),
                  _ShimmerBlock(
                    animation: _shimmer,
                    width: double.infinity,
                    height: 12,
                  ),
                  const SizedBox(height: 8),
                  _ShimmerBlock(
                    animation: _shimmer,
                    width: double.infinity,
                    height: 12,
                  ),
                  const SizedBox(height: 8),
                  _ShimmerBlock(animation: _shimmer, width: 190, height: 12),
                  if (i == 0) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: _ShimmerBlock(
                        animation: _shimmer,
                        width: 124,
                        height: 124,
                        radius: 100,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.animation,
    required this.width,
    required this.height,
    this.radius = 8,
  });
  final Animation<double> animation;
  final double width, height, radius;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final x = animation.value * 2 - 1;
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(x - 0.8, 0),
            end: Alignment(x + 0.8, 0),
            colors: [
              scheme.surfaceContainerHighest.withValues(alpha: .55),
              scheme.surfaceContainerHighest,
              scheme.surfaceContainerHighest.withValues(alpha: .55),
            ],
          ),
        ),
      );
    },
  );
}

class AuditCardEntry extends StatefulWidget {
  const AuditCardEntry({
    super.key,
    required this.index,
    required this.title,
    required this.summary,
    required this.why,
    required this.steps,
    required this.child,
    this.fixType,
    this.pageUrl = '',
    this.existingTitle = '',
    this.existingDescription = '',
    this.existingImage = '',
    this.schemaTypes = const [],
    this.animateIn = false,
  });
  final String? fixType;
  final bool animateIn;
  final String pageUrl, existingTitle, existingDescription, existingImage;
  final List<String> schemaTypes;
  final int index;
  final String title, summary, why;
  final List<String> steps;
  final Widget child;
  @override
  State<AuditCardEntry> createState() => _AuditCardEntryState();
}

class _AuditCardEntryState extends State<AuditCardEntry> {
  bool _visible = false;
  Timer? _delay;
  @override
  void initState() {
    super.initState();
    if (!widget.animateIn) {
      _visible = true;
      return;
    }
    _delay = Timer(Duration(milliseconds: widget.index * 45), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  Future<void> _details() async {
    // Fire-and-forget: waiting for the haptic channel would delay (or, on
    // platforms without haptics, block) the sheet from opening.
    HapticFeedback.lightImpact();
    if (!mounted) return;

    var fixOpen = false;

    await AppSheet.show<void>(
      context: context,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .55,
        minChildSize: .35,
        maxChildSize: .94,
        snap: true,
        snapSizes: const [.55, .94],
        shouldCloseOnMinExtent: true,
        builder: (sheetContext, controller) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              28 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            children: [
              Text(
                widget.title,
                style: Theme.of(sheetContext).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                widget.summary,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              Text(
                'Why it matters',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(widget.why),
              const SizedBox(height: 18),
              Text(
                'How to improve it',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < widget.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text('${i + 1}. ${widget.steps[i]}'),
                ),
              if (widget.fixType != null) ...[
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setSheetState(() => fixOpen = !fixOpen);
                  },
                  icon: Icon(
                    fixOpen ? Icons.expand_less_rounded : Icons.code_rounded,
                  ),
                  label: Text(fixOpen ? 'Hide HTML Fix' : 'Generate HTML Fix'),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: fixOpen
                      ? Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: FixCodeGenerator(
                            type: widget.fixType!,
                            url: widget.pageUrl,
                            title: widget.existingTitle,
                            description: widget.existingDescription,
                            image: widget.existingImage,
                            schemaTypes: widget.schemaTypes,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final visible = _visible || reduceMotion;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 320);

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, .06),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: IgnorePointer(
          ignoring: !visible,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _details,
              borderRadius: BorderRadius.circular(20),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
