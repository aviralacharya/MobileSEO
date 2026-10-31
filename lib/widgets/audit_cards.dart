import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/content_analyzer.dart';
import '../services/image_seo_checker.dart';
import '../services/indexation_checker.dart';
import '../services/link_checker.dart';
import '../services/open_graph_checker.dart';
import '../services/seo_audit_service.dart';
import '../services/site_files_checker.dart';
import '../services/security_report.dart';
import '../services/readability_accessibility_analyzer.dart';
import '../services/pagespeed_insights_service.dart';
import 'app_widgets.dart';

class MetaCard extends StatelessWidget {
  const MetaCard({super.key, required this.check, required this.icon});

  final AuditCheck check;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  check.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusChip(status: check.status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            check.value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            check.note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class HeadingsCard extends StatelessWidget {
  const HeadingsCard({super.key, required this.result});

  final SeoAuditResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h1Good = result.h1Count == 1;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.format_size_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Headings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusChip(
                status: h1Good ? AuditStatus.good : AuditStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HeadingRow(
            tag: 'H1',
            count: result.h1Count,
            caption: 'Primary heading',
            status: h1Good ? AuditStatus.good : AuditStatus.warning,
          ),
          const SizedBox(height: 10),
          _HeadingRow(
            tag: 'H2',
            count: result.h2Count,
            caption: 'Section headings',
            status: result.h2Count > 0 ? AuditStatus.good : AuditStatus.warning,
          ),
          const SizedBox(height: 10),
          _HeadingRow(
            tag: 'H3',
            count: result.h3Count,
            caption: 'Sub-section headings',
            status: result.h3Count > 0 ? AuditStatus.good : AuditStatus.warning,
          ),
        ],
      ),
    );
  }
}

class _HeadingRow extends StatelessWidget {
  const _HeadingRow({
    required this.tag,
    required this.count,
    required this.caption,
    required this.status,
  });

  final String tag;
  final int count;
  final String caption;
  final AuditStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = StatusPalette.of(context, status);

    return Row(
      children: [
        Container(
          width: 46,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            tag,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                count == 0 ? 'None found' : '$count on the page',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: palette.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelLarge?.copyWith(
              color: palette.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class ImagesCard extends StatelessWidget {
  const ImagesCard({super.key, required this.report});

  final ImageSeoReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status =
        report.isHealthy &&
            (!report.hasImageDetails || report.missingLazyLoadingCount == 0)
        ? AuditStatus.good
        : AuditStatus.warning;
    final palette = StatusPalette.of(context, status);

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
                  'Image SEO',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            report.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            report.hasImageDetails
                ? '${report.missingLazyLoadingCount} missing lazy loading · '
                      '${report.modernFormatCount} modern formats · '
                      '${report.legacyFormatCount} legacy raster formats'
                : 'Detailed loading and format data is unavailable for this older saved audit.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: report.coveragePercent / 100,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(palette.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.coveragePercent}% of images have alt text',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text('Scanned images (${report.images.length})'),
            subtitle: const Text(
              'Source, alt text, loading, dimensions, and format',
            ),
            children: [
              for (var i = 0; i < report.images.length; i++) ...[
                if (i > 0) const Divider(height: 18),
                _ScannedImageRow(image: report.images[i]),
              ],
              if (report.images.isEmpty && report.totalImages > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Run a new audit to capture per-image details for this page.',
                    ),
                  ),
                )
              else if (report.images.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No image elements were found.'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScannedImageRow extends StatelessWidget {
  const _ScannedImageRow({required this.image});

  final ImageAuditItem image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimensions = [
      image.width,
      image.height,
    ].map((value) => value?.trim() ?? '').toList();
    final size = dimensions.every((value) => value.isNotEmpty)
        ? '${dimensions[0]} × ${dimensions[1]} px'
        : 'Dimensions not specified';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          image.src,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
        const SizedBox(height: 5),
        Text(
          image.hasAlt ? 'Alt: ${image.alt}' : 'Alt text is missing or empty',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _ImageFlagChip(label: 'Alt text', passed: image.hasAlt),
            _ImageFlagChip(label: 'Lazy loading', passed: image.lazyLoaded),
            _ImageFlagChip(
              label: image.format,
              passed: image.isModernFormat,
              neutral: !image.isModernFormat && !image.isLegacyFormat,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${image.loading == null || image.loading!.isEmpty ? 'Loading not set' : 'loading="${image.loading}"'} · $size',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ImageFlagChip extends StatelessWidget {
  const _ImageFlagChip({
    required this.label,
    required this.passed,
    this.neutral = false,
  });

  final String label;
  final bool passed;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = neutral
        ? scheme.surfaceContainerHighest
        : passed
        ? scheme.primaryContainer
        : scheme.errorContainer;
    final foreground = neutral
        ? scheme.onSurfaceVariant
        : passed
        ? scheme.onPrimaryContainer
        : scheme.onErrorContainer;
    return Chip(
      avatar: neutral
          ? null
          : Icon(
              passed ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 15,
              color: foreground,
            ),
      label: Text(label),
      labelStyle: TextStyle(color: foreground),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class OpenGraphCard extends StatelessWidget {
  const OpenGraphCard({super.key, required this.report});

  final OpenGraphReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.share_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Social preview',
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
            'Open Graph tags control how this page looks when it is shared '
            'on social media.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < report.tags.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            OpenGraphRow(tag: report.tags[i]),
          ],
          const SizedBox(height: 14),
          Text(
            report.isComplete
                ? 'All 3 tags are present.'
                : '${report.presentCount} of ${OpenGraphReport.tagCount} tags '
                      'present — missing tags will not appear in link previews.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class OpenGraphRow extends StatelessWidget {
  const OpenGraphRow({super.key, required this.tag});

  final OpenGraphTag tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tag.property,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tag.value ?? 'Missing — add this <meta> tag',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: tag.isPresent
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: PassFailChip(passed: tag.isPresent),
        ),
      ],
    );
  }
}

class SchemaCard extends StatelessWidget {
  const SchemaCard({super.key, required this.result});

  final SeoAuditResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final invalidScripts = result.schemaScripts
        .where((script) => !script.isValid)
        .length;
    final syntaxPassed = invalidScripts == 0;
    final hasMarkup = result.hasSchema || result.schemaScripts.isNotEmpty;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.code_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Schema markup',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusChip(
                status: hasMarkup && syntaxPassed
                    ? AuditStatus.good
                    : AuditStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasMarkup)
            Text(
              'No JSON-LD scripts or microdata were found. Structured data helps search engines understand page content.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            )
          else ...[
            if (result.schemaTypes.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in result.schemaTypes)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(
                          alpha: 0.55,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        type,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            if (result.schemaScripts.isNotEmpty) ...[
              if (result.schemaTypes.isNotEmpty) const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${result.schemaScripts.length} JSON-LD block(s) · '
                      '${result.schemaScripts.length - invalidScripts} valid · '
                      '$invalidScripts invalid',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  PassFailChip(passed: syntaxPassed),
                ],
              ),
              const SizedBox(height: 6),
              for (final script in result.schemaScripts)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  title: Text('JSON-LD script ${script.index}'),
                  subtitle: Text(
                    script.isValid
                        ? script.schemaTypes.isEmpty
                              ? 'Valid JSON · no @type found'
                              : script.schemaTypes.join(', ')
                        : 'Invalid JSON syntax',
                  ),
                  trailing: PassFailChip(passed: script.isValid),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        script.isValid ? 'Formatted JSON tree' : 'Parser error',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    if (!script.isValid && script.error != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          script.error!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 360),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: .55,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: SelectableText(
                            script.formattedJson ?? script.rawJson,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class LinksCard extends StatefulWidget {
  const LinksCard({super.key, required this.audit});
  final LinkAudit audit;
  @override
  State<LinksCard> createState() => _LinksCardState();
}

class _LinksCardState extends State<LinksCard> {
  bool scanning = false;
  int done = 0;
  List<String> broken = [];
  Future<void> scan() async {
    setState(() {
      scanning = true;
      done = 0;
      broken = [];
    });
    final client = http.Client();
    final links = widget.audit.urls.take(25).toList();
    try {
      for (final link in links) {
        try {
          var r = await client
              .head(Uri.parse(link))
              .timeout(const Duration(seconds: 7));
          if (r.statusCode == 405 || r.statusCode == 501) {
            r = await client
                .get(Uri.parse(link))
                .timeout(const Duration(seconds: 7));
          }
          if (r.statusCode == 404 || r.statusCode >= 500) broken.add(link);
        } catch (_) {}
        if (mounted) setState(() => done++);
      }
    } finally {
      client.close();
      if (mounted) setState(() => scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.audit;
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Links', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (!a.hasLinks)
            const Text('No navigable links found.')
          else ...[
            Row(
              children: [
                _LinkStat(label: 'Total', value: a.total),
                _LinkStat(label: 'Internal', value: a.internal),
                _LinkStat(label: 'External', value: a.external),
              ],
            ),
            Text(
              '${a.nofollow} nofollow · ${a.emptyHrefs} empty or placeholder',
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: scanning || a.urls.isEmpty ? null : scan,
              icon: const Icon(Icons.broken_image_outlined),
              label: Text(
                scanning
                    ? 'Scanning $done/${a.urls.length < 25 ? a.urls.length : 25}…'
                    : 'Scan for Broken Links',
              ),
            ),
            if (scanning)
              LinearProgressIndicator(
                value: a.urls.isEmpty
                    ? 0
                    : done / (a.urls.length < 25 ? a.urls.length : 25),
              ),
            if (!scanning && done > 0) ...[
              Text(
                broken.isEmpty
                    ? 'No 404 or server-error links found.'
                    : '${broken.length} dead links found',
              ),
              for (final url in broken)
                Text(url, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ],
      ),
    );
  }
}

class _LinkStat extends StatelessWidget {
  const _LinkStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class SiteFilesCard extends StatelessWidget {
  const SiteFilesCard({super.key, required this.report});

  final SiteFilesReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.travel_explore_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Crawl files',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusChip(
                status: report.allPassed
                    ? AuditStatus.good
                    : AuditStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Checked at the site root, independent of the audited page path. '
            'These do not affect the score.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _SiteFileRow(check: report.robots),
          const SizedBox(height: 12),
          _SiteFileRow(check: report.sitemap),
        ],
      ),
    );
  }
}

class AIReadinessCard extends StatelessWidget {
  const AIReadinessCard({super.key, required this.report});

  final AiReadinessReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasData = report.crawlers.isNotEmpty;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.smart_toy_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI Search & LLM Readiness',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(
                avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text('AI ${hasData ? report.score : '—'}/100'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Estimate from robots.txt access rules and root-level LLM guidance files. This is not a formal ranking score.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasData)
            const Text(
              'AI crawler rules were not recorded for this saved audit.',
            )
          else ...[
            Text(
              '${report.allowedCount} allowed · ${report.restrictedCount} restricted · ${report.disallowedCount} disallowed',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            for (final crawler in report.crawlers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            crawler.userAgent,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            crawler.detail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AiCrawlerChip(status: crawler.access),
                  ],
                ),
              ),
          ],
          const Divider(height: 24),
          Text('LLM guidance files', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _AiFileChip(fileName: 'llms.txt', check: report.llmsTxt),
              _AiFileChip(fileName: 'llms-full.txt', check: report.llmsFullTxt),
            ],
          ),
        ],
      ),
    );
  }
}

class CoreWebVitalsCard extends StatefulWidget {
  const CoreWebVitalsCard({super.key, required this.auditedUrl});

  final String auditedUrl;

  @override
  State<CoreWebVitalsCard> createState() => _CoreWebVitalsCardState();
}

class _CoreWebVitalsCardState extends State<CoreWebVitalsCard> {
  final PageSpeedInsightsService _service = PageSpeedInsightsService();
  PageSpeedReport? _report;
  String? _error;
  bool _loading = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(covariant CoreWebVitalsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auditedUrl != widget.auditedUrl) _run();
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  Future<void> _run() async {
    final requestVersion = ++_requestVersion;
    final targetUrl = widget.auditedUrl;
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await _service.analyze(targetUrl);
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _report = report);
      }
    } on PageSpeedInsightsException catch (error) {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _error = 'PageSpeed analysis failed: $error');
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final report = _report;
    final score = report?.performanceScore;
    final scoreRating = score == null
        ? VitalRating.unavailable
        : score >= 90
        ? VitalRating.good
        : score >= 50
        ? VitalRating.needsImprovement
        : VitalRating.poor;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.speed_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Core Web Vitals & Speed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Run mobile PageSpeed test again',
                onPressed: _loading ? null : _run,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Text(
            'Google PageSpeed Insights · Mobile',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Running mobile performance analysis…'),
                  ],
                ),
              ),
            )
          else if (_error != null)
            _PageSpeedError(message: _error!, onRetry: _run)
          else if (report != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _PerformanceScoreRing(score: score, rating: scoreRating),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    report.usedOriginData
                        ? 'Field metrics use the 75th percentile of recent real-user data, falling back to the site origin when page samples are limited.'
                        : 'Field data uses the 75th percentile of recent real users; Lighthouse lab results fill missing metrics.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VitalRing(
                  label: 'LCP',
                  metric: report.lcp,
                  kind: _VitalKind.lcp,
                ),
                _VitalRing(
                  label: 'CLS',
                  metric: report.cls,
                  kind: _VitalKind.cls,
                ),
                _VitalRing(
                  label: 'INP',
                  metric: report.inp,
                  kind: _VitalKind.inp,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'LCP: loading · CLS: visual stability · INP: responsiveness. '
              'Field data covers a recent 28-day period; lab values are simulated.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _VitalKind { lcp, cls, inp }

class _PerformanceScoreRing extends StatelessWidget {
  const _PerformanceScoreRing({required this.score, required this.rating});
  final int? score;
  final VitalRating rating;

  @override
  Widget build(BuildContext context) {
    final color = _vitalColor(context, rating);
    final value = (score ?? 0) / 100;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => CircularProgressIndicator(
              value: score == null ? 0 : progress,
              strokeWidth: 8,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score?.toString() ?? '—',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
              Text('Score', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _VitalRing extends StatelessWidget {
  const _VitalRing({
    required this.label,
    required this.metric,
    required this.kind,
  });
  final String label;
  final WebVitalMetric metric;
  final _VitalKind kind;

  String get _value {
    final value = metric.value;
    if (value == null) return '—';
    if (kind == _VitalKind.cls) return value.toStringAsFixed(2);
    if (kind == _VitalKind.lcp && value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)} s';
    }
    return '${value.round()} ms';
  }

  double get _progress {
    final value = metric.value;
    if (value == null) return 0;
    final maximum = switch (kind) {
      _VitalKind.lcp => 8000.0,
      _VitalKind.cls => 0.5,
      _VitalKind.inp => 1000.0,
    };
    return (1 - value / maximum).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _vitalColor(context, metric.rating);
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => CircularProgressIndicator(
                    value: metric.value == null ? 0 : progress,
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _value,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: theme.textTheme.titleSmall),
          Text(
            _ratingLabel(metric.rating),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
          Text(
            switch (metric.source) {
              'Real-user field data' => 'Field data',
              'Origin field data' => 'Origin data',
              'Lighthouse lab data' => 'Lab data',
              _ => 'No data',
            },
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageSpeedError extends StatelessWidget {
  const _PageSpeedError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try again'),
      ),
    ],
  );
}

Color _vitalColor(BuildContext context, VitalRating rating) {
  final scheme = Theme.of(context).colorScheme;
  return switch (rating) {
    VitalRating.good => const Color(0xFF168A55),
    VitalRating.needsImprovement => const Color(0xFFD28A00),
    VitalRating.poor => scheme.error,
    VitalRating.unavailable => scheme.onSurfaceVariant,
  };
}

String _ratingLabel(VitalRating rating) => switch (rating) {
  VitalRating.good => 'Good',
  VitalRating.needsImprovement => 'Needs work',
  VitalRating.poor => 'Poor',
  VitalRating.unavailable => 'No data',
};

class _AiCrawlerChip extends StatelessWidget {
  const _AiCrawlerChip({required this.status});
  final AiCrawlerAccess status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, color, foreground) = switch (status) {
      AiCrawlerAccess.allowed => (
        'Allowed',
        Icons.check_circle_outline,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      AiCrawlerAccess.restricted => (
        'Partial',
        Icons.warning_amber_rounded,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      AiCrawlerAccess.disallowed => (
        'Blocked',
        Icons.block_rounded,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      AiCrawlerAccess.unknown => (
        'Unknown',
        Icons.help_outline_rounded,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: foreground),
      label: Text(label),
      labelStyle: TextStyle(color: foreground),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AiFileChip extends StatelessWidget {
  const _AiFileChip({required this.fileName, required this.check});
  final String fileName;
  final SiteFileCheck? check;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final passed = check?.passed ?? false;
    final unknown = check == null;
    final color = unknown
        ? scheme.surfaceContainerHighest
        : passed
        ? scheme.primaryContainer
        : scheme.errorContainer;
    final foreground = unknown
        ? scheme.onSurfaceVariant
        : passed
        ? scheme.onPrimaryContainer
        : scheme.onErrorContainer;
    return Tooltip(
      message: check?.detail ?? 'Not recorded in this audit',
      child: Chip(
        avatar: Icon(
          unknown
              ? Icons.help_outline_rounded
              : passed
              ? Icons.check_circle_outline
              : Icons.cancel_outlined,
          size: 16,
          color: foreground,
        ),
        label: Text(
          '$fileName ${unknown
              ? 'Unknown'
              : passed
              ? 'Found'
              : 'Missing'}',
        ),
        labelStyle: TextStyle(color: foreground),
        backgroundColor: color,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SiteFileRow extends StatelessWidget {
  const _SiteFileRow({required this.check});

  final SiteFileCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                check.fileName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                check.detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        PassFailChip(passed: check.passed),
      ],
    );
  }
}

class LoadingCard extends StatelessWidget {
  const LoadingCard({
    super.key,
    this.message = 'Fetching page and analysing tags…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not complete the audit',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ContentAnalyzerCard extends StatelessWidget {
  const ContentAnalyzerCard({super.key, required this.metrics});
  final ContentMetrics metrics;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Content & keyword density', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('${metrics.wordCount} words')),
              Chip(
                label: Text(
                  'Text / HTML ${metrics.textToHtmlRatio.toStringAsFixed(1)}%',
                ),
              ),
              if (metrics.isThinContent)
                Chip(
                  avatar: Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.error,
                  ),
                  label: const Text('Thin Content (<300 words)'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Top single keywords', style: theme.textTheme.titleSmall),
          for (final k in metrics.keywords)
            _KeywordBar(
              metric: k,
              max: metrics.keywords.isEmpty ? 1 : metrics.keywords.first.count,
            ),
          const SizedBox(height: 12),
          Text('Top two-word phrases', style: theme.textTheme.titleSmall),
          for (final k in metrics.bigrams)
            _KeywordBar(
              metric: k,
              max: metrics.bigrams.isEmpty ? 1 : metrics.bigrams.first.count,
            ),
        ],
      ),
    );
  }
}

class _KeywordBar extends StatelessWidget {
  const _KeywordBar({required this.metric, required this.max});
  final KeywordMetric metric;
  final int max;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 125,
          child: Text(
            metric.term,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(child: LinearProgressIndicator(value: metric.count / max)),
        const SizedBox(width: 8),
        Text('${metric.count} · ${metric.density.toStringAsFixed(1)}%'),
      ],
    ),
  );
}

class IndexationCard extends StatelessWidget {
  const IndexationCard({super.key, required this.info, required this.pageUrl});
  final IndexationInfo info;
  final String pageUrl;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Indexation & identity', style: theme.textTheme.titleMedium),
          if (info.blocksIndexing)
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'High priority: robots meta contains noindex or nofollow. Search engines may not index or follow links on this page.',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          _MetaLine(label: 'Robots', value: info.robotsMeta ?? 'Not set'),
          _MetaLine(label: 'Googlebot', value: info.googlebotMeta ?? 'Not set'),
          _MetaLine(
            label: 'Canonical',
            value:
                '${info.canonicalState(pageUrl)}${info.canonicalUrl == null ? '' : ' · ${info.canonicalUrl}'}',
          ),
          _MetaLine(label: 'HTML language', value: info.language ?? 'Not set'),
          _MetaLine(
            label: 'Mobile viewport',
            value: info.viewport ?? 'Not set',
          ),
          _MetaLine(label: 'Favicon', value: info.faviconUrl ?? 'Not found'),
          const SizedBox(height: 8),
          Text('Hreflang alternates', style: theme.textTheme.titleSmall),
          if (info.hreflangs.isEmpty)
            const Text('None found')
          else
            for (final e in info.hreflangs)
              Text(
                '${e.language} → ${e.url}',
                style: theme.textTheme.bodySmall,
              ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
  );
}

class SecurityResponseCard extends StatelessWidget {
  const SecurityResponseCard({super.key, required this.report});
  final SecurityReport report;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Security & Server Response',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(
                avatar: const Icon(Icons.timer_outlined, size: 16),
                label: Text('${report.responseTimeMs} ms'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Security headers', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerChip(context, 'HSTS', report.hsts),
              _headerChip(context, 'CSP', report.csp),
              _headerChip(context, 'X-Frame-Options', report.xFrameOptions),
              _headerChip(
                context,
                'X-Content-Type-Options',
                report.xContentTypeOptions,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Server: ${report.server ?? 'Not disclosed'}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text('Mixed content', style: theme.textTheme.titleSmall),
          if (report.mixedContentUrls.isEmpty)
            Text(
              'No insecure HTTP resources found on this HTTPS page.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            Text(
              '${report.mixedContentUrls.length} insecure resource URL(s)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final url in report.mixedContentUrls)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  url,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _headerChip(BuildContext context, String label, bool present) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        present ? Icons.check_circle : Icons.cancel,
        size: 16,
        color: present ? scheme.primary : scheme.error,
      ),
      label: Text('$label ${present ? 'Present' : 'Missing'}'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class ReadabilityAccessibilityCard extends StatelessWidget {
  const ReadabilityAccessibilityCard({super.key, required this.report});

  final ReadabilityAccessibilityReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasIssues = report.accessibilityIssueCount > 0;
    final badgeColor = hasIssues
        ? scheme.errorContainer
        : scheme.primaryContainer;
    final badgeText = hasIssues
        ? scheme.onErrorContainer
        : scheme.onPrimaryContainer;

    return SectionCard(
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: const IconBubble(icon: Icons.accessibility_new_rounded),
          title: Text(
            'Readability & Accessibility',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(report.readingLevel),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    '${report.fleschScore.toStringAsFixed(0)} Flesch',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: Icon(
                    hasIssues
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    size: 16,
                    color: badgeText,
                  ),
                  label: Text('${report.accessibilityIssueCount} a11y fixes'),
                  backgroundColor: badgeColor,
                  labelStyle: TextStyle(color: badgeText),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          children: [
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${report.wordCount} words · ${report.sentenceCount} sentences · '
                '${report.syllableCount} estimated syllables · ${report.gradeLevel}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            if (report.issues.isEmpty)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle_outline),
                title: Text('No common accessibility gaps found'),
                subtitle: Text(
                  'Buttons, inputs, and links passed these checks.',
                ),
              )
            else
              for (final issue in report.issues)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.error,
                  ),
                  title: Text('${issue.category} (${issue.count})'),
                  subtitle: Text(issue.description),
                ),
          ],
        ),
      ),
    );
  }
}
