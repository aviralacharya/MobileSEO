import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/audit_controller.dart';
import '../services/app_settings.dart';
import '../services/seo_audit_service.dart';
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

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Avoids scheduling size animations when accessibility requests less motion.
class MotionAwareSize extends StatelessWidget {
  const MotionAwareSize({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: duration,
          curve: curve,
          alignment: alignment,
          child: child,
        );
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

/// Small, local artwork shared by the app's top bars.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key});

  static const image = AssetImage('assets/branding/mobileseo_logo.png');

  @override
  Widget build(BuildContext context) => Image(
    image: image,
    width: 32,
    height: 32,
    fit: BoxFit.contain,
    semanticLabel: 'MobileSEO logo',
    errorBuilder: (_, _, _) => Icon(
      Icons.travel_explore_rounded,
      size: 32,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

/// Compact branding that stays in the top bar, including while scrolling.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        const BrandLogo(),
        const SizedBox(width: 10),
        // The logo keeps its size while long titles and larger text ellipsize.
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
          Flexible(
            child: Text(
              palette.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.color,
                fontWeight: FontWeight.w600,
              ),
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
      onPressed: () async {
        try {
          await SettingsScope.of(context)
              .update(themeMode: dark ? ThemeMode.light : ThemeMode.dark);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not save the appearance preference.'),
              ),
            );
          }
        }
      },
      icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
    );
  }
}

class AuditLoadingExperience extends StatelessWidget {
  const AuditLoadingExperience({
    super.key,
    this.phase = AuditPhase.fetching,
    this.onCancel,
  });
  final AuditPhase phase;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final active = switch (phase) {
      AuditPhase.fetching => 0,
      AuditPhase.analyzing => 1,
      _ => 2,
    };
    const stages = [
      'Fetching the page',
      'Analyzing HTML & on-page checks',
      'Checking crawl & AI guidance files',
    ];
    return Semantics(
      liveRegion: true,
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              phase == AuditPhase.siteFiles
                  ? 'On-page results are ready'
                  : 'Audit in progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < stages.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: index < active
                          ? Icon(
                              Icons.check_circle_rounded,
                              size: 22,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : index == active &&
                                !MediaQuery.disableAnimationsOf(context)
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Icon(
                              index == active
                                  ? Icons.hourglass_top_rounded
                                  : Icons.circle_outlined,
                              size: 20,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        stages[index],
                        style: TextStyle(
                          fontWeight: index == active
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (onCancel != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel audit'),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
    this.showDetails = true,
  });
  final String? fixType;
  final bool animateIn;
  final bool showDetails;
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
  void didUpdateWidget(covariant AuditCardEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateIn && !oldWidget.animateIn) {
      _delay?.cancel();
      _visible = false;
      _delay = Timer(Duration(milliseconds: widget.index * 45), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  Future<void> _details() async {
    // Fire-and-forget: waiting for the haptic channel would delay (or, on
    // platforms without haptics, block) the sheet from opening.
    SettingsScope.of(context).feedback();
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
                    SettingsScope.of(context).feedback();
                    setSheetState(() => fixOpen = !fixOpen);
                  },
                  icon: Icon(
                    fixOpen ? Icons.expand_less_rounded : Icons.code_rounded,
                  ),
                  label: Text(fixOpen ? 'Hide HTML Fix' : 'Generate HTML Fix'),
                ),
                MotionAwareSize(
                  duration: const Duration(milliseconds: 280),
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
            child: !widget.showDetails
                ? widget.child
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: _details,
                        borderRadius: BorderRadius.circular(20),
                        child: widget.child,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _details,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                          label: const Text('View details'),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
