import 'package:flutter/material.dart';

import '../services/seo_audit_service.dart';
import '../services/site_files_checker.dart';
import '../widgets/app_widgets.dart';
import '../widgets/audit_cards.dart';
import '../widgets/fix_checklist.dart';
import '../widgets/score_gauge.dart';

/// Tab 1 of the shell: the audit form plus the three result tabs.
///
/// All mutable audit state lives in [HomeShell]; this screen owns only its
/// [TabController] and whether the search form is collapsed.
class AuditDashboardScreen extends StatefulWidget {
  const AuditDashboardScreen({
    super.key,
    required this.urlController,
    required this.isLoading,
    required this.urlError,
    required this.errorMessage,
    required this.canRetry,
    required this.result,
    required this.siteFiles,
    required this.checkedFixes,
    required this.tabIndex,
    required this.onRun,
    required this.onRetry,
    required this.onUrlEdited,
    required this.onToggleFix,
    required this.onResetFixes,
    required this.onTabChanged,
  });

  final TextEditingController urlController;
  final bool isLoading;
  final String? urlError;
  final String? errorMessage;
  final bool canRetry;
  final SeoAuditResult? result;
  final SiteFilesReport? siteFiles;

  /// Labels of the checklist items the user has ticked off.
  final Set<String> checkedFixes;

  /// Selected result tab, lifted so it survives navigation.
  final int tabIndex;

  final VoidCallback onRun;
  final VoidCallback onRetry;
  final VoidCallback onUrlEdited;
  final ValueChanged<String> onToggleFix;
  final VoidCallback onResetFixes;
  final ValueChanged<int> onTabChanged;

  @override
  State<AuditDashboardScreen> createState() => _AuditDashboardScreenState();
}

class _AuditDashboardScreenState extends State<AuditDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late int _reportedIndex;
  late bool _searchExpanded;

  @override
  void initState() {
    super.initState();
    _reportedIndex = widget.tabIndex;
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.tabIndex,
    )..addListener(_handleTabChange);
    _searchExpanded = widget.result == null;
  }

  @override
  void didUpdateWidget(AuditDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Collapse the form once a fresh result arrives, expand it again if the
    // result was cleared by an error.
    if (oldWidget.result == null && widget.result != null) {
      _searchExpanded = false;
    } else if (oldWidget.result != null && widget.result == null) {
      _searchExpanded = true;
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_handleTabChange);
    _tabs.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabs.index == _reportedIndex) return;
    _reportedIndex = _tabs.index;
    widget.onTabChanged(_reportedIndex);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: const BrandTitle(title: 'SEO Audit'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'On-Page & Content'),
            Tab(text: 'Technical & Links'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: _searchArea(context),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _bodyForTab(_tabs.index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search form
  // ---------------------------------------------------------------------------

  Widget _searchArea(BuildContext context) {
    final compact = widget.result != null && !_searchExpanded;
    return compact ? _compactSearch(context) : _fullSearch(context);
  }

  Widget _compactSearch(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          const IconBubble(icon: Icons.public_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Audited page',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  widget.result!.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => setState(() => _searchExpanded = true),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _fullSearch(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Audit a page',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.result != null)
                IconButton(
                  tooltip: 'Collapse',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _searchExpanded = false),
                  icon: const Icon(Icons.expand_less_rounded),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a public URL and check the on-page SEO basics.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.urlController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => widget.onUrlEdited(),
            onSubmitted: (_) => widget.onRun(),
            decoration: InputDecoration(
              hintText: 'https://example.com',
              prefixIcon: const Icon(Icons.link_rounded),
              helperText: 'https:// is added automatically',
              errorText: widget.urlError,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: widget.isLoading ? null : widget.onRun,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: widget.isLoading
                    ? Row(
                        key: const ValueKey('loading'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Auditing…'),
                        ],
                      )
                    : const Row(
                        key: ValueKey('idle'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded, size: 20),
                          SizedBox(width: 10),
                          Text('Run SEO Audit'),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  Widget _bodyForTab(int index) {
    switch (index) {
      case 1:
        return _TabBody(
          stateKey: 'on-page',
          child: _onPageTab(context),
        );
      case 2:
        return _TabBody(
          stateKey: 'technical',
          child: _technicalTab(context),
        );
      default:
        return _TabBody(
          stateKey: 'overview',
          child: _overviewTab(context),
        );
    }
  }

  Widget _overviewTab(BuildContext context) {
    if (widget.isLoading) {
      return const LoadingCard();
    }
    if (widget.errorMessage != null) {
      return ErrorCard(
        message: widget.errorMessage!,
        onRetry: widget.canRetry ? widget.onRetry : null,
      );
    }

    final result = widget.result;
    if (result == null) {
      return const MessageCard(
        icon: Icons.travel_explore_rounded,
        title: 'Ready when you are',
        message: 'Enter a URL above to score the page and get a checklist of '
            'everything that is holding it back.',
      );
    }

    final fixedCount = widget.checkedFixes.length;
    final score = result.scoreWithFixes(fixedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScoreSummaryCard(
          result: result,
          score: score,
          fixedCount: fixedCount,
        ),
        const SizedBox(height: 16),
        FixChecklist(
          fixes: result.failedChecks,
          checked: widget.checkedFixes,
          pointsPerFix: result.pointsPerFix,
          onToggle: widget.onToggleFix,
          onReset: widget.onResetFixes,
        ),
        const SizedBox(height: 16),
        _ScoreBreakdown(result: result, score: score),
      ],
    );
  }

  Widget _onPageTab(BuildContext context) {
    if (widget.isLoading) return const LoadingCard();
    final result = widget.result;
    if (result == null) {
      return const MessageCard(
        icon: Icons.description_outlined,
        title: 'No page audited yet',
        message: 'Run an audit and the title, description, headings and image '
            'alt text will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaCard(check: result.checks[0], icon: Icons.title_rounded),
        const SizedBox(height: 16),
        MetaCard(check: result.checks[1], icon: Icons.notes_rounded),
        const SizedBox(height: 16),
        HeadingsCard(result: result),
        const SizedBox(height: 16),
        ImagesCard(report: result.imageReport),
      ],
    );
  }

  Widget _technicalTab(BuildContext context) {
    if (widget.isLoading) return const LoadingCard();
    final result = widget.result;
    if (result == null) {
      return const MessageCard(
        icon: Icons.build_circle_outlined,
        title: 'No page audited yet',
        message: 'Schema markup, robots.txt, sitemap.xml and link counts will '
            'appear here after an audit.',
      );
    }

    final siteFiles = widget.siteFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SchemaCard(result: result),
        const SizedBox(height: 16),
        LinksCard(audit: result.linkAudit),
        const SizedBox(height: 16),
        if (siteFiles != null)
          SiteFilesCard(report: siteFiles)
        else
          const LoadingCard(message: 'Checking robots.txt and sitemap.xml…'),
      ],
    );
  }
}

/// Scrollable, width-limited container shared by the three tabs.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.stateKey, required this.child});

  final String stateKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: ValueKey(stateKey),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: child,
        ),
      ),
    );
  }
}

/// Per-check breakdown that mirrors the gauge.
class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.result, required this.score});

  final SeoAuditResult result;
  final int score;

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
              const IconBubble(icon: Icons.checklist_rtl_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'All checks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$score/100',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < result.checks.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.checks[i].label,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                PassFailChip(
                  passed: result.checks[i].status == AuditStatus.good,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
