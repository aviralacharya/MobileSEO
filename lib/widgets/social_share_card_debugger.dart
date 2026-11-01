import 'package:flutter/material.dart';

import '../services/seo_audit_service.dart';
import 'app_widgets.dart';

class SocialShareCardDebugger extends StatefulWidget {
  const SocialShareCardDebugger({
    super.key,
    required this.result,
    this.allowNetworkImages = true,
  });
  final SeoAuditResult result;
  final bool allowNetworkImages;

  @override
  State<SocialShareCardDebugger> createState() =>
      _SocialShareCardDebuggerState();
}

class _SocialShareCardDebuggerState extends State<SocialShareCardDebugger> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _image = TextEditingController();
  String? _loadedUrl;
  bool _titleEdited = false;
  bool _descriptionEdited = false;
  bool _imageEdited = false;

  @override
  void initState() {
    super.initState();
    _syncFields();
  }

  @override
  void didUpdateWidget(covariant SocialShareCardDebugger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result)) {
      _titleEdited = false;
      _descriptionEdited = false;
      _imageEdited = false;
      _loadedUrl = null;
      _syncFields();
    }
  }

  void _syncFields() {
    final result = widget.result;
    if (result.url == _loadedUrl) return;
    _loadedUrl = result.url;
    _title.text =
        result.openGraph.title ??
        result.title ??
        result.openGraph.twitterTitle ??
        '';
    _description.text =
        result.openGraph.description ??
        result.description ??
        result.openGraph.twitterDescription ??
        '';
    _image.text = result.openGraph.image ?? result.openGraph.twitterImage ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final og = widget.result.openGraph;
    final pageUri = Uri.tryParse(widget.result.url);
    final domain =
        Uri.tryParse(og.url ?? widget.result.url)?.host ??
        pageUri?.host ??
        widget.result.url;
    final title = _title.text.trim().isEmpty
        ? 'Add a social title'
        : _title.text.trim();
    final description = _description.text.trim().isEmpty
        ? 'Add a short page summary for social sharing.'
        : _description.text.trim();
    final image = widget.allowNetworkImages
        ? _resolveImage(_image.text, widget.result.url)
        : null;
    final xImage = !widget.allowNetworkImages
        ? null
        : _resolveImage(og.twitterImage ?? _image.text, widget.result.url);
    final missing = <(String, String)>[
      if (og.title == null)
        ('og:title', 'Add a concise, page-specific share title.'),
      if (og.description == null)
        ('og:description', 'Add a short summary that explains the page value.'),
      if (og.image == null)
        (
          'og:image',
          'Add an absolute HTTPS image URL; a clear landscape image around 1200 × 630 px works well.',
        ),
      if (og.url == null)
        ('og:url', 'Set the stable canonical URL for this page.'),
      if (og.twitterCard == null)
        ('twitter:card', 'Set summary_large_image to request a large X card.'),
      if (og.twitterImage == null)
        (
          'twitter:image',
          'Set the image intended for X; it may fall back to og:image when omitted.',
        ),
    ];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Social Share Card Debugger', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Preview changes here before publishing them to your site.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            maxLength: 120,
            onChanged: (_) => setState(() => _titleEdited = true),
            decoration: const InputDecoration(labelText: 'Social title'),
          ),
          TextField(
            controller: _description,
            maxLength: 240,
            maxLines: 2,
            onChanged: (_) => setState(() => _descriptionEdited = true),
            decoration: const InputDecoration(labelText: 'Social description'),
          ),
          TextField(
            controller: _image,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() => _imageEdited = true),
            decoration: const InputDecoration(
              labelText: 'Social image URL',
              hintText: 'https://example.com/share-image.jpg',
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final facebook = _FacebookLinkedInCard(
                domain: domain,
                title: title,
                description: description,
                image: image,
              );
              final xCard = _XShareCard(
                domain: domain,
                cardType:
                    og.twitterCard ??
                    (image == null ? 'summary' : 'summary_large_image'),
                title: _titleEdited
                    ? title
                    : (og.twitterTitle ??
                          og.title ??
                          widget.result.title ??
                          title),
                description: _descriptionEdited
                    ? description
                    : (og.twitterDescription ??
                          og.description ??
                          widget.result.description ??
                          description),
                image: _imageEdited ? image : xImage,
              );
              if (constraints.maxWidth >= 620) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: facebook),
                    const SizedBox(width: 14),
                    Expanded(child: xCard),
                  ],
                );
              }
              return Column(
                children: [facebook, const SizedBox(height: 14), xCard],
              );
            },
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Tag checks', style: theme.textTheme.titleSmall),
              if (missing.isNotEmpty)
                _TagCountBadge(count: missing.length)
              else
                const _AllTagsBadge(),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final item in missing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MissingTagBadge(tag: item.$1),
                    const SizedBox(height: 4),
                    Text(item.$2, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

String? _resolveImage(String raw, String pageUrl) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.hasScheme) return uri.toString();
  return Uri.tryParse(pageUrl)?.resolveUri(uri).toString();
}

class _FacebookLinkedInCard extends StatelessWidget {
  const _FacebookLinkedInCard({
    required this.domain,
    required this.title,
    required this.description,
    required this.image,
  });
  final String domain, title, description;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Facebook · LinkedIn', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.public_rounded,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(domain, style: theme.textTheme.labelLarge),
                      Text('Shared a link', style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded),
              ],
            ),
            const SizedBox(height: 12),
            _NetworkShareImage(url: image, aspectRatio: 1.91),
            const SizedBox(height: 10),
            Text(domain.toUpperCase(), style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Divider(color: scheme.outlineVariant),
            const Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 12,
              runSpacing: 8,
              children: [
                _SocialAction(icon: Icons.thumb_up_alt_outlined, label: 'Like'),
                _SocialAction(
                  icon: Icons.chat_bubble_outline,
                  label: 'Comment',
                ),
                _SocialAction(icon: Icons.share_outlined, label: 'Share'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _XShareCard extends StatelessWidget {
  const _XShareCard({
    required this.domain,
    required this.cardType,
    required this.title,
    required this.description,
    required this.image,
  });
  final String domain, cardType, title, description;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('X (Twitter)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: scheme.onSurface,
                  child: Text(
                    'X',
                    style: TextStyle(color: scheme.surface, fontSize: 19),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    domain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('· 1h', style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(13),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NetworkShareImage(url: image, aspectRatio: 2),
                  Padding(
                    padding: const EdgeInsets.all(11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(domain, style: theme.textTheme.labelSmall),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text('Card type: $cardType', style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            const Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 12,
              runSpacing: 8,
              children: [
                _SocialAction(icon: Icons.chat_bubble_outline, label: 'Reply'),
                _SocialAction(icon: Icons.repeat_rounded, label: 'Repost'),
                _SocialAction(icon: Icons.favorite_border, label: 'Like'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkShareImage extends StatelessWidget {
  const _NetworkShareImage({required this.url, required this.aspectRatio});
  final String? url;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: url == null
            ? _fallback(scheme)
            : Image.network(
                url!,
                key: ValueKey(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(scheme),
              ),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) => Semantics(
    label: 'Share image preview',
    image: true,
    excludeSemantics: true,
    child: Container(
      color: scheme.surfaceContainerHighest,
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_outlined,
                size: 38,
                color: scheme.onSurfaceVariant,
              ),
              if (constraints.maxHeight >
                  MediaQuery.textScalerOf(context).scale(48) + 48) ...[
                const SizedBox(height: 4),
                Text(
                  'Share image preview',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _SocialAction extends StatelessWidget {
  const _SocialAction({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _TagCountBadge extends StatelessWidget {
  const _TagCountBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        Icons.warning_amber_rounded,
        size: 16,
        color: scheme.onErrorContainer,
      ),
      label: Text('$count missing'),
      backgroundColor: scheme.errorContainer,
      labelStyle: TextStyle(color: scheme.onErrorContainer),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AllTagsBadge extends StatelessWidget {
  const _AllTagsBadge();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        Icons.check_circle_outline,
        size: 16,
        color: scheme.onPrimaryContainer,
      ),
      label: const Text('Critical tags found'),
      backgroundColor: scheme.primaryContainer,
      labelStyle: TextStyle(color: scheme.onPrimaryContainer),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MissingTagBadge extends StatelessWidget {
  const _MissingTagBadge({required this.tag});
  final String tag;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        Icons.warning_amber_rounded,
        size: 15,
        color: scheme.onErrorContainer,
      ),
      label: Text(tag),
      labelStyle: TextStyle(
        color: scheme.onErrorContainer,
        fontFamily: 'monospace',
      ),
      backgroundColor: scheme.errorContainer,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
