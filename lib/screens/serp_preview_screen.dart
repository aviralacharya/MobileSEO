import 'package:flutter/material.dart';

import '../services/seo_audit_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/audit_cards.dart';

/// Tab 2 of the shell: how the page looks in Google and on social networks.
class SerpPreviewScreen extends StatelessWidget {
  const SerpPreviewScreen({
    super.key,
    required this.result,
    required this.onGoToAudit,
  });

  final SeoAuditResult? result;
  final VoidCallback onGoToAudit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: const BrandTitle(
          title: 'SERP & Social Previews',
          icon: Icons.search_rounded,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: result == null
                  ? MessageCard(
                      icon: Icons.preview_outlined,
                      title: 'Run an audit first',
                      message: 'Previews are built from the title, meta '
                          'description and Open Graph tags of an audited page.',
                      action: FilledButton.icon(
                        onPressed: onGoToAudit,
                        icon: const Icon(Icons.insights_rounded, size: 18),
                        label: const Text('Go to Audit Dashboard'),
                      ),
                    )
                  : _Previews(result: result!),
            ),
          ),
        ),
      ),
    );
  }
}

class _Previews extends StatelessWidget {
  const _Previews({required this.result});

  final SeoAuditResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SerpPreviewCard(result: result),
        const SizedBox(height: 16),
        _SocialPreviewCard(result: result),
        const SizedBox(height: 16),
        OpenGraphCard(report: result.openGraph),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Google result preview
// -----------------------------------------------------------------------------

class _SerpPreviewCard extends StatelessWidget {
  const _SerpPreviewCard({required this.result});

  final SeoAuditResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final title = result.title;
    final description = result.description;
    final titleGood = title != null && title.length >= 30 && title.length <= 60;
    final descriptionGood =
        description != null && description.length >= 70 &&
            description.length <= 160;

    final linkColor =
        isDark ? const Color(0xFF8AB4F8) : const Color(0xFF1A0DAB);
    final uri = Uri.tryParse(result.url);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.manage_search_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Google result preview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusChip(
                status: titleGood && descriptionGood
                    ? AuditStatus.good
                    : AuditStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'An approximation of the snippet — Google still rewrites titles '
            'and descriptions when it thinks it can do better.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.public_rounded,
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            uri?.host ?? result.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? const Color(0xFFDADCE0)
                                  : const Color(0xFF202124),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _breadcrumb(uri),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark
                                  ? const Color(0xFF9AA0A6)
                                  : const Color(0xFF4D5156),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title ?? 'No title tag — Google will invent one',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: title == null
                        ? scheme.onSurfaceVariant
                        : linkColor,
                    fontStyle: title == null ? FontStyle.italic : null,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description ??
                      'No meta description — Google will pull a snippet from '
                          'the page body.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? const Color(0xFFB4B8BD)
                        : const Color(0xFF4D5156),
                    fontStyle:
                        description == null ? FontStyle.italic : null,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _LengthRow(
            label: 'Title',
            length: title?.length,
            min: 30,
            max: 60,
          ),
          const SizedBox(height: 8),
          _LengthRow(
            label: 'Description',
            length: description?.length,
            min: 70,
            max: 160,
          ),
        ],
      ),
    );
  }

  static String _breadcrumb(Uri? uri) {
    if (uri == null) return '/';
    final path = uri.path.isEmpty ? '/' : uri.path;
    return path.length > 1 ? path : '/';
  }
}

class _LengthRow extends StatelessWidget {
  const _LengthRow({
    required this.label,
    required this.length,
    required this.min,
    required this.max,
  });

  final String label;
  final int? length;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final value = length;
    final inRange = value != null && value >= min && value <= max;
    final color = value == null
        ? scheme.error
        : inRange
            ? StatusPalette.of(context, AuditStatus.good).color
            : scheme.error;

    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value == null
                  ? 0
                  : (value / max).clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value == null ? 'missing' : '$value / $max',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Social share preview
// -----------------------------------------------------------------------------

class _SocialPreviewCard extends StatelessWidget {
  const _SocialPreviewCard({required this.result});

  final SeoAuditResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final report = result.openGraph;
    final image = _resolveImage(report.image, result.url);
    final host = Uri.tryParse(result.url)?.host ?? result.url;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.image_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Social share card',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusChip(
                status: report.isComplete
                    ? AuditStatus.good
                    : AuditStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Built from your Open Graph tags. X, LinkedIn and WhatsApp fall '
            'back to these values.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1.91,
                    child: image == null
                        ? _MissingImage(theme: theme)
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                _MissingImage(theme: theme, failed: true),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: progress.expectedTotalBytes == null
                                        ? null
                                        : progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          host.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.title ?? result.title ?? 'No social title',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontStyle: report.title == null
                                ? FontStyle.italic
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.description ??
                              result.description ??
                              'No social description',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontStyle: report.description == null
                                ? FontStyle.italic
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            image == null
                ? 'Add og:image so the link shows a thumbnail instead of a '
                    'blank card.'
                : 'Image: $image',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: image == null ? FontStyle.italic : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves a possibly relative `og:image` against the audited page.
  static String? _resolveImage(String? raw, String pageUrl) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = Uri.tryParse(raw.trim());
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed.toString();
    final base = Uri.tryParse(pageUrl);
    if (base == null) return null;
    return base.resolveUri(parsed).toString();
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage({required this.theme, this.failed = false});

  final ThemeData theme;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.broken_image_outlined : Icons.image_outlined,
            size: 28,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            failed ? 'og:image could not be loaded' : 'No og:image',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
