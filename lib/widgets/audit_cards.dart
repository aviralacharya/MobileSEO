import 'package:flutter/material.dart';

import '../services/image_seo_checker.dart';
import '../services/link_checker.dart';
import '../services/open_graph_checker.dart';
import '../services/seo_audit_service.dart';
import '../services/site_files_checker.dart';
import 'app_widgets.dart';

/// Meta title or description line item.
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
            status: result.h2Count > 0
                ? AuditStatus.good
                : AuditStatus.warning,
          ),
          const SizedBox(height: 10),
          _HeadingRow(
            tag: 'H3',
            count: result.h3Count,
            caption: 'Sub-section headings',
            status: result.h3Count > 0
                ? AuditStatus.good
                : AuditStatus.warning,
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
    final status = report.isHealthy ? AuditStatus.good : AuditStatus.warning;
    final palette = StatusPalette.of(context, status);
    final visible = report.imagesMissingAlt.take(4).toList();
    final hidden = report.missingAltCount - visible.length;

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
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _MissingImageRow(issue: visible[i]),
            ],
            if (hidden > 0) ...[
              const SizedBox(height: 10),
              Text(
                '+ $hidden more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MissingImageRow extends StatelessWidget {
  const _MissingImageRow({required this.issue});

  final ImageIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.broken_image_outlined,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            issue.src,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            issue.hasEmptyAlt ? 'alt=""' : 'no alt',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
                  fontStyle:
                      tag.isPresent ? FontStyle.normal : FontStyle.italic,
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
                status:
                    result.hasSchema ? AuditStatus.good : AuditStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!result.hasSchema)
            Text(
              'No JSON-LD or microdata found. Structured data helps search '
              'engines show rich results.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            )
          else
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
                      color: scheme.secondaryContainer.withValues(alpha: 0.55),
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
        ],
      ),
    );
  }
}

class LinksCard extends StatelessWidget {
  const LinksCard({super.key, required this.audit});

  final LinkAudit audit;

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
              const IconBubble(icon: Icons.link_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Links',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PassFailChip(passed: audit.hasLinks),
            ],
          ),
          const SizedBox(height: 14),
          if (!audit.hasLinks)
            Text(
              'No navigable links were found on this page. Search engines '
              'discover new pages by following links, so internal links are '
              'worth adding.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            )
          else ...[
            Row(
              children: [
                _LinkStat(label: 'Total', value: audit.total),
                _LinkStat(label: 'Internal', value: audit.internal),
                _LinkStat(label: 'External', value: audit.external),
              ],
            ),
            if (audit.hasEmptyHrefs || audit.nofollow > 0) ...[
              const SizedBox(height: 14),
              Text(
                [
                  if (audit.hasEmptyHrefs)
                    '${audit.emptyHrefs} empty or placeholder hrefs',
                  if (audit.nofollow > 0)
                    '${audit.nofollow} nofollow links',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (audit.externalHosts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final host in audit.externalHosts.take(6))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        host,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontFamily: 'monospace',
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
  const LoadingCard({super.key, this.message = 'Fetching page and analysing tags…'});

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
