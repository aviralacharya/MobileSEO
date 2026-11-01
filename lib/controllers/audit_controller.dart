import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/audit_history_service.dart';
import '../services/sample_audit.dart';
import '../services/seo_audit_service.dart';
import '../services/seo_scraper_service.dart';
import '../services/site_files_checker.dart';
import 'workspace_controller.dart';

enum AuditPhase {
  idle,
  fetching,
  analyzing,
  siteFiles,
  complete,
  cancelled,
  failed,
}

enum AuditSource { live, saved, sample }

/// Owns each run's clients and generation. Late network responses cannot
/// replace the current page; accepted snapshots finish saving independently.
class AuditController extends ChangeNotifier {
  AuditController({
    required this._workspace,
    http.Client Function()? clientFactory,
    DateTime Function()? clock,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _clock = clock ?? DateTime.now;

  final WorkspaceController _workspace;
  final http.Client Function() _clientFactory;
  final DateTime Function() _clock;
  http.Client? _pageClient, _filesClient;
  int _generation = 0;
  bool _disposed = false;
  String? _entryId;
  Future<AuditHistoryEntry?>? _saving;
  int _pendingSaves = 0;

  AuditPhase phase = AuditPhase.idle;
  AuditSource source = AuditSource.live;
  SeoAuditResult? result;
  SiteFilesReport? siteFiles;
  DateTime? auditedAt;
  String? errorMessage, filesError, saveError;
  SeoErrorKind? errorKind;

  bool get running =>
      phase == AuditPhase.fetching ||
      phase == AuditPhase.analyzing ||
      phase == AuditPhase.siteFiles;
  bool get filesLoading => phase == AuditPhase.siteFiles;
  bool get canRetry =>
      errorKind == null ||
      errorKind == SeoErrorKind.timeout ||
      errorKind == SeoErrorKind.network ||
      errorKind == SeoErrorKind.serverError ||
      errorKind == SeoErrorKind.unknown;
  String? get entryId => _entryId;
  bool get saving => _pendingSaves > 0;

  bool _current(int generation) => !_disposed && generation == _generation;
  bool _ownsResult(SeoAuditResult audited) =>
      !_disposed && source == AuditSource.live && identical(result, audited);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _stop() {
    _generation++;
    _pageClient?.close();
    _filesClient?.close();
    _pageClient = null;
    _filesClient = null;
  }

  Future<void> run(Uri url) async {
    _stop();
    final generation = _generation;
    result = null;
    siteFiles = null;
    auditedAt = null;
    _entryId = null;
    _saving = null;
    _pendingSaves = 0;
    errorMessage = filesError = saveError = null;
    errorKind = null;
    source = AuditSource.live;
    phase = AuditPhase.fetching;
    _changed();
    final client = _clientFactory();
    _pageClient = client;
    try {
      final page = await SeoScraperService(client: client)
          .fetchDocument(url.toString());
      if (!_current(generation)) return;
      phase = AuditPhase.analyzing;
      _changed();
      // Yield to the UI for the real analysis stage, without a simulated timer.
      await Future<void>.delayed(Duration.zero);
      if (!_current(generation)) return;
      final audited = const SeoAuditService().analyze(page);
      final at = _clock();
      result = audited;
      auditedAt = at;
      phase = AuditPhase.siteFiles;
      _saving = _record(audited, at);
      _changed();
      if (!_current(generation)) return;
      await _checkFiles(Uri.parse(audited.url), generation);
    } on SeoScrapeException catch (error) {
      if (!_current(generation)) return;
      errorMessage = error.userMessage;
      errorKind = error.kind;
      phase = AuditPhase.failed;
      _changed();
    } catch (_) {
      if (!_current(generation)) return;
      errorMessage = 'The page could not be analyzed. Please try again.';
      errorKind = SeoErrorKind.unknown;
      phase = AuditPhase.failed;
      _changed();
    } finally {
      client.close();
      if (identical(_pageClient, client)) _pageClient = null;
    }
  }

  Future<AuditHistoryEntry?> _record(
    SeoAuditResult audited,
    DateTime at, {
    SiteFilesReport? files,
  }) async {
    _pendingSaves++;
    try {
      final entry = await _workspace.record(audited, files, at);
      if (_ownsResult(audited)) {
        _entryId = entry.id;
        saveError = null;
      }
      return entry;
    } catch (_) {
      if (_ownsResult(audited)) {
        saveError =
            'This result is available, but could not be saved to history.';
      }
      return null;
    } finally {
      if (_ownsResult(audited)) {
        _pendingSaves--;
        _changed();
      }
    }
  }

  Future<void> _attachFiles(
    SeoAuditResult audited,
    String id,
    SiteFilesReport files,
  ) async {
    if (_ownsResult(audited)) {
      _pendingSaves++;
      _changed();
    }
    try {
      await _workspace.attachFiles(id, files);
      if (_ownsResult(audited)) saveError = null;
    } catch (_) {
      if (_ownsResult(audited)) {
        saveError = 'On-page results are saved; the site-file update could not be saved.';
      }
    } finally {
      if (_ownsResult(audited)) {
        _pendingSaves--;
        _changed();
      }
    }
  }

  Future<void> _checkFiles(Uri url, int generation) async {
    if (!_current(generation)) return;
    final client = _clientFactory();
    _filesClient = client;
    try {
      final files = await SiteFilesChecker(client: client).check(url);
      if (!_current(generation)) return;
      final audited = result!;
      final pendingSave = _saving;
      final entryId = _entryId;
      siteFiles = files;
      final checks = [
        files.robots,
        files.sitemap,
        if (files.aiReadiness.llmsTxt != null) files.aiReadiness.llmsTxt!,
        if (files.aiReadiness.llmsFullTxt != null)
          files.aiReadiness.llmsFullTxt!,
      ];
      filesError = checks.any((check) => check.httpStatus == null)
          ? 'Some site files could not be reached. Retry these checks independently.'
          : null;
      phase = AuditPhase.complete;
      _changed();
      final saved = await pendingSave;
      final id = entryId ?? saved?.id;
      if (id != null) {
        await _attachFiles(audited, id, files);
      }
    } catch (_) {
      if (!_current(generation)) return;
      filesError =
          'Site files are unavailable. Your on-page results are ready.';
      phase = AuditPhase.complete;
      _changed();
    } finally {
      client.close();
      if (identical(_filesClient, client)) _filesClient = null;
    }
  }

  Future<void> retryFiles() async {
    if (result == null || running || source != AuditSource.live) return;
    filesError = null;
    phase = AuditPhase.siteFiles;
    _changed();
    await _checkFiles(Uri.parse(result!.url), _generation);
  }

  Future<void> retrySave() async {
    final audited = result;
    final at = auditedAt;
    if (audited == null ||
        at == null ||
        source != AuditSource.live ||
        saving ||
        saveError == null) {
      return;
    }
    final id = _entryId;
    final files = siteFiles;
    if (id == null) {
      _saving = _record(audited, at, files: files);
      _changed();
      await _saving;
    } else if (files != null) {
      await _attachFiles(audited, id, files);
    }
  }

  void cancel() {
    if (!running) return;
    _stop();
    phase = AuditPhase.cancelled;
    if (result != null) {
      filesError = 'Site checks cancelled. On-page results are ready.';
    }
    _changed();
  }

  void restore(AuditHistoryEntry entry) {
    _stop();
    result = entry.result;
    siteFiles = entry.siteFiles;
    auditedAt = entry.createdAt;
    _entryId = entry.id;
    _saving = null;
    _pendingSaves = 0;
    source = AuditSource.saved;
    phase = AuditPhase.complete;
    errorMessage = filesError = saveError = null;
    errorKind = null;
    _changed();
  }

  void showSample() {
    _stop();
    result = SampleAudit.create();
    siteFiles = SampleAudit.files;
    auditedAt = null;
    _entryId = null;
    _saving = null;
    _pendingSaves = 0;
    source = AuditSource.sample;
    phase = AuditPhase.complete;
    errorMessage = filesError = saveError = null;
    errorKind = null;
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    super.dispose();
  }
}
