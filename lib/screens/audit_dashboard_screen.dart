import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/audit_controller.dart';
import '../services/app_settings.dart';
import '../services/audit_review.dart';
import '../services/incoming_share_service.dart';
import '../services/seo_audit_service.dart';
import '../services/audit_history_service.dart';
import '../services/site_files_checker.dart';
import '../utils/page_identity.dart';
import '../widgets/app_widgets.dart';
import '../widgets/audit_history_widgets.dart';
import '../widgets/audit_cards.dart';
import '../widgets/fix_checklist.dart';
import '../widgets/guided_audit_card.dart';
import '../widgets/shared_pages_card.dart';
import '../widgets/score_gauge.dart';
import '../widgets/report_export_sheet.dart';
import 'audit_comparison_screen.dart';

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
    this.phase = AuditPhase.fetching,
    this.source = AuditSource.live,
    this.auditedAt,
    this.previousAudit,
    this.siteFilesLoading = false,
    this.siteFilesError,
    this.saveWarning,
    this.isSaving = false,
    this.onCancel,
    this.onRetryFiles,
    this.onRetrySave,
    this.onLoadSample,
    this.onSaveProject,
    this.onReaudit,
    this.projectName = '',
    this.isSavedProject = false,
    this.canTrackFixes = true,
    this.inputRevision = 0,
    this.sharedDraft = false,
    this.incomingShare,
    this.onSelectShared,
    this.onDismissShared,
  });

  final TextEditingController urlController;
  final bool isLoading;
  final String? urlError;
  final String? errorMessage;
  final bool canRetry;
  final int inputRevision;
  final bool sharedDraft;
  final SharedPages? incomingShare;
  final ValueChanged<Uri>? onSelectShared;
  final VoidCallback? onDismissShared;
  final SeoAuditResult? result;
  final SiteFilesReport? siteFiles;

  /// IDs of findings the user is working on; never measured as passing.
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
  final AuditPhase phase;
  final AuditSource source;
  final DateTime? auditedAt;
  final AuditHistoryEntry? previousAudit;
  final bool siteFilesLoading, isSavedProject, canTrackFixes, isSaving;
  final String? siteFilesError, saveWarning;
  final String projectName;
  final VoidCallback? onCancel,
      onRetryFiles,
      onRetrySave,
      onLoadSample,
      onSaveProject,
      onReaudit;

  @override
  State<AuditDashboardScreen> createState() => _AuditDashboardScreenState();
}

class _AuditDashboardScreenState extends State<AuditDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late int _reportedIndex;
  late bool _searchExpanded;
  final _outerScroll = ScrollController();
  final _urlFocus = FocusNode();
  String? _guidedFindingId, _guidedPage;
  bool _guidedSample = false;

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
    if (widget.tabIndex != _tabs.index) _tabs.index = widget.tabIndex;
    // Collapse the form once a fresh result arrives, expand it again if the
    // result was cleared by an error.
    if (oldWidget.result == null && widget.result != null) {
      _searchExpanded = false;
    } else if (oldWidget.result != null && widget.result == null) {
      _searchExpanded = true;
    }
    if (widget.result != null && !identical(oldWidget.result, widget.result)) {
      _scheduleCardAnimation();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _outerScroll.hasClients) _outerScroll.jumpTo(0);
      });
    }
    if (widget.inputRevision != oldWidget.inputRevision) {
      _searchExpanded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _outerScroll.hasClients) _outerScroll.jumpTo(0);
      });
    }
    if (widget.source == AuditSource.sample &&
        !identical(oldWidget.result, widget.result)) {
      _guidedFindingId = _guidedPage = null;
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
    _outerScroll.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  String get _sourceLabel => switch (widget.source) {
    AuditSource.live => 'Live audit',
    AuditSource.saved => 'Saved snapshot',
    AuditSource.sample => 'Sample audit',
  };

  Future<void> _shareReport() async {
    final result = widget.result;
    if (result == null) return;
    await showReportExport(
      context,
      result: result,
      source: _sourceLabel,
      auditedAt: widget.auditedAt,
      before: widget.previousAudit,
      siteFiles: widget.siteFiles,
      inProgress: widget.checkedFixes,
      projectName: widget.projectName,
    );
  }

  void _handleTabChange() {
    if (_tabs.index == _reportedIndex) return;
    _reportedIndex = _tabs.index;
    SettingsScope.of(context).feedback();
    widget.onTabChanged(_reportedIndex);
  }

  Future<void> _hideGuide() async {
    try {
      await SettingsScope.of(context).update(showAuditGuide: false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the guide preference. Try again.'),
          ),
        );
      }
    }
  }

  void _useOwnPage() {
    setState(() => _searchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_outerScroll.hasClients) _outerScroll.jumpTo(0);
      _urlFocus.requestFocus();
    });
  }

  void _openFinding(AuditFinding finding) {
    final result = widget.result;
    if (result == null) return;
    if (!finding.passed) {
      setState(() {
        _guidedFindingId = finding.id;
        _guidedPage = result.url;
        _guidedSample = widget.source == AuditSource.sample;
      });
    }
    // Capture this page's callback so later navigation cannot recheck another URL.
    final recheck = widget.onReaudit;
    showFindingDetails(
      context,
      finding,
      result,
      isSample: widget.source == AuditSource.sample,
      onReaudit: recheck == null
          ? null
          : () {
              if (mounted) recheck();
            },
    );
  }

  void _openFindingId(String id) {
    final result = widget.result;
    if (result == null) return;
    final finding = reviewAudit(result)
        .where((item) => item.id == id)
        .firstOrNull;
    if (finding != null) _openFinding(finding);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final score = result?.score ?? 0;
    final domain = result == null
        ? 'MobileSEO'
        : (Uri.tryParse(result.url)?.host ?? result.url);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: NestedScrollView(
        controller: _outerScroll,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            titleSpacing: 16,
            title: BrandTitle(
              title: domain,
              trailing: result == null
                  ? null
                  : Container(
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
                        semanticsLabel: 'Measured score $score out of 100',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
            ),
            actions: [
              IconButton(
                tooltip: 'Audit history',
                onPressed: widget.onOpenHistory,
                icon: const Icon(Icons.history_rounded),
              ),
              if (result != null)
                IconButton(
                  tooltip: 'Export report',
                  onPressed: _shareReport,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
            ],
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
        child: MotionAwareSize(child: _searchArea(context)),
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Search form
  // ---------------------------------------------------------------------------

  Widget _searchArea(BuildContext context) {
    final compact = widget.result != null && !_searchExpanded;
    final search = compact ? _compactSearch(context) : _fullSearch(context);
    if (widget.incomingShare == null) return search;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SharedPagesCard(
          pages: widget.incomingShare!,
          auditRunning: widget.isLoading,
          onSelect: widget.onSelectShared ?? (_) {},
          onDismiss: widget.onDismissShared ?? () {},
        ),
        const SizedBox(height: 12),
        search,
      ],
    );
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
          if (widget.sharedDraft) ...[
            Text(
              'Shared link ready · Run the audit when you’re ready.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: widget.urlController,
            focusNode: _urlFocus,
            keyboardType: TextInputType.url,
            enabled: !widget.isLoading,
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
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
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
    final Widget child;
    if (widget.isLoading && widget.result == null) {
      child = AuditLoadingExperience(
        phase: widget.phase,
        onCancel: widget.onCancel,
      );
    } else if (widget.errorMessage != null) {
      child = ErrorCard(
        message: widget.errorMessage!,
        onRetry: widget.canRetry ? widget.onRetry : null,
      );
    } else {
      child = switch (index) {
        1 => _onPageTab(context),
        2 => _technicalTab(context),
        _ => _overviewTab(context),
      };
    }
    return _TabBody(
      stateKey: 'tab-$index-${widget.result?.hashCode ?? 'empty'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isLoading && widget.result != null) ...[
            AuditLoadingExperience(
              phase: widget.phase,
              onCancel: widget.onCancel,
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _overviewTab(BuildContext context) {
    final result = widget.result;
    final settings = SettingsScope.of(context);
    if (result == null) {
      if (settings.showAuditGuide && widget.phase != AuditPhase.cancelled) {
        return FirstAuditCard(
          onSample: widget.onLoadSample,
          onDismiss: settings.saving ? null : _hideGuide,
        );
      }
      return MessageCard(
        icon: Icons.travel_explore_rounded,
        title: widget.phase == AuditPhase.cancelled
            ? 'Audit cancelled'
            : 'Ready when you are',
        message: widget.phase == AuditPhase.cancelled
            ? 'Your request was stopped. Run the audit again when you are ready.'
            : 'See how your page is doing, prioritize the next fix and track your progress.',
        action: widget.onLoadSample == null
            ? null
            : TextButton.icon(
                onPressed: widget.onLoadSample,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Explore sample audit'),
              ),
      );
    }
    final score = result.score;
    final findings = reviewAudit(result);
    final comparison = widget.previousAudit == null
        ? null
        : AuditComparison(before: widget.previousAudit!.result, after: result);
    final pageHistory = widget.history
        .where(
          (entry) =>
              samePage(entry.result.url, result.url) &&
              (widget.auditedAt == null ||
                  !entry.createdAt.isAfter(widget.auditedAt!)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: Icon(switch (widget.source) {
                AuditSource.live => Icons.check_circle_outline_rounded,
                AuditSource.saved => Icons.history_rounded,
                AuditSource.sample => Icons.science_outlined,
              }, size: 18),
              label: Text(_sourceLabel),
            ),
            if (widget.auditedAt != null)
              Text(
                formatAuditDate(widget.auditedAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        if (widget.source == AuditSource.sample)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'An offline example to explore. Sample tasks are temporary and stay out of your real projects and history.',
            ),
          ),
        if (settings.showAuditGuide) ...[
          const SizedBox(height: 12),
          GuidedAuditCard(
            result: result,
            isSample: widget.source == AuditSource.sample,
            reviewedFindingId:
                _guidedPage != null &&
                    samePage(_guidedPage!, result.url) &&
                    _guidedSample == (widget.source == AuditSource.sample)
                ? _guidedFindingId
                : null,
            comparison: comparison,
            onOpenFinding: _openFinding,
            onUseOwnPage: _useOwnPage,
            onReaudit: widget.onReaudit,
            onSaveProject: widget.isSavedProject ? null : widget.onSaveProject,
            onDismiss: settings.saving ? null : _hideGuide,
            busy: widget.isLoading,
          ),
          const SizedBox(height: 12),
        ],
        if (widget.saveWarning != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.saveWarning!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (widget.onRetrySave != null)
                  TextButton.icon(
                    onPressed: widget.isSaving ? null : widget.onRetrySave,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(widget.isSaving ? 'Saving…' : 'Retry save'),
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (widget.onReaudit != null)
              FilledButton.tonalIcon(
                onPressed: widget.isLoading ? null : widget.onReaudit,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Re-audit page'),
              ),
            if (widget.onSaveProject != null)
              TextButton.icon(
                onPressed: widget.onSaveProject,
                icon: Icon(
                  widget.isSavedProject
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_add_outlined,
                  size: 18,
                ),
                label: Text(
                  widget.isSavedProject ? 'Project saved' : 'Save project',
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 0,
          title: 'Measured SEO score',
          summary: '$score out of 100',
          why: 'The score summarizes the audit checks that affect how clearly search engines can understand the page.',
          steps: const [
            'Review failed checks below.',
            'Prioritize missing metadata and structural issues.',
            'Re-run the audit after publishing changes.',
          ],
          child: ScoreSummaryCard(
            result: result,
            projectedScore: projectedAuditScore(result, widget.checkedFixes),
            selectedCoreChecks: selectedCoreFixes(result, widget.checkedFixes),
          ),
        ),
        FindingCounts(findings: findings),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 1,
          showDetails: false,
          title: 'Your next best fixes',
          summary: '',
          why: '',
          steps: const [],
          child: TopRecommendations(
            result: result,
            onOpenFinding: _openFinding,
          ),
        ),
        const SizedBox(height: 16),
        if (comparison != null) ...[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Since the previous audit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ComparisonCounts(comparison: comparison),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AuditComparisonScreen(
                        before: widget.previousAudit!,
                        after: AuditHistoryEntry(
                          id: 'current',
                          createdAt: widget.auditedAt!,
                          result: result,
                          siteFiles: widget.siteFiles,
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                  label: const Text('View before & after'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        AuditCardEntry(
          animateIn: _animateCards,
          index: 2,
          showDetails: false,
          title: 'Fix checklist',
          summary: '${result.failedChecks.length} items to review',
          why: 'Resolving on-page issues can improve search visibility and the experience for visitors.',
          steps: const [
            'Start with critical indexing and metadata problems.',
            'Make the change on your website.',
            'Re-run the audit to confirm it is fixed.',
          ],
          child: FixChecklist(
            result: result,
            inProgress: widget.checkedFixes,
            verified:
                comparison?.resolved.map((finding) => finding.id).toSet() ?? {},
            onToggle: widget.onToggleFix,
            onReset: widget.onResetFixes,
            onReaudit: widget.isLoading ? null : widget.onReaudit,
            readOnly: !widget.canTrackFixes,
            onOpenFinding: _openFinding,
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ExpansionTile(
            key: const PageStorageKey('score-trend'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Score trend & core checks'),
            children: [
              if (pageHistory.length >= 2) ...[
                ScoreTrendChart(entries: pageHistory),
                const SizedBox(height: 12),
              ],
              _ScoreBreakdown(result: result, score: score),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _onPageTab(BuildContext context) {
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
          onDetails: () => _openFindingId('Meta title'),
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
          onDetails: () => _openFindingId('Meta description'),
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
          onDetails: () =>
              _openFindingId(r.h1Count == 1 ? 'H2 headings' : 'H1 heading'),
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
          onDetails: () => _openFindingId('Image SEO'),
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
          onDetails: () => _openFindingId(
            result.indexation.blocksIndexing
                ? 'Indexing directives'
                : 'Mobile viewport',
          ),
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
        CoreWebVitalsCard(
          key: ValueKey(result),
          auditedUrl: result.url,
          localFetchTimeMs: result.security.responseTimeMs,
          enabled: widget.source != AuditSource.sample,
        ),
        const SizedBox(height: 16),
        AuditCardEntry(
          animateIn: _animateCards,
          index: 1,
          title: 'Structured data',
          onDetails: () => _openFindingId('Schema markup'),
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
          onDetails: () => _openFindingId('Social sharing'),
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
          child: LinksCard(
            key: ValueKey(result),
            audit: result.linkAudit,
            enabled: widget.source != AuditSource.sample,
          ),
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
        else if (widget.siteFilesLoading)
          const LoadingCard(message: 'Checking robots.txt and sitemap.xml…'),
        const SizedBox(height: 16),
        if (widget.siteFilesError != null)
          ErrorCard(
            message: widget.siteFilesError!,
            onRetry: widget.siteFilesLoading ? null : widget.onRetryFiles,
          ),
        if (siteFiles == null &&
            !widget.siteFilesLoading &&
            widget.siteFilesError == null)
          const MessageCard(
            icon: Icons.cloud_off_outlined,
            title: 'Site checks unavailable',
            message: 'These checks were not recorded for this snapshot. Re-audit the page for current results.',
          ),
        if (widget.source == AuditSource.live && widget.onRetryFiles != null)
          TextButton.icon(
            onPressed: widget.siteFilesLoading ? null : widget.onRetryFiles,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry site-file checks'),
          ),
        if (siteFiles != null)
          AIReadinessCard(report: siteFiles.aiReadiness)
        else if (widget.siteFilesLoading)
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
class _TabBody extends StatefulWidget {
  const _TabBody({required this.stateKey, required this.child});

  final String stateKey;
  final Widget child;

  @override
  State<_TabBody> createState() => _TabBodyState();
}

class _TabBodyState extends State<_TabBody> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      key: PageStorageKey<String>(widget.stateKey),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: widget.child,
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
                  'Core score breakdown',
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
