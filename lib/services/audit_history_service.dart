import 'dart:convert';

import '../utils/page_identity.dart';
import 'local_store.dart';
import 'content_analyzer.dart';
import 'image_seo_checker.dart';
import 'indexation_checker.dart';
import 'link_checker.dart';
import 'open_graph_checker.dart';
import 'seo_audit_service.dart';
import 'seo_extractor.dart';
import 'site_files_checker.dart';
import 'security_report.dart';
import 'readability_accessibility_analyzer.dart';
import 'schema_inspector.dart';

class AuditHistoryEntry {
  const AuditHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.result,
    this.siteFiles,
  });
  final String id;
  final DateTime createdAt;
  final SeoAuditResult result;
  final SiteFilesReport? siteFiles;
  String get domain => Uri.tryParse(result.url)?.host ?? result.url;
}

class AuditHistoryService {
  AuditHistoryService({LocalStore? store})
    : _store = store ?? PreferencesStore();
  static const _key = 'mobile_seo.audit_history.v1';
  final LocalStore _store;

  Future<List<AuditHistoryEntry>> load() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return const [];
    final rows = jsonDecode(raw) as List;
    final list = <AuditHistoryEntry>[];
    for (final row in rows.whereType<Map>()) {
      try {
        list.add(_entryFromJson(Map<String, dynamic>.from(row)));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<AuditHistoryEntry>> add(
    SeoAuditResult result,
    SiteFilesReport? files, {
    DateTime? auditedAt,
  }) async {
    final entries = [...await load()];
    final now = auditedAt ?? DateTime.now();
    var id = '${now.microsecondsSinceEpoch}';
    var suffix = 0;
    while (entries.any((entry) => entry.id == id)) {
      id = '${now.microsecondsSinceEpoch}-${++suffix}';
    }
    entries.insert(
      0,
      AuditHistoryEntry(
        id: id,
        createdAt: now,
        result: result,
        siteFiles: files,
      ),
    );
    if (entries.length > 100) entries.removeRange(100, entries.length);
    await _store.write(_key, jsonEncode(entries.map(_entryToJson).toList()));
    return entries;
  }

  Future<List<AuditHistoryEntry>> delete(String id) async {
    final entries = (await load()).where((e) => e.id != id).toList();
    await _store.write(_key, jsonEncode(entries.map(_entryToJson).toList()));
    return entries;
  }

  Future<void> clear() => _store.remove(_key);

  Future<List<AuditHistoryEntry>> updateFiles(
    String id,
    SiteFilesReport files,
  ) async {
    final entries = await load();
    final index = entries.indexWhere((entry) => entry.id == id);
    // A user may have deleted the audit while the network request finished.
    if (index < 0) return entries;
    final previous = entries[index];
    entries[index] = AuditHistoryEntry(
      id: previous.id,
      createdAt: previous.createdAt,
      result: previous.result,
      siteFiles: files,
    );
    await _store.write(_key, jsonEncode(entries.map(_entryToJson).toList()));
    return entries;
  }

  Map<String, dynamic> _entryToJson(AuditHistoryEntry e) => {
    'id': e.id,
    'createdAt': e.createdAt.toIso8601String(),
    'result': _resultToJson(e.result),
    'siteFiles': e.siteFiles == null ? null : _filesToJson(e.siteFiles!),
  };
  AuditHistoryEntry _entryFromJson(Map<String, dynamic> j) => AuditHistoryEntry(
    id: j['id'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    result: _resultFromJson(Map<String, dynamic>.from(j['result'] as Map)),
    siteFiles: j['siteFiles'] == null
        ? null
        : _filesFromJson(Map<String, dynamic>.from(j['siteFiles'] as Map)),
  );

  Map<String, dynamic> _resultToJson(SeoAuditResult r) => {
    'url': r.url,
    'title': r.title,
    'description': r.description,
    'headings': r.headings.map((h) => {'tag': h.tag, 'text': h.text}).toList(),
    'h1': r.h1Count,
    'h2': r.h2Count,
    'h3': r.h3Count,
    'schemaTypes': r.schemaTypes,
    'schemaScripts': r.schemaScripts
        .map(
          (script) => {
            'index': script.index,
            'raw': script.rawJson,
            'valid': script.isValid,
            'formatted': script.formattedJson,
            'types': script.schemaTypes,
            'error': script.error,
          },
        )
        .toList(),
    'images': {
      'total': r.imageReport.totalImages,
      'missing': r.imageReport.imagesMissingAlt
          .map((i) => {'src': i.src, 'empty': i.hasEmptyAlt})
          .toList(),
      'items': r.imageReport.images
          .map(
            (image) => {
              'src': image.src,
              'alt': image.alt,
              'loading': image.loading,
              'width': image.width,
              'height': image.height,
              'format': image.format,
              'modern': image.isModernFormat,
              'legacy': image.isLegacyFormat,
            },
          )
          .toList(),
    },
    'og': {
      'title': r.openGraph.title,
      'description': r.openGraph.description,
      'image': r.openGraph.image,
      'url': r.openGraph.url,
      'twitterCard': r.openGraph.twitterCard,
      'twitterTitle': r.openGraph.twitterTitle,
      'twitterDescription': r.openGraph.twitterDescription,
      'twitterImage': r.openGraph.twitterImage,
    },
    'links': {
      'total': r.linkAudit.total,
      'internal': r.linkAudit.internal,
      'external': r.linkAudit.external,
      'empty': r.linkAudit.emptyHrefs,
      'nofollow': r.linkAudit.nofollow,
      'hosts': r.linkAudit.externalHosts,
      'urls': r.linkAudit.urls,
    },
    'content': {
      'words': r.content.wordCount,
      'ratio': r.content.textToHtmlRatio,
      'keywords': _keywords(r.content.keywords),
      'bigrams': _keywords(r.content.bigrams),
    },
    'indexation': {
      'robots': r.indexation.robotsMeta,
      'googlebot': r.indexation.googlebotMeta,
      'canonical': r.indexation.canonicalUrl,
      'language': r.indexation.language,
      'favicon': r.indexation.faviconUrl,
      'viewport': r.indexation.viewport,
      'hreflangs': r.indexation.hreflangs
          .map((h) => {'language': h.language, 'url': h.url})
          .toList(),
    },
    'security': {
      'hsts': r.security.hsts,
      'csp': r.security.csp,
      'xFrame': r.security.xFrameOptions,
      'xContentType': r.security.xContentTypeOptions,
      'server': r.security.server,
      'responseTimeMs': r.security.responseTimeMs,
      'mixedContentUrls': r.security.mixedContentUrls,
    },
    'readability': {
      'sentences': r.readability.sentenceCount,
      'words': r.readability.wordCount,
      'syllables': r.readability.syllableCount,
      'score': r.readability.fleschScore,
      'readingLevel': r.readability.readingLevel,
      'gradeLevel': r.readability.gradeLevel,
      'issues': r.readability.issues
          .map(
            (issue) => {
              'category': issue.category,
              'count': issue.count,
              'description': issue.description,
            },
          )
          .toList(),
    },
    'checks': r.checks
        .map(
          (c) => {
            'label': c.label,
            'value': c.value,
            'note': c.note,
            'status': c.status.name,
          },
        )
        .toList(),
  };

  SeoAuditResult _resultFromJson(Map<String, dynamic> j) {
    final image = Map<String, dynamic>.from(j['images'] as Map),
        og = Map<String, dynamic>.from(j['og'] as Map),
        links = Map<String, dynamic>.from(j['links'] as Map),
        content = Map<String, dynamic>.from(j['content'] as Map),
        index = Map<String, dynamic>.from(j['indexation'] as Map),
        security = Map<String, dynamic>.from(j['security'] as Map? ?? {});
    final readability = Map<String, dynamic>.from(
      j['readability'] as Map? ?? {},
    );
    String? str(Object? v) => v as String?;
    int toInt(Object? v) => v is int ? v : 0;
    final scannedImages = (image['items'] as List? ?? const []).map((item) {
      final data = Map<String, dynamic>.from(item as Map);
      return ImageAuditItem(
        src: data['src'] as String? ?? '(no src)',
        alt: data['alt'] as String?,
        loading: data['loading'] as String?,
        width: data['width'] as String?,
        height: data['height'] as String?,
        format: data['format'] as String? ?? 'Unknown',
        isModernFormat: data['modern'] as bool? ?? false,
        isLegacyFormat: data['legacy'] as bool? ?? false,
      );
    }).toList();
    final imageReport = ImageSeoReport(
      totalImages: toInt(image['total']),
      imagesMissingAlt: (image['missing'] as List).map((x) {
        final m = Map<String, dynamic>.from(x as Map);
        return ImageIssue(
          src: m['src'] as String,
          hasEmptyAlt: m['empty'] as bool,
        );
      }).toList(),
      images: scannedImages,
    );
    final contentReport = ContentMetrics(
      wordCount: toInt(content['words']),
      textToHtmlRatio: (content['ratio'] as num).toDouble(),
      keywords: _keywordsFromJson(content['keywords'] as List),
      bigrams: _keywordsFromJson(content['bigrams'] as List),
    );
    final indexation = IndexationInfo(
      robotsMeta: str(index['robots']),
      googlebotMeta: str(index['googlebot']),
      canonicalUrl: str(index['canonical']),
      language: str(index['language']),
      faviconUrl: str(index['favicon']),
      viewport: str(index['viewport']),
      hreflangs: (index['hreflangs'] as List).map((x) {
        final m = Map<String, dynamic>.from(x as Map);
        return HreflangEntry(m['language'] as String, m['url'] as String);
      }).toList(),
    );
    return SeoAuditResult(
      url: parsePageUrl(j['url'] as String).toString(),
      title: str(j['title']),
      description: str(j['description']),
      headings: (j['headings'] as List).map((x) {
        final m = Map<String, dynamic>.from(x as Map);
        return HeadingTag(tag: m['tag'] as String, text: m['text'] as String);
      }).toList(),
      h1Count: toInt(j['h1']),
      h2Count: toInt(j['h2']),
      h3Count: toInt(j['h3']),
      schemaTypes: (j['schemaTypes'] as List).cast<String>(),
      schemaScripts: (j['schemaScripts'] as List? ?? const []).map((item) {
        final script = Map<String, dynamic>.from(item as Map);
        return JsonLdScriptReport(
          index: script['index'] as int? ?? 0,
          rawJson: script['raw'] as String? ?? '',
          isValid: script['valid'] as bool? ?? false,
          formattedJson: script['formatted'] as String?,
          schemaTypes: (script['types'] as List? ?? const []).cast<String>(),
          error: script['error'] as String?,
        );
      }).toList(),
      imageReport: imageReport,
      openGraph: OpenGraphReport(
        title: str(og['title']),
        description: str(og['description']),
        image: str(og['image']),
        url: str(og['url']),
        twitterCard: str(og['twitterCard']),
        twitterTitle: str(og['twitterTitle']),
        twitterDescription: str(og['twitterDescription']),
        twitterImage: str(og['twitterImage']),
      ),
      linkAudit: LinkAudit(
        total: toInt(links['total']),
        internal: toInt(links['internal']),
        external: toInt(links['external']),
        emptyHrefs: toInt(links['empty']),
        nofollow: toInt(links['nofollow']),
        externalHosts: (links['hosts'] as List).cast<String>(),
        urls: (links['urls'] as List).cast<String>(),
      ),
      content: contentReport,
      indexation: indexation,
      security: SecurityReport(
        hsts: security['hsts'] as bool? ?? false,
        csp: security['csp'] as bool? ?? false,
        xFrameOptions: security['xFrame'] as bool? ?? false,
        xContentTypeOptions: security['xContentType'] as bool? ?? false,
        server: security['server'] as String?,
        responseTimeMs: security['responseTimeMs'] as int? ?? 0,
        mixedContentUrls: (security['mixedContentUrls'] as List? ?? const [])
            .cast<String>(),
      ),
      readability: ReadabilityAccessibilityReport(
        sentenceCount: toInt(readability['sentences']),
        wordCount: toInt(readability['words']),
        syllableCount: toInt(readability['syllables']),
        fleschScore: (readability['score'] as num?)?.toDouble() ?? 0,
        readingLevel:
            readability['readingLevel'] as String? ??
            'Not enough text to score',
        gradeLevel: readability['gradeLevel'] as String? ?? '—',
        issues: (readability['issues'] as List? ?? const []).map((item) {
          final issue = Map<String, dynamic>.from(item as Map);
          return AccessibilityIssue(
            category: issue['category'] as String? ?? 'Accessibility issue',
            count: toInt(issue['count']),
            description: issue['description'] as String? ?? '',
          );
        }).toList(),
      ),
      checks: (j['checks'] as List).map((x) {
        final m = Map<String, dynamic>.from(x as Map);
        return AuditCheck(
          label: m['label'] as String,
          value: m['value'] as String,
          note: m['note'] as String,
          status: AuditStatus.values.firstWhere(
            (v) => v.name == m['status'],
            orElse: () => AuditStatus.warning,
          ),
        );
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _keywords(List<KeywordMetric> values) => values
      .map((k) => {'term': k.term, 'count': k.count, 'density': k.density})
      .toList();
  List<KeywordMetric> _keywordsFromJson(List values) => values.map((x) {
    final m = Map<String, dynamic>.from(x as Map);
    return KeywordMetric(
      m['term'] as String,
      m['count'] as int,
      (m['density'] as num).toDouble(),
    );
  }).toList();

  Map<String, dynamic> _filesToJson(SiteFilesReport r) => {
    'robots': _fileToJson(r.robots),
    'sitemap': _fileToJson(r.sitemap),
    'aiReadiness': {
      'crawlers': r.aiReadiness.crawlers
          .map(
            (crawler) => {
              'userAgent': crawler.userAgent,
              'access': crawler.access.name,
              'detail': crawler.detail,
            },
          )
          .toList(),
      'llmsTxt': r.aiReadiness.llmsTxt == null
          ? null
          : _fileToJson(r.aiReadiness.llmsTxt!),
      'llmsFullTxt': r.aiReadiness.llmsFullTxt == null
          ? null
          : _fileToJson(r.aiReadiness.llmsFullTxt!),
    },
  };
  Map<String, dynamic> _fileToJson(SiteFileCheck c) => {
    'name': c.fileName,
    'url': c.url,
    'status': c.status.name,
    'detail': c.detail,
    'http': c.httpStatus,
  };
  SiteFilesReport _filesFromJson(Map<String, dynamic> j) {
    final ai = Map<String, dynamic>.from(j['aiReadiness'] as Map? ?? const {});
    return SiteFilesReport(
      robots: _fileFromJson(Map<String, dynamic>.from(j['robots'] as Map)),
      sitemap: _fileFromJson(Map<String, dynamic>.from(j['sitemap'] as Map)),
      aiReadiness: AiReadinessReport(
        crawlers: (ai['crawlers'] as List? ?? const []).map((item) {
          final crawler = Map<String, dynamic>.from(item as Map);
          return AiCrawlerStatus(
            userAgent: crawler['userAgent'] as String,
            access: AiCrawlerAccess.values.firstWhere(
              (status) => status.name == crawler['access'],
              orElse: () => AiCrawlerAccess.unknown,
            ),
            detail: crawler['detail'] as String,
          );
        }).toList(),
        llmsTxt: ai['llmsTxt'] == null
            ? null
            : _fileFromJson(Map<String, dynamic>.from(ai['llmsTxt'] as Map)),
        llmsFullTxt: ai['llmsFullTxt'] == null
            ? null
            : _fileFromJson(
                Map<String, dynamic>.from(ai['llmsFullTxt'] as Map),
              ),
      ),
    );
  }

  SiteFileCheck _fileFromJson(Map<String, dynamic> j) => SiteFileCheck(
    fileName: j['name'] as String,
    url: j['url'] as String,
    status: SiteFileStatus.values.firstWhere(
      (v) => v.name == j['status'],
      orElse: () => SiteFileStatus.fail,
    ),
    detail: j['detail'] as String,
    httpStatus: j['http'] as int?,
  );
}
