import 'dart:convert';
import 'dart:typed_data';

import 'audit_review.dart';
import 'report_options.dart';
import 'seo_audit_service.dart';

class CsvReportService {
  const CsvReportService();

  Uint8List buildReport(
    SeoAuditResult result, {
    ReportOptions options = const ReportOptions(),
  }) {
    final comparison = options.comparison(result);
    final previous = options.before == null
        ? <String, AuditFinding>{}
        : {
            for (final finding in reviewAudit(options.before!.result))
              finding.id: finding,
          };
    final rows = <List<Object>>[
      [
        'Project',
        'Client',
        'Prepared by',
        'Page URL',
        'Audited at (UTC)',
        'Source',
        'Measured score',
        'Projected score',
        'Category',
        'Finding',
        'Severity',
        'Workflow status',
        'Core score check',
        'Estimated effort',
        'Evidence',
        'Recommendation',
        'Previous evidence',
        'Change since previous audit',
        'Notes',
      ],
      for (final finding in reviewAudit(result))
        [
          options.projectName,
          options.clientName,
          options.brandName,
          result.url,
          options.auditedAt?.toUtc().toIso8601String() ?? '',
          options.source,
          result.score,
          projectedAuditScore(result, options.inProgress),
          finding.category,
          finding.title,
          finding.severityLabel,
          options.workflow(finding, comparison),
          finding.scored ? 'Yes' : 'No',
          finding.effort,
          finding.evidence,
          finding.recommendation,
          previous[finding.id]?.evidence ?? '',
          comparison == null
              ? ''
              : comparison.resolved.any((item) => item.id == finding.id)
              ? 'Resolved'
              : comparison.introduced.any((item) => item.id == finding.id)
              ? 'New'
              : comparison.remaining.any((item) => item.id == finding.id)
              ? 'Remaining'
              : 'Still passing',
          options.notes,
        ],
    ];
    // BOM keeps UTF-8 page titles readable in common spreadsheet apps.
    return Uint8List.fromList(
      utf8.encode(
        '\uFEFF${rows.map((row) => row.map(_cell).join(',')).join('\r\n')}\r\n',
      ),
    );
  }

  String _cell(Object value) {
    var text = value.toString();
    // Page metadata is untrusted spreadsheet input. Quoting alone does not
    // prevent formulas from running when a CSV is opened in a spreadsheet.
    if (RegExp(r'^\s*[=+\-@]').hasMatch(text) ||
        text.startsWith('\t') ||
        text.startsWith('\r')) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}
