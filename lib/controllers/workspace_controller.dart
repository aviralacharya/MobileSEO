import 'package:flutter/foundation.dart';

import '../services/audit_history_service.dart';
import '../services/audit_review.dart';
import '../services/project_service.dart';
import '../services/seo_audit_service.dart';
import '../services/site_files_checker.dart';
import '../utils/page_identity.dart';
import '../utils/url_validator.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({AuditHistoryService? history, ProjectService? projects})
    : _historyService = history ?? AuditHistoryService(),
      _projectService = projects ?? ProjectService();

  final AuditHistoryService _historyService;
  final ProjectService _projectService;
  List<AuditHistoryEntry> _history = [];
  List<SavedProject> _projects = [];
  Future<void> _operations = Future.value();
  bool _disposed = false;
  bool loaded = false;
  String? loadError;

  List<AuditHistoryEntry> get history => List.unmodifiable(_history);
  List<SavedProject> get projects => List.unmodifiable(_projects);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() => _enqueue(_read);

  Future<void> _read() async {
    loadError = null;
    try {
      final history = await _historyService.load();
      final projects = await _projectService.load();
      _history = history;
      _projects = projects;
    } catch (_) {
      loadError = 'Saved data could not be loaded. Try again.';
    }
    loaded = true;
    _changed();
  }

  SavedProject? projectFor(String url) {
    for (final project in _projects) {
      if (samePage(project.url, url)) return project;
    }
    return null;
  }

  List<AuditHistoryEntry> historyFor(String url) =>
      _history.where((entry) => samePage(entry.result.url, url)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  AuditHistoryEntry? previousFor(String url, DateTime at) {
    for (final entry in historyFor(url)) {
      if (entry.createdAt.isBefore(at)) return entry;
    }
    return null;
  }

  // Reads share the mutation queue: even an initial load or a retry cannot
  // replace newer in-memory changes with an earlier storage snapshot.
  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<T> _write<T>(Future<T> Function() operation) => _enqueue(() async {
    if (!loaded || loadError != null) await _read();
    if (loadError != null) throw StateError(loadError!);
    return operation();
  });

  Future<void> _saveProjects(List<SavedProject> next) async {
    await _projectService.save(next);
    _projects = next;
    _changed();
  }

  Future<void> saveProject(String url, {String? name, bool? favorite}) =>
      _write(() async {
        final validation = UrlValidator.validate(url);
        if (!validation.isValid) throw ArgumentError(validation.message);
        final normalized = pageIdentity(validation.uri.toString());
        final existing = projectFor(normalized);
        final trimmed = name?.trim();
        final title = trimmed == null || trimmed.isEmpty
            ? existing?.name ?? validation.uri!.host
            : trimmed;
        final project =
            existing?.copyWith(name: title, favorite: favorite) ??
            SavedProject(
              url: normalized,
              name: title,
              createdAt: DateTime.now(),
              favorite: favorite ?? false,
            );
        await _saveProjects([
          ..._projects.where((item) => item.id != project.id),
          project,
        ]);
      });

  Future<void> toggleFavorite(String url) => _write(() async {
    final project = projectFor(url);
    if (project == null) return;
    await _saveProjects(
      _projects
          .map(
            (item) => item.id == project.id
                ? item.copyWith(favorite: !item.favorite)
                : item,
          )
          .toList(),
    );
  });

  Future<void> removeProject(String url) => _write(
    () => _saveProjects(
      _projects.where((item) => !samePage(item.url, url)).toList(),
    ),
  );

  Future<void> toggleFinding(String url, String finding) => _write(() async {
    final existing =
        projectFor(url) ??
        SavedProject(
          url: pageIdentity(url),
          name: Uri.parse(url).host,
          createdAt: DateTime.now(),
        );
    final selected = {...existing.inProgress};
    if (!selected.remove(finding)) selected.add(finding);
    await _saveProjects([
      ..._projects.where((item) => item.id != existing.id),
      existing.copyWith(inProgress: selected),
    ]);
  });

  Future<void> resetFindings(String url) => _write(
    () => _saveProjects(
      _projects
          .map(
            (project) => samePage(project.url, url)
                ? project.copyWith(inProgress: {})
                : project,
          )
          .toList(),
    ),
  );

  Future<AuditHistoryEntry> record(
    SeoAuditResult result,
    SiteFilesReport? files,
    DateTime at,
  ) => _write(() async {
    _history = await _historyService.add(result, files, auditedAt: at);
    final entry = _history.first;
    _changed();
    final project = projectFor(result.url);
    if (project != null) {
      final unresolved = reviewAudit(result)
          .where((item) => !item.passed)
          .map((item) => item.id)
          .toSet();
      // In-progress state is reconciled when the history is read in the UI as
      // well, so a preference write failure cannot mark a passing check open.
      try {
        await _saveProjects(
          _projects
              .map(
                (item) => item.id == project.id
                    ? item.copyWith(
                        inProgress: item.inProgress.intersection(unresolved),
                      )
                    : item,
              )
              .toList(),
        );
      } catch (_) {
        // The audit itself has already been saved successfully.
      }
    }
    return entry;
  });

  Future<void> attachFiles(String id, SiteFilesReport files) =>
      _write(() async {
        _history = await _historyService.updateFiles(id, files);
        _changed();
      });

  Future<void> deleteAudit(String id) => _write(() async {
    _history = await _historyService.delete(id);
    _changed();
  });

  Future<void> clearHistory() => _write(() async {
    await _historyService.clear();
    _history = [];
    _changed();
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
