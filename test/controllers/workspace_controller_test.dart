import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/controllers/workspace_controller.dart';
import 'package:mobile_seo/services/audit_history_service.dart';
import 'package:mobile_seo/services/project_service.dart';
import 'package:mobile_seo/services/sample_audit.dart';

import '../support/test_fixtures.dart';

const _historyKey = 'mobile_seo.audit_history.v1';
const _url = 'https://example.com/guide';

void main() {
  late MemoryStore store;
  late WorkspaceController workspace;
  final at = DateTime.utc(2026, 10, 20, 12);

  setUp(() {
    store = MemoryStore();
    workspace = workspaceFor(store);
  });
  tearDown(() => workspace.dispose());

  test(
    'first audit persists with complete evidence and can be restored',
    () async {
      final entry = await workspace.record(
        auditResult(),
        SampleAudit.files,
        at,
      );
      final restored = workspaceFor(store);
      addTearDown(restored.dispose);
      await restored.load();

      expect(restored.loadError, isNull);
      expect(restored.history.single.id, entry.id);
      final saved = restored.history.single;
      expect(saved.createdAt, at);
      expect(saved.result.score, 100);
      expect(saved.result.title, entry.result.title);
      expect(saved.result.imageReport.images.single.alt, 'A sunny courtyard');
      expect(saved.result.schemaScripts.single.isValid, isTrue);
      expect(saved.result.security.responseTimeMs, 246);
      expect(saved.siteFiles!.aiReadiness.llmsTxt!.httpStatus, 404);
      expect(saved.siteFiles!.robots.httpStatus, 200);
    },
  );

  test(
    'projects, favorites and fixes survive reload without duplicate pages',
    () async {
      await workspace.saveProject(
        'https://EXAMPLE.com/guide#top',
        name: 'Client site',
      );
      await Future.wait([
        workspace.toggleFavorite(_url),
        workspace.toggleFinding(_url, 'Meta title'),
        workspace.saveProject('$_url#section', name: 'Renamed project'),
      ]);
      await workspace.load();

      expect(workspace.projects, hasLength(1));
      final project = workspace.projectFor(_url)!;
      expect(project.url, _url);
      expect(project.name, 'Renamed project');
      expect(project.favorite, isTrue);
      expect(project.inProgress, {'Meta title'});
      expect(workspace.projectFor('$_url?lang=en'), isNull);
      expect(workspace.projectFor('http://example.com/guide'), isNull);
    },
  );

  test('initial load cannot overwrite queued project mutations', () async {
    await ProjectService(store: store)
        .save([SavedProject(url: _url, name: 'Existing', createdAt: at)]);
    final reading = Completer<void>();
    final release = Completer<void>();
    store.beforeRead = (key) async {
      if (key == ProjectService.storageKey && !reading.isCompleted) {
        reading.complete();
        await release.future;
      }
    };
    final loading = workspace.load();
    await reading.future;
    final favorite = workspace.toggleFavorite(_url);
    final rename = workspace.saveProject(_url, name: 'Updated');
    release.complete();
    await Future.wait([loading, favorite, rename]);
    await workspace.load();

    expect(workspace.projects.single.favorite, isTrue);
    expect(workspace.projects.single.name, 'Updated');
  });

  test(
    'a reload waits for an in-flight write and later mutations are retained',
    () async {
      await workspace.saveProject(_url);
      final writing = Completer<void>();
      final release = Completer<void>();
      store.beforeWrite = (key) async {
        if (!writing.isCompleted) {
          writing.complete();
          await release.future;
        }
      };
      final first = workspace.toggleFinding(_url, 'Meta title');
      await writing.future;
      final loading = workspace.load();
      final second = workspace.toggleFinding(_url, 'Meta description');
      release.complete();
      await Future.wait([first, loading, second]);

      expect(workspace.projects.single.inProgress, {
        'Meta title',
        'Meta description',
      });
      final persisted = await ProjectService(store: store).load();
      expect(persisted.single.inProgress, workspace.projects.single.inProgress);
    },
  );

  test(
    'failed writes keep the previous state and do not poison the queue',
    () async {
      await workspace.saveProject(_url, name: 'Original');
      store.failWrites = true;
      await expectLater(
        workspace.saveProject(_url, name: 'Not saved'),
        throwsStateError,
      );
      expect(workspace.projects.single.name, 'Original');
      store.failWrites = false;
      await workspace.toggleFavorite(_url);
      await workspace.load();
      expect(workspace.projects.single.name, 'Original');
      expect(workspace.projects.single.favorite, isTrue);
    },
  );

  test('load failures protect stored data and can be retried', () async {
    await workspace.saveProject(_url, name: 'Keep me');
    final before = Map<String, String>.of(store.values);
    store.failReads = true;
    await workspace.load();
    expect(workspace.loadError, isNotNull);
    await expectLater(
      workspace.saveProject('https://other.com'),
      throwsStateError,
    );
    expect(store.values, before);
    store.failReads = false;
    await workspace.load();
    expect(workspace.loadError, isNull);
    expect(workspace.projects.single.name, 'Keep me');
  });

  test(
    'malformed individual history rows are skipped but broken roots surface',
    () async {
      final entry = await workspace.record(auditResult(), null, at);
      final rows = jsonDecode(store.values[_historyKey]!) as List;
      store.values[_historyKey] = jsonEncode([
        null,
        {'id': 'bad-date', 'createdAt': 'not a date'},
        {
          'id': 'bad-result',
          'createdAt': at.toIso8601String(),
          'result': false,
        },
        ...rows,
      ]);
      await workspace.load();
      expect(workspace.loadError, isNull);
      expect(workspace.history.single.id, entry.id);
      store.values[_historyKey] = '{broken';
      await workspace.load();
      expect(workspace.loadError, isNotNull);
      expect(workspace.history.single.id, entry.id);
      await expectLater(
        workspace.record(auditResult(), null, at),
        throwsStateError,
      );
      expect(store.values[_historyKey], '{broken');
    },
  );

  test(
    'concurrent snapshots retain unique IDs and cap history at 100',
    () async {
      final result = auditResult();
      await Future.wait([
        for (var i = 0; i < 102; i++) workspace.record(result, null, at),
      ]);
      await workspace.load();
      expect(workspace.history, hasLength(100));
      expect(workspace.history.map((e) => e.id).toSet(), hasLength(100));
    },
  );

  test(
    'malformed saved URLs cannot break project or history navigation',
    () async {
      final entry = await workspace.record(auditResult(), null, at);
      await workspace.saveProject(_url, name: 'Valid project');
      final history =
          (jsonDecode(store.values[_historyKey]!) as List).single as Map;
      final project =
          (jsonDecode(store.values[ProjectService.storageKey]!) as List).single
              as Map;
      const invalid = [
        'relative/path',
        'https://',
        'https://example.com:not-a-port',
        'https://example.com:99999',
        'file:///private/file',
        'http://[broken',
      ];
      store.values[_historyKey] = jsonEncode([
        for (final url in invalid)
          {
            ...history,
            'result': {...history['result'] as Map, 'url': url},
          },
        history,
      ]);
      store.values[ProjectService.storageKey] = jsonEncode([
        for (final url in invalid) {...project, 'url': url},
        project,
      ]);
      await workspace.load();
      expect(workspace.loadError, isNull);
      expect(workspace.historyFor(_url).single.id, entry.id);
      expect(workspace.projects.single.name, 'Valid project');
    },
  );

  test('site-file completion never recreates a deleted snapshot', () async {
    final entry = await workspace.record(auditResult(), null, at);
    await workspace.deleteAudit(entry.id);
    final writes = store.writes.length;
    await workspace.attachFiles(entry.id, SampleAudit.files);
    expect(workspace.history, isEmpty);
    expect(store.writes.length, writes);
    expect(await AuditHistoryService(store: store).load(), isEmpty);
  });

  test('history clearing preserves projects and in-progress work', () async {
    await workspace.saveProject(_url, name: 'My client');
    await workspace.record(auditResult(html: incompleteHtml), null, at);
    await workspace.toggleFinding(_url, 'Meta title');
    await workspace.clearHistory();
    await workspace.load();
    expect(workspace.history, isEmpty);
    expect(workspace.projects.single.inProgress, {'Meta title'});
  });

  test('a new audit clears only tasks that now pass and selects exact-page history', () async {
    final before = await workspace.record(
      auditResult(html: incompleteHtml),
      null,
      at,
    );
    await workspace.toggleFinding(_url, 'Meta title');
    await workspace.toggleFinding(_url, 'Meta description');
    final nextHtml = incompleteHtml.replaceFirst(
      'Short title',
      'A practical guide to a weekend in Kathmandu',
    );
    await workspace.record(
      auditResult(html: nextHtml),
      null,
      at.add(const Duration(days: 1)),
    );
    await workspace.record(
      auditResult(url: '$_url?lang=en'),
      null,
      at.add(const Duration(days: 2)),
    );

    expect(workspace.projectFor(_url)!.inProgress, {'Meta description'});
    expect(workspace.historyFor('$_url#heading'), hasLength(2));
    expect(
      workspace.previousFor(_url, at.add(const Duration(days: 1)))!.id,
      before.id,
    );
    await workspace.removeProject(_url);
    expect(workspace.projects, isEmpty);
    expect(workspace.history, hasLength(3));
  });
}
