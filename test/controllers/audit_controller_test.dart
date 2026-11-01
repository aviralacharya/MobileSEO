import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_seo/controllers/audit_controller.dart';
import 'package:mobile_seo/controllers/workspace_controller.dart';
import 'package:mobile_seo/services/audit_history_service.dart';
import 'package:mobile_seo/services/sample_audit.dart';

import '../support/test_fixtures.dart';

void main() {
  final uri = Uri.parse('https://example.com/guide');
  final at = DateTime.utc(2026, 10, 21, 9);
  late MemoryStore store;
  late WorkspaceController workspace;
  late AuditController audit;

  setUp(() {
    store = MemoryStore();
    workspace = workspaceFor(store);
  });
  tearDown(() {
    audit.dispose();
    workspace.dispose();
  });

  AuditController controller(List<TrackingClient> clients) {
    var next = 0;
    return AuditController(
      workspace: workspace,
      clientFactory: () => clients[next++],
      clock: () => at,
    );
  }

  test(
    'core results are usable and durable before site files complete',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final page = TrackingClient(pageResponse);
      final files = TrackingClient((request) async {
        if (!started.isCompleted) started.complete();
        await release.future;
        return fileResponse(request);
      });
      audit = controller([page, files]);
      final phases = <AuditPhase>[];
      audit.addListener(() => phases.add(audit.phase));
      final run = audit.run(uri);
      await started.future;
      await workspace.load();
      expect(audit.phase, AuditPhase.siteFiles);
      expect(audit.result!.score, 100);
      expect(audit.auditedAt, at);
      final id = workspace.history.single.id;
      expect(workspace.history.single.siteFiles, isNull);

      release.complete();
      await run;
      expect(audit.phase, AuditPhase.complete);
      expect(audit.filesError, isNull);
      expect(audit.entryId, id);
      expect(workspace.history.single.id, id);
      expect(workspace.history.single.siteFiles!.robots.passed, isTrue);
      expect(
        phases,
        containsAllInOrder([
          AuditPhase.fetching,
          AuditPhase.analyzing,
          AuditPhase.siteFiles,
          AuditPhase.complete,
        ]),
      );
      expect(page.closed && files.closed, isTrue);
    },
  );

  test(
    'cancelled page requests cannot publish late results or save history',
    () async {
      final release = Completer<void>();
      final page = TrackingClient((request) async {
        await release.future;
        return pageResponse(request);
      });
      audit = controller([page]);
      final run = audit.run(uri);
      audit.cancel();
      expect(page.closed, isTrue);
      release.complete();
      await run;
      expect(audit.phase, AuditPhase.cancelled);
      expect(audit.result, isNull);
      expect(workspace.history, isEmpty);
      expect(store.writes, isEmpty);
    },
  );

  test(
    'cancelling during analysis stops before core and file checks',
    () async {
      audit = controller([TrackingClient(pageResponse)]);
      audit.addListener(() {
        if (audit.phase == AuditPhase.analyzing) audit.cancel();
      });
      await audit.run(uri);
      expect(audit.phase, AuditPhase.cancelled);
      expect(audit.result, isNull);
      expect(store.writes, isEmpty);
    },
  );

  test('a superseded request cannot replace the newer audit', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final oldPage = TrackingClient((request) async {
      started.complete();
      await release.future;
      return pageResponse(request, html: incompleteHtml);
    });
    audit = controller([
      oldPage,
      TrackingClient(pageResponse),
      TrackingClient(fileResponse),
    ]);
    final old = audit.run(uri);
    await started.future;
    await audit.run(Uri.parse('https://example.org/current'));
    release.complete();
    await old;
    expect(audit.result!.url, 'https://example.org/current');
    expect(audit.result!.score, 100);
    expect(workspace.history.single.result.url, audit.result!.url);
    expect(oldPage.closed, isTrue);
  });

  test(
    'cancelled site checks retain core results and retry the same snapshot',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final page = TrackingClient(pageResponse);
      final files = TrackingClient((request) async {
        if (!started.isCompleted) started.complete();
        await release.future;
        return fileResponse(request);
      });
      final retry = TrackingClient(fileResponse);
      audit = controller([page, files, retry]);
      final run = audit.run(uri);
      await started.future;
      await workspace.load();
      final id = workspace.history.single.id;
      audit.cancel();
      release.complete();
      await run;
      expect(audit.result, isNotNull);
      expect(audit.siteFiles, isNull);
      expect(audit.filesError, contains('cancelled'));
      expect(files.closed, isTrue);
      await audit.retryFiles();
      expect(audit.phase, AuditPhase.complete);
      expect(audit.filesError, isNull);
      expect(workspace.history.single.id, id);
      expect(workspace.history.single.siteFiles, isNotNull);
      expect(page.requests, hasLength(1));
      expect(retry.requests, hasLength(4));
    },
  );

  test(
    'unreachable files can be retried without re-fetching the page',
    () async {
      final page = TrackingClient(pageResponse);
      audit = controller([
        page,
        TrackingClient((request) => throw http.ClientException('Offline')),
        TrackingClient(fileResponse),
      ]);
      await audit.run(uri);
      expect(audit.phase, AuditPhase.complete);
      expect(audit.result, isNotNull);
      expect(audit.filesError, isNotNull);
      await audit.retryFiles();
      expect(audit.filesError, isNull);
      expect(page.requests, hasLength(1));
      expect(workspace.history, hasLength(1));
    },
  );

  test('a failed history write does not discard the measured result', () async {
    store.failWrites = true;
    audit = controller([
      TrackingClient(pageResponse),
      TrackingClient(fileResponse),
    ]);
    await audit.run(uri);
    expect(audit.phase, AuditPhase.complete);
    expect(audit.result!.score, 100);
    expect(audit.siteFiles, isNotNull);
    expect(audit.saveError, contains('could not be saved'));
    expect(workspace.history, isEmpty);
    store.failWrites = false;
    await audit.retrySave();
    expect(audit.saveError, isNull);
    expect(audit.saving, isFalse);
    expect(workspace.history.single.id, audit.entryId);
    expect(workspace.history.single.createdAt, at);
    expect(workspace.history.single.siteFiles, isNotNull);
    await audit.retrySave();
    expect(workspace.history, hasLength(1));
  });

  for (final failSave in [false, true]) {
    test(
      'cancelling during a pending save retains ${failSave ? 'its error' : 'its snapshot ID'}',
      () async {
        final writing = Completer<void>();
        final releaseSave = Completer<void>();
        final releaseFiles = Completer<void>();
        store.beforeWrite = (_) async {
          if (!writing.isCompleted) writing.complete();
          await releaseSave.future;
        };
        store.failWrites = failSave;
        audit = controller([
          TrackingClient(pageResponse),
          TrackingClient((request) async {
            await releaseFiles.future;
            return fileResponse(request);
          }),
        ]);
        final run = audit.run(uri);
        await writing.future;
        expect(audit.saving, isTrue);
        audit.cancel();
        releaseSave.complete();
        await workspace.load();
        releaseFiles.complete();
        await run;
        expect(audit.phase, AuditPhase.cancelled);
        expect(audit.result!.score, 100);
        expect(audit.saving, isFalse);
        if (failSave) {
          expect(audit.saveError, contains('could not be saved'));
          expect(audit.entryId, isNull);
          store.failWrites = false;
          await audit.retrySave();
          expect(audit.saveError, isNull);
        }
        expect(workspace.history.single.id, audit.entryId);
        expect(workspace.history.single.createdAt, at);
      },
    );
  }

  test(
    'accepted site files finish saving after switching to a sample',
    () async {
      final writing = Completer<void>();
      final release = Completer<void>();
      store.beforeWrite = (_) async {
        if (!writing.isCompleted) writing.complete();
        await release.future;
      };
      audit = controller([
        TrackingClient(pageResponse),
        TrackingClient(fileResponse),
      ]);
      final ready = Completer<void>();
      audit.addListener(() {
        if (audit.phase == AuditPhase.complete && !ready.isCompleted) {
          ready.complete();
        }
      });
      final run = audit.run(uri);
      await writing.future;
      await ready.future;
      audit.showSample();
      release.complete();
      await run;
      expect(audit.source, AuditSource.sample);
      expect(audit.entryId, isNull);
      expect(audit.saveError, isNull);
      expect(audit.saving, isFalse);
      expect(workspace.history.single.result.url, uri.toString());
      expect(workspace.history.single.siteFiles, isNotNull);
    },
  );

  test(
    'retrying a failed file attachment updates the existing snapshot',
    () async {
      audit = controller([
        TrackingClient(pageResponse),
        TrackingClient(fileResponse),
      ]);
      var writes = 0;
      store.beforeWrite = (_) async {
        if (++writes == 2) throw StateError('Storage full');
      };
      await audit.run(uri);
      expect(audit.saveError, contains('site-file update'));
      final id = audit.entryId;
      expect(workspace.history.single.siteFiles, isNull);
      await audit.retrySave();
      expect(audit.saveError, isNull);
      expect(workspace.history.single.id, id);
      expect(workspace.history.single.siteFiles, isNotNull);
    },
  );

  test(
    'deleting an in-flight snapshot prevents later file attachment',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      audit = controller([
        TrackingClient(pageResponse),
        TrackingClient((request) async {
          if (!started.isCompleted) started.complete();
          await release.future;
          return fileResponse(request);
        }),
      ]);
      final run = audit.run(uri);
      await started.future;
      await workspace.load();
      await workspace.deleteAudit(workspace.history.single.id);
      release.complete();
      await run;
      expect(audit.siteFiles, isNotNull);
      expect(workspace.history, isEmpty);
    },
  );

  test(
    'restoring a saved snapshot rejects responses from the previous run',
    () async {
      final release = Completer<void>();
      audit = controller([
        TrackingClient((request) async {
          await release.future;
          return pageResponse(request);
        }),
      ]);
      final run = audit.run(uri);
      final snapshot = AuditHistoryEntry(
        id: 'saved',
        createdAt: at,
        result: auditResult(html: incompleteHtml),
      );
      audit.restore(snapshot);
      release.complete();
      await run;
      expect(audit.source, AuditSource.saved);
      expect(audit.entryId, 'saved');
      expect(audit.result, same(snapshot.result));
      expect(store.writes, isEmpty);
    },
  );

  test(
    'sample audits and saved-file retries are entirely network-free',
    () async {
      var requests = 0;
      audit = AuditController(
        workspace: workspace,
        clientFactory: () {
          requests++;
          throw StateError('No network allowed');
        },
      );
      audit.showSample();
      await audit.retryFiles();
      expect(audit.result!.url, SampleAudit.url);
      expect(audit.source, AuditSource.sample);
      expect(audit.auditedAt, isNull);
      expect(audit.entryId, isNull);
      expect(store.writes, isEmpty);
      audit.restore(
        AuditHistoryEntry(id: 'saved', createdAt: at, result: auditResult()),
      );
      await audit.retryFiles();
      expect(requests, 0);
    },
  );
}
