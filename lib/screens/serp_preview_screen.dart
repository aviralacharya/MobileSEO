import 'package:flutter/material.dart';

import '../services/seo_audit_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/social_share_card_debugger.dart';
import 'legal_pages.dart';

class SerpPreviewScreen extends StatefulWidget {
  const SerpPreviewScreen({
    super.key,
    required this.result,
    required this.onGoToAudit,
  });
  final SeoAuditResult? result;
  final VoidCallback onGoToAudit;

  @override
  State<SerpPreviewScreen> createState() => _SerpPreviewScreenState();
}

class _SerpPreviewScreenState extends State<SerpPreviewScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _mobile = true;
  String? _loadedUrl;

  @override
  void didUpdateWidget(covariant SerpPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFields();
  }

  void _syncFields() {
    final result = widget.result;
    if (result == null || result.url == _loadedUrl) return;
    _loadedUrl = result.url;
    _title.text = result.title ?? '';
    _description.text = result.description ?? '';
  }

  @override
  void initState() {
    super.initState();
    _syncFields();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(
      appBar: AppBar(
        actions: const [ThemeModeToggle(), LegalMenuButton()],
        title: const BrandTitle(
          title: 'SERP & Social Previews',
          icon: Icons.search_rounded,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: result == null
                  ? MessageCard(
                      icon: Icons.preview_outlined,
                      title: 'Run an audit first',
                      message: 'Previews use metadata from your audited page.',
                      action: FilledButton.icon(
                        onPressed: widget.onGoToAudit,
                        icon: const Icon(Icons.insights_rounded),
                        label: const Text('Go to Audit Dashboard'),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _serp(context, result),
                        const SizedBox(height: 16),
                        _social(context, result),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _serp(BuildContext context, SeoAuditResult result) {
    final theme = Theme.of(context);
    final uri = Uri.tryParse(result.url);
    final host = uri?.host ?? result.url;
    final title = _title.text.isEmpty ? 'Add a page title' : _title.text;
    final desc = _description.text.isEmpty
        ? 'Add a meta description'
        : _description.text;
    final link = theme.brightness == Brightness.dark
        ? const Color(0xff8ab4f8)
        : const Color(0xff1a0dab);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Google Search preview', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Mobile SERP'),
                icon: Icon(Icons.phone_android),
              ),
              ButtonSegment(
                value: false,
                label: Text('Desktop SERP'),
                icon: Icon(Icons.desktop_windows),
              ),
            ],
            selected: {_mobile},
            onSelectionChanged: (v) => setState(() => _mobile = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 100,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Preview title',
              helperText: 'About 60 characters is a useful guide.',
            ),
          ),
          TextField(
            controller: _description,
            maxLength: 300,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Preview description',
              helperText: 'About 160 characters is a useful guide.',
            ),
          ),
          const SizedBox(height: 12),
          AnimatedAlign(
            alignment: _mobile ? Alignment.center : Alignment.centerLeft,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _mobile ? 360 : 600),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.public, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  host,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$host${uri?.path ?? '/'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: link,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: _mobile ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Preview only. Editing these fields does not change the live page.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _social(BuildContext context, SeoAuditResult result) =>
      SocialShareCardDebugger(result: result);
}
