import 'package:flutter/material.dart';

import '../services/seo_audit_service.dart';
import '../widgets/app_widgets.dart';
import 'competitor_compare_screen.dart';
import 'serp_preview_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({
    super.key,
    required this.active,
    required this.result,
    required this.isSample,
    required this.onGoToAudit,
    required this.onSample,
    required this.onOpenTab,
    this.onReport,
  });
  final bool active, isSample;
  final SeoAuditResult? result;
  final VoidCallback onGoToAudit, onSample;
  final ValueChanged<int> onOpenTab;
  final VoidCallback? onReport;
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  int _tool = 0;
  final Set<int> _visited = {0};
  void _select(int tool) => setState(() {
    _tool = tool;
    _visited.add(tool);
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.active || _tool == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && widget.active) _select(0);
    },
    child: IndexedStack(
      index: _tool,
      children: [
        _menu(context),
        if (_visited.contains(1))
          TickerMode(
            enabled: _tool == 1 && widget.active,
            child: SerpPreviewScreen(
              result: widget.result,
              onGoToAudit: widget.onGoToAudit,
              isSample: widget.isSample,
              onBack: () => _select(0),
            ),
          )
        else
          const SizedBox.shrink(),
        if (_visited.contains(2))
          TickerMode(
            enabled: _tool == 2 && widget.active,
            child: CompetitorCompareScreen(
              result: widget.result,
              onGoToAudit: widget.onGoToAudit,
              isSample: widget.isSample,
              onBack: () => _select(0),
            ),
          )
        else
          const SizedBox.shrink(),
      ],
    ),
  );

  Widget _menu(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BrandTitle(title: 'Tools')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'A closer look at your page',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Explore the details, test your presentation and turn findings into next steps.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _toolCard(
                context,
                'Search & social previews',
                'Try titles, descriptions and share cards before publishing.',
                Icons.preview_outlined,
                () => _select(1),
              ),
              _toolCard(
                context,
                'Competitor comparison',
                'Compare two pages side by side with the same core checks.',
                Icons.compare_arrows_rounded,
                () => _select(2),
              ),
              _toolCard(
                context,
                'Technical diagnostics',
                'PageSpeed, schema, crawl files, AI access and link checks.',
                Icons.code_rounded,
                () => widget.onOpenTab(2),
              ),
              _toolCard(
                context,
                'Content & accessibility',
                'Headings, readable content and meaningful image descriptions.',
                Icons.article_outlined,
                () => widget.onOpenTab(1),
              ),
              _toolCard(
                context,
                'Client reports',
                widget.result == null
                    ? 'Start with a page audit, then share a branded PDF or CSV.'
                    : 'Add your brand, client notes and before-and-after changes.',
                Icons.ios_share_rounded,
                widget.onReport ?? widget.onGoToAudit,
              ),
              const SizedBox(height: 8),
              MessageCard(
                icon: Icons.science_outlined,
                title: 'Explore without a website',
                message: 'Try a realistic sample audit. Everything works offline and your real workspace stays separate.',
                action: FilledButton.tonalIcon(
                  onPressed: widget.onSample,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Explore sample audit'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _toolCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SectionCard(
      padding: const EdgeInsets.all(8),
      child: ListTile(
        leading: IconBubble(icon: icon),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(description),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );
}
