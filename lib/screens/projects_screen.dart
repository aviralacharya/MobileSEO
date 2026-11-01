import 'package:flutter/material.dart';

import '../controllers/workspace_controller.dart';
import '../services/audit_history_service.dart';
import '../services/audit_review.dart';
import '../services/project_service.dart';
import '../utils/page_identity.dart';
import '../widgets/app_widgets.dart';
import '../widgets/project_editor.dart';
import '../widgets/score_gauge.dart';
import 'audit_comparison_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.workspace,
    required this.onAudit,
    required this.onOpenAudit,
    required this.tabIndex,
    required this.onTabChanged,
  });
  final WorkspaceController workspace;
  final ValueChanged<String> onAudit;
  final ValueChanged<AuditHistoryEntry> onOpenAudit;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  final Set<String> _selected = {};
  String _query = '';
  String? _historyPage;
  bool _favorites = false, _needsAttention = false;
  int _days = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.tabIndex)
      ..addListener(_tabChanged);
  }

  void _tabChanged() {
    if (_tabs.index != widget.tabIndex) widget.onTabChanged(_tabs.index);
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabs.index != widget.tabIndex) _tabs.index = widget.tabIndex;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) _message('Could not update saved data. Please try again.');
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      ) ??
      false;

  void _select(AuditHistoryEntry entry) {
    if (_selected.contains(entry.id)) {
      setState(() => _selected.remove(entry.id));
      return;
    }
    final existing = widget.workspace.history
        .where((item) => _selected.contains(item.id))
        .toList();
    if (existing.length == 2) {
      _message('Choose two audits. Deselect one to change the comparison.');
      return;
    }
    if (existing.isNotEmpty &&
        !samePage(existing.first.result.url, entry.result.url)) {
      _message(
        'Choose audits of the same page URL, including its path and query.',
      );
      return;
    }
    setState(() => _selected.add(entry.id));
  }

  void _compare() {
    final entries =
        widget.workspace.history
            .where((entry) => _selected.contains(entry.id))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (entries.length != 2) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AuditComparisonScreen(before: entries.first, after: entries.last),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.workspace,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const BrandTitle(title: 'Projects'),
        actions: [
          IconButton(
            tooltip: 'Add project',
            onPressed: () => showProjectEditor(context, widget.workspace),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Saved projects'),
            Tab(text: 'Audit history'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: !widget.workspace.loaded
                ? const Center(child: CircularProgressIndicator())
                : widget.workspace.loadError != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: MessageCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'Saved data unavailable',
                      message: widget.workspace.loadError!,
                      action: FilledButton(
                        onPressed: widget.workspace.load,
                        child: const Text('Try again'),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: TextField(
                          controller: _search,
                          onChanged: (value) => setState(
                            () => _query = value.trim().toLowerCase(),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Search projects & URLs',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _search.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [_projects(), _history()],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );

  Widget _projects() {
    final projects =
        widget.workspace.projects
            .where(
              (project) =>
                  (!_favorites || project.favorite) &&
                  '${project.name} ${project.url}'.toLowerCase().contains(
                    _query,
                  ),
            )
            .toList()
          ..sort((a, b) {
            if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
            final ah = widget.workspace.historyFor(a.url);
            final bh = widget.workspace.historyFor(b.url);
            return (bh.isEmpty ? b.createdAt : bh.first.createdAt).compareTo(
              ah.isEmpty ? a.createdAt : ah.first.createdAt,
            );
          });
    return ListView(
      key: const PageStorageKey('projects-list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Favorites'),
              avatar: const Icon(Icons.star_outline_rounded, size: 18),
              selected: _favorites,
              onSelected: (value) => setState(() => _favorites = value),
            ),
            ActionChip(
              label: const Text('Add project'),
              avatar: const Icon(Icons.add_rounded, size: 18),
              onPressed: () => showProjectEditor(context, widget.workspace),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${widget.workspace.projects.length} saved projects · On this device',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (projects.isEmpty)
          MessageCard(
            icon: Icons.folder_open_rounded,
            title: widget.workspace.projects.isEmpty
                ? 'Your websites, organized'
                : 'No matching projects',
            message: widget.workspace.projects.isEmpty
                ? 'Save the pages you manage. Come back to your score, audit history and next fixes in one tap.'
                : 'Try another search or turn off the Favorites filter.',
            action: widget.workspace.projects.isEmpty
                ? FilledButton.icon(
                    onPressed: () =>
                        showProjectEditor(context, widget.workspace),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add your first project'),
                  )
                : null,
          ),
        for (final project in projects) ...[
          _projectCard(project),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _projectCard(SavedProject project) {
    final entries = widget.workspace.historyFor(project.url);
    final latest = entries.isEmpty ? null : entries.first;
    final theme = Theme.of(context);
    final favicon = latest?.result.indexation.faviconUrl;
    final active = latest == null
        ? project.inProgress.length
        : reviewAudit(latest.result)
              .where(
                (finding) =>
                    !finding.passed && project.inProgress.contains(finding.id),
              )
              .length;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (favicon == null)
                const IconBubble(icon: Icons.public_rounded)
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    favicon,
                    width: 38,
                    height: 38,
                    errorBuilder: (_, _, _) =>
                        const IconBubble(icon: Icons.public_rounded),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Project options',
                onSelected: (value) async {
                  if (value == 'edit') {
                    showProjectEditor(
                      context,
                      widget.workspace,
                      project: project,
                    );
                  }
                  if (value == 'remove' &&
                      await _confirm(
                        'Remove project?',
                        'Remove ${project.name} and its in-progress fixes? Audit snapshots stay in history.',
                      )) {
                    if (mounted) {
                      await _mutate(
                        () => widget.workspace.removeProject(project.url),
                      );
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit project')),
                  PopupMenuItem(value: 'remove', child: Text('Remove project')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (latest != null)
                Text(
                  '${latest.result.score}/100 · ${ScoreBand.of(latest.result.score).label}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: ScoreBand.of(latest.result.score).color(context),
                  ),
                )
              else
                const Text('Ready for a first audit'),
              if (active > 0)
                Text('$active in progress', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            latest == null
                ? 'Added ${formatAuditDate(project.createdAt)}'
                : 'Last audit ${formatAuditDate(latest.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => widget.onAudit(project.url),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(latest == null ? 'Run audit' : 'Re-audit'),
              ),
              if (latest != null)
                TextButton(
                  onPressed: () => widget.onOpenAudit(latest),
                  child: const Text('View latest'),
                ),
              TextButton(
                onPressed: () {
                  setState(() => _historyPage = project.url);
                  widget.onTabChanged(1);
                },
                child: const Text('History'),
              ),
              IconButton(
                tooltip: project.favorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: () =>
                    _mutate(() => widget.workspace.toggleFavorite(project.url)),
                icon: Icon(
                  project.favorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: project.favorite ? theme.colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _history() {
    final all = widget.workspace.history;
    final selectedCount = all
        .where((entry) => _selected.contains(entry.id))
        .length;
    final cutoff = DateTime.now().subtract(Duration(days: _days));
    final entries = all.where((entry) {
      final project = widget.workspace.projectFor(entry.result.url);
      return (_historyPage == null ||
              samePage(entry.result.url, _historyPage!)) &&
          (_days == 0 || !entry.createdAt.isBefore(cutoff)) &&
          (!_needsAttention ||
              reviewAudit(entry.result).any((finding) => !finding.passed)) &&
          '${entry.result.url} ${project?.name ?? ''}'.toLowerCase().contains(
            _query,
          );
    }).toList();
    return ListView(
      key: const PageStorageKey('history-list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: DropdownButton<int>(
                isExpanded: true,
                value: _days,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('All time')),
                  DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                  DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                ],
                onChanged: (value) => setState(() => _days = value ?? 0),
              ),
            ),
            FilterChip(
              label: const Text('Needs attention'),
              selected: _needsAttention,
              onSelected: (value) => setState(() => _needsAttention = value),
            ),
            if (_historyPage != null)
              InputChip(
                label: const Text('Selected page'),
                tooltip: _historyPage,
                onDeleted: () => setState(() => _historyPage = null),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${all.length} saved · Select two audits of the same page to compare.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (selectedCount > 0) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: selectedCount == 2 ? _compare : null,
                icon: const Icon(Icons.compare_arrows_rounded),
                label: Text('Compare ($selectedCount/2)'),
              ),
              TextButton(
                onPressed: () => setState(_selected.clear),
                child: const Text('Clear selection'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (entries.isEmpty)
          MessageCard(
            icon: Icons.history_rounded,
            title: all.isEmpty
                ? 'A record of your progress'
                : 'No matching audits',
            message: all.isEmpty
                ? 'Completed audits will appear here. Re-audit the same page to see what improved.'
                : 'Adjust the search, date or page filter to see more snapshots.',
          ),
        for (final entry in entries) ...[
          SectionCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _selected.contains(entry.id),
                      semanticLabel:
                          'Select ${entry.result.url}, ${formatAuditDate(entry.createdAt)} for comparison',
                      onChanged: (_) => _select(entry),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.workspace.projectFor(entry.result.url)?.name ??
                            entry.domain,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '${entry.result.score}/100',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                Text(
                  entry.result.url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  formatAuditDate(entry.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => widget.onOpenAudit(entry),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('View snapshot'),
                    ),
                    TextButton.icon(
                      onPressed: () => widget.onAudit(entry.result.url),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Re-audit'),
                    ),
                    IconButton(
                      tooltip: 'Delete audit',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        if (await _confirm(
                          'Remove this audit?',
                          'This snapshot and its comparison evidence will be removed from this device.',
                        )) {
                          if (!mounted) return;
                          await _mutate(
                            () => widget.workspace.deleteAudit(entry.id),
                          );
                          if (mounted) {
                            setState(() => _selected.remove(entry.id));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
