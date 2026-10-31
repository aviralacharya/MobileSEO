import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../services/seo_audit_service.dart';
import '../services/audit_history_service.dart';
import '../services/pdf_report_service.dart';
import '../services/site_files_checker.dart';
import '../widgets/app_widgets.dart';
import '../widgets/audit_history_widgets.dart';
import '../widgets/audit_cards.dart';
import '../widgets/fix_checklist.dart';
import '../widgets/score_gauge.dart';
import 'legal_pages.dart';

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
    required this.history,
    required this.onOpenHistory,
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

  final List<AuditHistoryEntry> history;
  final VoidCallback onOpenHistory;
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
  static const double _toolbarHeight = 68;
  static const double _expandedHeight = 236;

  late final TabController _tabs;
  late int _reportedIndex;
  late bool _searchExpanded;

  /// True only for a short window after a fresh audit, so card entrance
  /// animations play once instead of replaying on every tab visit.
  bool _animateCards = false;
  Timer? _cardAnimationTimer;

  @override
  void initState() {
    super.initState();
    _reportedIndex = widget.tabIndex;
    _tabs = TabController(length: 3, vsync: this, initialIndex: widget.tabIndex)
      ..addListener(_handleTabChange);
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
    if (widget.result != null && oldWidget.result?.url != widget.result?.url) {
      _scheduleCardAnimation();
    }
  }

  void _scheduleCardAnimation() {
    _cardAnimationTimer?.cancel();
    _animateCards = true;
    _cardAnimationTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _animateCards = false);
    });
  }

  @override
  void dispose() {
    _cardAnimationTimer?.cancel();
    _tabs.removeListener(_handleTabChange);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _sharePdf() async {
    final result = widget.result;
    if (result == null) return;
    try {
      final bytes = await const PdfReportService().buildReport(result);
      final host =
          Uri.tryParse(result.url)?.host
              .replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_') ??
          'audit';
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'mobile-seo-$host-report.pdf',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create or share the PDF report: $error'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _handleTabChange() {
    if (_tabs.index == _reportedIndex) return;
    _reportedIndex = _tabs.index;
    HapticFeedback.lightImpact();
    widget.onTabChanged(_reportedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final score = result?.scoreWithFixes(widget.checkedFixes.length) ?? 0;
    final domain = result == null
        ? 'MobileSEO'
        : (Uri.tryParse(result.url)?.host ?? result.url);
    final scheme = Theme.of(context).colorScheme;
    // Before the first audit there is no gauge to show, so keep the decorative
    // header short. This guarantees room for the tab body on small phones
    // (e.g. 320x568) where a tall header would push it out of the viewport.
    final expandedHeight = result == null ? 132.0 : _expandedHeight;

    return SafeArea(
      top: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: expandedHeight,
            collapsedHeight: _toolbarHeight,
            toolbarHeight: _toolbarHeight,
            titleSpacing: 16,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (result?.indexation.faviconUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      result!.indexation.faviconUrl!,
                      width: 22,
                      height: 22,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.public,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                Flexible(
                  child: Text(
                    domain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(width: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$score',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Audit history',
                onPressed: widget.onOpenHistory,
                icon: const Icon(Icons.history_rounded),
              ),
              if (result != null)
                IconButton(
                  tooltip: 'Share PDF report',
                  onPressed: _sharePdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
              const LegalMenuButton(),
              const ThemeModeToggle(),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final collapse =
                    ((constraints.maxHeight - _toolbarHeight) /
                            (expandedHeight - _toolbarHeight))
                        .clamp(0.0, 1.0);
                // Fade the gauge out before it can slide under the toolbar.
                final fade = ((collapse - 0.3) / 0.7).clamp(0.0, 1.0);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: fade < .05,
                        child: Opacity(
                          opacity: fade,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: result != null
                                  ? ScoreGauge(score: score, size: 112)
                                  : Image.asset(
                                      'assets/branding/mobileseo_icon.png',
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SliverToBoxAdapter(child: _searchHeader(context)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedTabsDelegate(
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'On-Page & Content'),
                  Tab(text: 'Technical & Links'),
                ],
              ),
              Theme.of(context).scaffoldBackgroundColor,
              scheme.outlineVariant,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [_bodyForTab(0), _bodyForTab(1), _bodyForTab(2)],
        ),
      ),
    );
  }

  /// The single search card, shared by all three tabs.
  Widget _searchHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _searchArea(context),
        ),
      ),
    ),
  );

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
    final media = MediaQuery.of(context);
    // On short screens or with large accessibility text, drop the explanatory
    // copy so the tab body still gets usable space below the pinned tabs.
    final compact = media.size.height < 640 || media.textScaler.scale(1) > 1.3;

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
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              'Paste a public URL and check the on-page SEO basics.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: compact ? 10 : 16),
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
              helperText: compact ? null : 'https:// is added automatically',
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
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.center,
                  children: [...previousChildren, ?currentChild],
                ),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: FittedBox(
                  key: ValueKey(widget.isLoading),
                  fit: BoxFit.scaleDown,
                  child: widget.isLoading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Auditing…'),
                          ],
                        )
                      : const Row(
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
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  Widget _bodyForTab(int index) {
    final child = switch (index) {
      1 => _onPageTab(context),
      2 => _technicalTab(context),
      _ => _overviewTab(context),
    };
    return _TabBody(stateKey: 'tab-$index', child: child);
  }

  Widget _overviewTab(BuildContext context) {
    if (widget.isLoading) return const AuditLoadingExperience();
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
        message: 'Enter a URL above to score the page and get a checklist of everything that is holding it back.',
      );
    }
    final fixedCount = widget.checkedFixes.length;
    final score = result.scoreWithFixes(fixedCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.history
                .where(
                  (e) =>
                      Uri.tryParse(e.result.url)?.host.toLowerCase() ==
                      Uri.tryParse(result.url)?.host.toLowerCase(),
                )
                .length >=
            2) ...[
          ScoreTrendChart(
            entries: widget.history
                .where(
                  (e) =>
                      Uri.tryParse(e.result.url)?.host.toLowerCase() ==
                      Uri.tryParse(result.url)?.host.toLowerCase(),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        AuditCardEntry(
          animateIn: _animateCards,
          index: 0,
          title: 'SEO health score',
          summary: '$score out of 100',
          why: 'The score summarizes the audit checks that affect how clearly search engines can understand the page.',
          steps: const [
            'Review failed checks below.',
            'Prioritize missing metadata and structural issues.',
            'Re-run the audit after publishing changes.',
          ],
          child: ScoreSummaryCard(
            result: result,
            score: score,
            fixedCount: fixedCount,
          ),
        ),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 1,
          title: 'Fix checklist',
          summary: '${result.failedChecks.length} items to review',
          why: 'Resolving on-page issues can improve search visibility and the experience for visitors.',
          steps: const [
            'Start with critical indexing and metadata problems.',
            'Make the change on your website.',
            'Re-run the audit to confirm it is fixed.',
          ],
          child: FixChecklist(
            fixes: result.failedChecks,
            checked: widget.checkedFixes,
            pointsPerFix: result.pointsPerFix,
            onToggle: widget.onToggleFix,
            onReset: widget.onResetFixes,
          ),
        ),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 2,
          title: 'Audit checks',
          summary: '${result.passedCount} of ${result.checks.length} passed',
          why: 'Each check points to page elements or signals that search engines use to interpret your content.',
          steps: const [
            'Review each failed check.',
            'Apply its recommended fix.',
            'Audit again to track the result.',
          ],
          child: _ScoreBreakdown(result: result, score: score),
        ),
      ],
    );
  }

  Widget _onPageTab(BuildContext context) {
    if (widget.isLoading) return const AuditLoadingExperience();
    final r = widget.result;
    if (r == null) {
      return const MessageCard(
        icon: Icons.description_outlined,
        title: 'No page audited yet',
        message: 'Run an audit and the title, description, headings and image alt text will appear here.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuditCardEntry(
          animateIn: _animateCards,
          index: 0,
          title: 'Meta title',
          summary: r.title ?? 'Missing',
          why: 'The title helps people and search engines identify the page in search results.',
          steps: const [
            'Write a unique descriptive title.',
            'Put the main topic near the start.',
            'Keep it concise and accurate.',
          ],
          fixType:
              (r.title == null || r.title!.length < 30 || r.title!.length > 60)
              ? 'title'
              : null,
          pageUrl: r.url,
          existingTitle: r.title ?? '',
          child: MetaCard(check: r.checks[0], icon: Icons.title_rounded),
        ),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 1,
          title: 'Meta description',
          summary: r.description ?? 'Missing',
          why: 'A useful description explains the page and encourages relevant searchers to visit.',
          steps: const [
            'Summarize the page accurately.',
            'Include the value for visitors.',
            'Avoid duplicates across pages.',
          ],
          fixType:
              (r.description == null ||
                  r.description!.length < 70 ||
                  r.description!.length > 160)
              ? 'description'
              : null,
          pageUrl: r.url,
          existingTitle: r.title ?? '',
          existingDescription: r.description ?? '',
          child: MetaCard(check: r.checks[1], icon: Icons.notes_rounded),
        ),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 2,
          title: 'Headings',
          summary: '${r.h1Count} H1 · ${r.h2Count} H2 · ${r.h3Count} H3',
          why: 'Heading structure makes content easier to scan and clarifies its hierarchy.',
          steps: const [
            'Use one clear H1.',
            'Use H2 and H3 for sections.',
            'Keep headings descriptive.',
          ],
          child: HeadingsCard(result: r),
        ),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 3,
          title: 'Content analyzer',
          summary: '${r.content.wordCount} words',
          why: 'Focused content helps visitors and search systems understand the page.',
          steps: const [
            'Answer visitor questions.',
            'Use relevant terms naturally.',
            'Avoid repetitive keyword use.',
          ],
          child: ContentAnalyzerCard(metrics: r.content),
        ),
        const SizedBox(height: 16),
        ReadabilityAccessibilityCard(report: r.readability),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 4,
          title: 'Image SEO',
          summary:
              '${r.imageReport.totalImages} images · ${r.imageReport.missingAltCount} missing alt',
          why: 'Descriptive alt text supports accessibility and helps search engines understand images.',
          steps: const [
            'Describe meaningful images.',
            'Use empty alt for decorative images.',
            'Optimize image size and format.',
          ],
          child: ImagesCard(report: r.imageReport),
        ),
      ],
    );
  }

  Widget _technicalTab(BuildContext context) {
    if (widget.isLoading) return const AuditLoadingExperience();
    final result = widget.result;
    if (result == null) {
      return const MessageCard(
        icon: Icons.build_circle_outlined,
        title: 'No page audited yet',
        message:
            'Schema markup, robots.txt, sitemap.xml, AI crawler access and '
            'link counts will appear here after an audit.',
      );
    }

    final siteFiles = widget.siteFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuditCardEntry(
          animateIn: _animateCards,
          index: 0,
          title: 'Indexation & identity',
          summary: result.indexation.blocksIndexing
              ? 'Indexing restriction found'
              : result.indexation.canonicalState(result.url),
          why: 'Robots directives and canonical URLs affect which URL search engines can index.',
          steps: const [
            'Remove noindex if the page should appear in search.',
            'Use a canonical URL that matches the preferred page.',
            'Set the HTML language and valid hreflang links.',
          ],
          fixType:
              (result.indexation.viewport == null ||
                  !result.indexation.viewport!.contains('width=device-width'))
              ? 'viewport'
              : null,
          pageUrl: result.url,
          existingTitle: result.title ?? '',
          child: IndexationCard(info: result.indexation, pageUrl: result.url),
        ),
        const SizedBox(height: 16),
        SecurityResponseCard(report: result.security),
        const SizedBox(height: 16),
        CoreWebVitalsCard(auditedUrl: result.url),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 1,
          title: 'Structured data',
          summary: result.schemaTypes.isNotEmpty
              ? result.schemaTypes.join(', ')
              : result.schemaScripts.isNotEmpty
              ? '${result.schemaScripts.length} JSON-LD block(s) found'
              : 'No schema detected',
          why: 'Structured data can help search engines interpret page entities and eligibility for rich results.',
          steps: const [
            'Choose a schema type that matches the content.',
            'Add valid JSON-LD markup.',
            'Validate the markup after publishing.',
          ],
          fixType:
              result.schemaTypes.isEmpty ||
                  result.schemaScripts.any((script) => !script.isValid)
              ? 'schema'
              : null,
          pageUrl: result.url,
          existingTitle: result.title ?? '',
          existingDescription: result.description ?? '',
          existingImage: result.openGraph.image ?? '',
          schemaTypes: result.schemaTypes,
          child: SchemaCard(result: result),
        ),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 2,
          title: 'Open Graph tags',
          summary: result.openGraph.isComplete
              ? 'Social preview tags complete'
              : '${result.openGraph.presentCount} of 3 tags present',
          why: 'Open Graph tags control the title, summary, and image shown when a page is shared.',
          steps: const [
            'Set a compelling og:title.',
            'Write a concise og:description.',
            'Use an absolute, crawlable og:image URL.',
          ],
          fixType: result.openGraph.isComplete ? null : 'open_graph',
          pageUrl: result.url,
          existingTitle: result.openGraph.title ?? result.title ?? '',
          existingDescription:
              result.openGraph.description ?? result.description ?? '',
          existingImage: result.openGraph.image ?? '',
          child: OpenGraphCard(report: result.openGraph),
        ),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 3,
          title: 'Links',
          summary: result.linkAudit.summary,
          why: 'Internal links help visitors and crawlers discover related pages; external links provide references.',
          steps: const [
            'Link important pages from relevant content.',
            'Use descriptive anchor text.',
            'Scan a sample of links for dead destinations.',
          ],
          child: LinksCard(audit: result.linkAudit),
        ),
        const SizedBox(height: 16),
        if (siteFiles != null)
          AuditCardEntry(
            animateIn: _animateCards,
            index: 3,
            title: 'Robots and sitemap',
            summary: '${siteFiles.passedCount} of 2 files found',
            why: 'Robots and sitemap files help crawlers understand crawl guidance and discover URLs.',
            steps: const [
              'Ensure robots.txt is available at the site root.',
              'Publish a valid XML sitemap.',
              'Reference the sitemap in robots.txt.',
            ],
            child: SiteFilesCard(report: siteFiles),
          )
        else
          const LoadingCard(message: 'Checking robots.txt and sitemap.xml…'),
        const SizedBox(height: 16),
        if (siteFiles != null)
          AIReadinessCard(report: siteFiles.aiReadiness)
        else
          const LoadingCard(
            message: 'Checking AI crawler access and llms.txt…',
          ),
      ],
    );
  }
}

class _PinnedTabsDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedTabsDelegate(this.tabBar, this.background, this.borderColor);
  final TabBar tabBar;
  final Color background;
  final Color borderColor;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: background,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: borderColor.withValues(alpha: overlapsContent ? 1 : .5),
          ),
        ),
      ),
      child: tabBar,
    ),
  );
  @override
  bool shouldRebuild(covariant _PinnedTabsDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar ||
      oldDelegate.background != background ||
      oldDelegate.borderColor != borderColor;
}

/// Scrollable, width-limited container shared by the three tabs.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.stateKey, required this.child});

  final String stateKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: PageStorageKey<String>(stateKey),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
