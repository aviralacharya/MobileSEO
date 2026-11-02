import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/audit_review.dart';
import '../services/fix_guides.dart';
import '../services/seo_audit_service.dart';
import 'fix_code_generator.dart';

class FixGuideSection extends StatefulWidget {
  const FixGuideSection({
    super.key,
    required this.finding,
    required this.result,
  });

  final AuditFinding finding;
  final SeoAuditResult result;

  @override
  State<FixGuideSection> createState() => _FixGuideSectionState();
}

class _FixGuideSectionState extends State<FixGuideSection> {
  WebsitePlatform? _platform;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _platform ??= SettingsScope.of(context).websitePlatform;
  }

  Future<void> _choosePlatform(WebsitePlatform platform) async {
    FocusScope.of(context).unfocus();
    setState(() => _platform = platform);
    final settings = SettingsScope.of(context);
    settings.feedback();
    try {
      await settings.update(websitePlatform: platform);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The guide is available, but your platform preference could not be saved.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = _platform!;
    final guide = FixGuides.forFinding(widget.finding.id, platform);
    if (guide == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Fix guide', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('Where do you edit this website?'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final option in WebsitePlatform.values)
              ChoiceChip(
                label: Text(option.label),
                selected: option == platform,
                onSelected: (_) => _choosePlatform(option),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Your selection is remembered. Menu names can vary by theme or editor version.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Text(guide.location, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        for (var index = 0; index < guide.steps.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(24),
                  child: Text(
                    '${index + 1}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: SelectableText(guide.steps[index])),
              ],
            ),
          ),
        if (guide.note != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(guide.note!, style: theme.textTheme.bodySmall),
          ),
        if (widget.finding.fixType != null)
          Visibility(
            visible: platform == WebsitePlatform.html,
            maintainState: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: FixCodeGenerator(
                type: widget.finding.fixType!,
                url: widget.result.url,
                title: widget.result.title ?? '',
                description: widget.result.description ?? '',
                image: widget.result.openGraph.image ?? '',
                schemaTypes: widget.result.schemaTypes,
              ),
            ),
          ),
      ],
    );
  }
}
