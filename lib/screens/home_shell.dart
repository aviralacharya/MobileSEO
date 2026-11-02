import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/audit_controller.dart';
import '../controllers/workspace_controller.dart';
import '../services/app_settings.dart';
import '../services/audit_history_service.dart';
import '../services/audit_review.dart';
import '../services/incoming_share_service.dart';
import '../utils/url_validator.dart';
import '../widgets/project_editor.dart';
import '../widgets/report_export_sheet.dart';
import 'audit_dashboard_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';

/// Stateful destinations share an owned audit run and an on-device workspace.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.workspace, this.audit});
  final WorkspaceController? workspace;
  final AuditController? audit;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _urlController = TextEditingController();
  final _pageController = PageController();
  final _incomingShares = IncomingShareService();
  StreamSubscription<SharedPages>? _shareSubscription;
  SharedPages? _pendingShare;
  bool _sharedDraft = false;
  int _inputRevision = 0;
  late final _workspace = widget.workspace ?? WorkspaceController();
  late final _audit = widget.audit ?? AuditController(workspace: _workspace);
  late final _changes = Listenable.merge([_workspace, _audit]);
  final Set<String> _sampleFixes = {};
  int _destination = 0, _tabIndex = 0, _projectsTab = 0;
  String? _urlError;
  AuditPhase _previousPhase = AuditPhase.idle;
  AppSettings _settings = AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _workspace.load().ignore();
    _audit.addListener(_auditChanged);
    _shareSubscription = _incomingShares.shares.listen(_receiveShare);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _incomingShares.start().ignore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = SettingsScope.of(context);
  }

  void _auditChanged() {
    if (_audit.phase == AuditPhase.complete &&
        _previousPhase != AuditPhase.complete &&
        _audit.source == AuditSource.live) {
      _settings.feedback(completed: true);
    }
    _previousPhase = _audit.phase;
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _incomingShares.dispose();
    _audit.removeListener(_auditChanged);
    if (widget.audit == null) _audit.dispose();
    if (widget.workspace == null) _workspace.dispose();
    _urlController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _selectDestination(int index) {
    if (index == _destination) return;
    FocusScope.of(context).unfocus();
    _settings.feedback();
    setState(() => _destination = index);
    if (!_pageController.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openHistory() {
    setState(() => _projectsTab = 1);
    _selectDestination(1);
  }

  void _openAudit(AuditHistoryEntry entry) {
    _audit.restore(entry);
    _urlController.text = entry.result.url;
    setState(() {
      _urlError = null;
      _tabIndex = 0;
      _sharedDraft = false;
      _pendingShare = null;
    });
    _selectDestination(0);
  }

  Future<void> _runAudit() async {
    if (_audit.running) return;
    final validation = UrlValidator.validate(_urlController.text);
    if (!validation.isValid) {
      setState(() => _urlError = validation.message);
      return;
    }
    FocusScope.of(context).unfocus();
    _urlController.text = validation.uri.toString();
    setState(() {
      _urlError = null;
      _tabIndex = 0;
      _sharedDraft = false;
      _pendingShare = null;
    });
    await _audit.run(validation.uri!);
  }

  void _auditUrl(String url) {
    _audit.cancel();
    _urlController.text = url;
    _selectDestination(0);
    _runAudit();
  }

  void _showSample() {
    _sampleFixes.clear();
    _audit.showSample();
    _urlController.clear();
    setState(() {
      _tabIndex = 0;
      _urlError = null;
      _sharedDraft = false;
      _pendingShare = null;
    });
    _selectDestination(0);
  }

  void _receiveShare(SharedPages pages) {
    if (!mounted) return;
    if (pages.urls.length == 1 && !_audit.running) {
      _prepareSharedUrl(pages.urls.single);
    } else {
      setState(() {
        _pendingShare = pages;
        _sharedDraft = false;
        _inputRevision++;
        _tabIndex = 0;
      });
      _selectDestination(0);
    }
    // A shared link must not silently dismiss an editor or report sheet.
    if (ModalRoute.of(context)?.isCurrent == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A shared link is ready on the Dashboard.'),
        ),
      );
    }
  }

  void _prepareSharedUrl(Uri url) {
    _urlController.text = url.toString();
    setState(() {
      _urlError = null;
      _pendingShare = null;
      _sharedDraft = true;
      _inputRevision++;
      _tabIndex = 0;
    });
    _selectDestination(0);
  }

  void _selectSharedUrl(Uri url) {
    if (_audit.running) {
      // Only the explicit "Audit shared page" action supersedes an active run.
      _auditUrl(url.toString());
    } else {
      _prepareSharedUrl(url);
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      _settings.feedback();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this change. Please try again.'),
          ),
        );
      }
    }
  }

  void _toggleFix(String finding) {
    final result = _audit.result;
    if (result == null) return;
    if (_audit.source == AuditSource.sample) {
      setState(() {
        if (!_sampleFixes.remove(finding)) _sampleFixes.add(finding);
      });
      _settings.feedback();
    } else {
      _mutate(() => _workspace.toggleFinding(result.url, finding));
    }
  }

  void _resetFixes() {
    if (_audit.source == AuditSource.sample) {
      setState(_sampleFixes.clear);
    } else if (_audit.result != null) {
      _mutate(() => _workspace.resetFindings(_audit.result!.url));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) {
      final result = _audit.result;
      final sample = _audit.source == AuditSource.sample;
      final project = result == null || sample
          ? null
          : _workspace.projectFor(result.url);
      final previous = result == null || _audit.auditedAt == null
          ? null
          : _workspace.previousFor(result.url, _audit.auditedAt!);
      final history = result == null
          ? <AuditHistoryEntry>[]
          : _workspace.historyFor(result.url);
      final canTrack =
          _audit.source != AuditSource.saved ||
          (history.isNotEmpty && history.first.id == _audit.entryId);
      final unresolved = result == null
          ? <String>{}
          : reviewAudit(result)
                .where((finding) => !finding.passed)
                .map((finding) => finding.id)
                .toSet();
      final fixes = sample
          ? _sampleFixes
          : canTrack
          ? (project?.inProgress ?? <String>{}).intersection(unresolved)
          : <String>{};
      return Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _KeepAlivePage(
              enabled: _destination == 0,
              child: AuditDashboardScreen(
                urlController: _urlController,
                isLoading: _audit.running,
                urlError: _urlError,
                errorMessage: _audit.errorMessage,
                canRetry: _audit.canRetry,
                result: result,
                siteFiles: _audit.siteFiles,
                checkedFixes: fixes,
                tabIndex: _tabIndex,
                onRun: _runAudit,
                history: sample ? const [] : _workspace.history,
                onOpenHistory: _openHistory,
                onRetry: _runAudit,
                onUrlEdited: () {
                  if (_urlError != null || _sharedDraft) {
                    setState(() {
                      _urlError = null;
                      _sharedDraft = false;
                    });
                  }
                },
                inputRevision: _inputRevision,
                sharedDraft: _sharedDraft,
                incomingShare: _pendingShare,
                onSelectShared: _selectSharedUrl,
                onDismissShared: () => setState(() => _pendingShare = null),
                onToggleFix: _toggleFix,
                onResetFixes: _resetFixes,
                onTabChanged: (index) {
                  if (index != _tabIndex) setState(() => _tabIndex = index);
                },
                phase: _audit.phase,
                source: _audit.source,
                auditedAt: _audit.auditedAt,
                previousAudit: previous,
                siteFilesLoading: _audit.filesLoading,
                siteFilesError: _audit.filesError,
                saveWarning: _audit.saveError,
                isSaving: _audit.saving,
                onCancel: _audit.cancel,
                onRetryFiles: _audit.retryFiles,
                onRetrySave: _audit.retrySave,
                onLoadSample: _showSample,
                onSaveProject: result == null || sample
                    ? null
                    : () => showProjectEditor(
                        context,
                        _workspace,
                        project: project,
                        initialUrl: result.url,
                      ),
                onReaudit: result == null || sample
                    ? null
                    : () => _auditUrl(result.url),
                projectName: project?.name ?? '',
                isSavedProject: project != null,
                canTrackFixes: canTrack,
              ),
            ),
            _KeepAlivePage(
              enabled: _destination == 1,
              child: ProjectsScreen(
                workspace: _workspace,
                onAudit: _auditUrl,
                onOpenAudit: _openAudit,
                tabIndex: _projectsTab,
                onTabChanged: (index) {
                  if (index != _projectsTab) {
                    setState(() => _projectsTab = index);
                  }
                },
              ),
            ),
            _KeepAlivePage(
              enabled: _destination == 2,
              child: ToolsScreen(
                active: _destination == 2,
                result: result,
                isSample: sample,
                onGoToAudit: () => _selectDestination(0),
                onSample: _showSample,
                onOpenTab: (index) {
                  setState(() => _tabIndex = index);
                  _selectDestination(0);
                },
                onReport: result == null
                    ? null
                    : () => showReportExport(
                        context,
                        result: result,
                        source: switch (_audit.source) {
                          AuditSource.live => 'Live audit',
                          AuditSource.saved => 'Saved snapshot',
                          AuditSource.sample => 'Sample audit',
                        },
                        auditedAt: _audit.auditedAt,
                        before: previous,
                        siteFiles: _audit.siteFiles,
                        inProgress: fixes,
                        projectName: project?.name ?? '',
                      ),
              ),
            ),
            _KeepAlivePage(
              enabled: _destination == 3,
              child: SettingsScreen(workspace: _workspace),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _destination,
          onDestinationSelected: _selectDestination,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder_rounded),
              label: 'Projects',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Tools',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      );
    },
  );
}

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
