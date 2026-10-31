import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/seo_audit_service.dart';
import '../services/audit_history_service.dart';
import '../services/seo_extractor.dart';
import '../services/seo_scraper_service.dart';
import '../services/site_files_checker.dart';
import '../utils/url_validator.dart';
import '../widgets/app_sheet.dart';
import '../widgets/audit_history_widgets.dart';
import 'audit_dashboard_screen.dart';
import 'competitor_compare_screen.dart';
import 'serp_preview_screen.dart';

/// Root of the app: three destinations plus the audit state they share.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final TextEditingController _urlController = TextEditingController();
  final SiteFilesChecker _siteFilesChecker = SiteFilesChecker();
  static const SeoAuditService _auditService = SeoAuditService();
  final AuditHistoryService _historyService = AuditHistoryService();
  final PageController _pageController = PageController();
  List<AuditHistoryEntry> _history = const [];

  /// Labels of the checklist items ticked in the Overview tab.
  final Set<String> _checkedFixes = <String>{};

  int _destination = 0;
  int _tabIndex = 0;
  bool _isLoading = false;
  String? _urlError;
  String? _errorMessage;
  SeoErrorKind? _errorKind;
  SeoAuditResult? _result;
  SiteFilesReport? _siteFiles;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final items = await _historyService.load();
      if (mounted) setState(() => _history = items);
    } catch (_) {}
  }

  Future<void> _openHistory() async {
    final picked = await AppSheet.show<AuditHistoryEntry>(
      context: context,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: AuditHistoryList(
          entries: _history,
          onDelete: (id) async {
            final items = await _historyService.delete(id);
            if (mounted) setState(() => _history = items);
            return items;
          },
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _result = picked.result;
      _siteFiles = picked.siteFiles;
      _urlController.text = picked.result.url;
      _destination = 0;
      _tabIndex = 0;
      _errorMessage = null;
      _errorKind = null;
      _urlError = null;
      _checkedFixes.clear();
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _urlController.dispose();
    _siteFilesChecker.close();
    super.dispose();
  }

  void _selectDestination(int index) {
    if (index == _destination) return;
    FocusScope.of(context).unfocus();
    setState(() => _destination = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _runAudit() async {
    if (_isLoading) return;

    // 1. Validate locally — bad input never reaches the network.
    final validation = UrlValidator.validate(_urlController.text);
    if (!validation.isValid) {
      setState(() {
        _urlError = validation.message;
        _errorMessage = null;
        _errorKind = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _urlError = null;
      _errorMessage = null;
      _errorKind = null;
      _siteFiles = null;
      _checkedFixes.clear();
      _tabIndex = 0;
    });

    // The two crawl-file checks only need the host, so they can run while the
    // page itself is still downloading.
    final filesFuture = _siteFilesChecker.check(validation.uri!);

    try {
      // 2. extractSeo never throws: timeouts, 404s, 500s, blocked sites and
      //    non-HTML responses all come back as a failed snapshot.
      final snapshot = await extractSeo(validation.uri.toString());
      if (!mounted) return;

      if (!snapshot.isSuccess) {
        setState(() {
          _result = null;
          _errorMessage = snapshot.error;
          _errorKind = snapshot.errorKind;
        });
        _showErrorSnackBar(
          snapshot.error ?? 'The audit could not be completed.',
          retryable: _isRetryable(snapshot.errorKind),
        );
        return;
      }

      final siteFiles = await filesFuture;
      if (!mounted) return;
      final audited = _auditService.analyzeSnapshot(snapshot);
      setState(() {
        _result = audited;
        _siteFiles = siteFiles;
        _errorMessage = null;
        _errorKind = null;
      });
      try {
        final items = await _historyService.add(audited, siteFiles);
        if (mounted) setState(() => _history = items);
      } catch (error) {
        debugPrint('Could not save history: $error');
      }
      HapticFeedback.mediumImpact();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _errorMessage = 'Something went wrong while auditing this page.';
        _errorKind = SeoErrorKind.unknown;
      });
      _showErrorSnackBar('Something went wrong while auditing this page.');
      debugPrint('Audit failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Transient problems are worth another attempt; a 404 or a block is not.
  static bool _isRetryable(SeoErrorKind? kind) {
    return kind == null ||
        kind == SeoErrorKind.timeout ||
        kind == SeoErrorKind.network ||
        kind == SeoErrorKind.serverError;
  }

  void _showErrorSnackBar(String message, {bool retryable = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: retryable
              ? SnackBarAction(label: 'Retry', onPressed: _runAudit)
              : null,
        ),
      );
  }

  void _toggleFix(String label) {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_checkedFixes.remove(label)) {
        _checkedFixes.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          if (index != _destination) setState(() => _destination = index);
        },
        children: [
          _KeepAlivePage(
            enabled: _destination == 0,
            child: AuditDashboardScreen(
              urlController: _urlController,
              isLoading: _isLoading,
              urlError: _urlError,
              errorMessage: _errorMessage,
              canRetry: _isRetryable(_errorKind),
              result: _result,
              siteFiles: _siteFiles,
              checkedFixes: _checkedFixes,
              tabIndex: _tabIndex,
              onRun: _runAudit,
              history: _history,
              onOpenHistory: _openHistory,
              onRetry: _runAudit,
              onUrlEdited: () {
                if (_urlError != null) setState(() => _urlError = null);
              },
              onToggleFix: _toggleFix,
              onResetFixes: () => setState(_checkedFixes.clear),
              onTabChanged: (index) {
                if (index != _tabIndex) setState(() => _tabIndex = index);
              },
            ),
          ),
          _KeepAlivePage(
            enabled: _destination == 1,
            child: SerpPreviewScreen(
              result: _result,
              onGoToAudit: () => _selectDestination(0),
            ),
          ),
          _KeepAlivePage(
            enabled: _destination == 2,
            child: CompetitorCompareScreen(
              result: _result,
              onGoToAudit: () => _selectDestination(0),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destination,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Previews',
          ),
          NavigationDestination(
            icon: Icon(Icons.compare_arrows_outlined),
            selectedIcon: Icon(Icons.compare_arrows_rounded),
            label: 'Compare',
          ),
        ],
      ),
    );
  }
}

/// Keeps a destination alive while it is off-screen and pauses its tickers so
/// background shimmer/gauge animations do not keep repainting.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TickerMode(enabled: widget.enabled, child: widget.child);
  }
}
