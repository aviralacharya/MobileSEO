import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/services/audit_history_service.dart';
import 'package:mobile_seo/services/csv_report_service.dart';
import 'package:mobile_seo/services/pdf_report_service.dart';
import 'package:mobile_seo/services/report_options.dart';
import 'package:mobile_seo/services/sample_audit.dart';

import '../support/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'CSV preserves UTF-8, quotes and newlines while neutralizing formula cells',
    () {
      final result = auditResult(
        html: incompleteHtml.replaceFirst('Short title', '=1+1'),
      );
      final bytes = const CsvReportService().buildReport(
        result,
        options: const ReportOptions(
          projectName: 'Café, "Kathmandu"',
          clientName: '@client',
          notes: 'First line\nSecond line, with "quotes"',
          inProgress: {'Meta title', 'Mobile viewport'},
          source: 'Sample audit',
        ),
      );
      expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
      final csv = utf8.decode(bytes);
      expect(csv, contains('"Café, ""Kathmandu"""'));
      expect(csv, contains('"\'@client"'));
      expect(csv, contains('"\'=1+1"'));
      expect(csv, contains('"First line\nSecond line, with ""quotes"""'));
      expect(csv, contains('"33","50"'));
      expect(csv, contains('"Sample audit"'));
      expect(csv, contains('"In progress"'));
      expect(csv, endsWith('\r\n'));
    },
  );

  test('CSV reports verified transitions and both audit evidence values', () {
    final before = AuditHistoryEntry(
      id: 'before',
      createdAt: DateTime.utc(2026, 10, 1),
      result: auditResult(html: incompleteHtml),
    );
    final result = auditResult();
    final csv = utf8.decode(
      const CsvReportService().buildReport(
        result,
        options: ReportOptions(
          before: before,
          auditedAt: DateTime.utc(2026, 10, 2),
        ),
      ),
    );
    expect(csv, contains('"Verified"'));
    expect(csv, contains('"Resolved"'));
    expect(csv, contains('"Short title"'));
    expect(csv, contains('"2026-10-02T00:00:00.000Z"'));
    expect(csv, contains('"100","100"'));
    expect(csv, contains('"Still passing"'));
    expect(
      () => const CsvReportService().buildReport(
        auditResult(url: 'https://different.com'),
        options: ReportOptions(before: before),
      ),
      throwsArgumentError,
    );
  });

  test('PDF handles long metadata, notes, bundled fonts and comparison pagination', () async {
    final before = AuditHistoryEntry(
      id: 'before',
      createdAt: DateTime.utc(2026, 10, 1),
      result: auditResult(html: incompleteHtml),
    );
    final notes = List.generate(
      55,
      (i) =>
          'Step ${i + 1}: Review the published changes with Café Kathmandu, then re-audit the same page.',
    ).join('\n');
    final longTitle = List.filled(160, 'Kathmandu').join(' ');
    final result = auditResult(
      html: healthyHtml.replaceFirst(
        'A practical guide to a weekend in Kathmandu',
        longTitle,
      ),
    );
    final bytes = await const PdfReportService().buildReport(
      result,
      generatedAt: DateTime.utc(2026, 10, 2, 12),
      options: ReportOptions(
        projectName: 'Kathmandu travel guide · October review',
        clientName: 'Café Kathmandu',
        brandName: 'Northstar SEO Studio',
        notes: notes,
        before: before,
        auditedAt: DateTime.utc(2026, 10, 2),
        inProgress: const {'Meta title'},
      ),
      siteFiles: SampleAudit.files,
    );
    final pdf = latin1.decode(bytes);
    expect(pdf, startsWith('%PDF-'));
    expect(pdf.trimRight(), endsWith('%%EOF'));
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(pdf).length,
      greaterThanOrEqualTo(3),
    );
    expect(pdf, contains('/FontFile2'));
    expect(bytes.length, greaterThan(20000));

    // Optional inspection output, outside the source tree and normal test runs.
    const output = String.fromEnvironment('REPORT_TEST_OUTPUT');
    if (output.isNotEmpty) {
      await Directory(output).create(recursive: true);
      await File('$output/client-report.pdf').writeAsBytes(bytes);
      await File('$output/client-report.csv').writeAsBytes(
        const CsvReportService().buildReport(
          result,
          options: ReportOptions(
            projectName: 'Kathmandu travel guide · October review',
            clientName: 'Café Kathmandu',
            brandName: 'Northstar SEO Studio',
            notes: notes,
            before: before,
            auditedAt: DateTime.utc(2026, 10, 2),
            inProgress: const {'Meta title'},
          ),
        ),
      );
    }
  });

  test(
    'sample PDF is generated offline with explicit sample metadata',
    () async {
      final bytes = await const PdfReportService().buildReport(
        SampleAudit.create(),
        options: const ReportOptions(
          source: 'Sample audit',
          projectName: 'Sample project',
        ),
      );
      expect(latin1.decode(bytes), startsWith('%PDF-'));
    },
  );
}
