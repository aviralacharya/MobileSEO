import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/seo_audit_service.dart';

class PdfReportService {
  const PdfReportService();

  Future<Uint8List> buildReport(
    SeoAuditResult result, {
    DateTime? generatedAt,
  }) async {
    final created = generatedAt ?? DateTime.now();
    final doc = pw.Document(title: 'MobileSEO Audit Report');
    final warnings = result.checks
        .where((c) => c.status == AuditStatus.warning)
        .length;
    final passed = result.checks.length - warnings;
    final failed = result.indexation.blocksIndexing ? 1 : 0;
    final actions = _prioritizedActions(result);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 42, 36, 42),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.blueGrey200),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MobileSEO',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo700,
                ),
              ),
              pw.Text(
                'AUDIT REPORT',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey200)),
          ),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey600,
            ),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 20),
          pw.Text(
            'SEO Audit Report',
            style: pw.TextStyle(
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            result.url,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.indigo700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${_formatDate(created)}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey600,
            ),
          ),
          pw.SizedBox(height: 20),
          _scoreCard(result.score, passed, warnings, failed),
          pw.SizedBox(height: 22),
          pw.Text(
            'Check summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Check', 'Status', 'Finding'],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.indigo700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.all(6),
            border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: .5),
            data: [
              for (final c in result.checks)
                [
                  c.label,
                  c.status == AuditStatus.good ? 'Passed' : 'Warning',
                  '${c.value}\n${c.note}',
                ],
              if (result.indexation.blocksIndexing)
                [
                  'Robots indexation directives',
                  'Failed',
                  'noindex or nofollow was found. Review whether indexing should be restricted.',
                ],
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            'Prioritized action checklist',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (actions.isEmpty)
            pw.Text(
              'No warning checks were found. Continue monitoring the page as it changes.',
              style: const pw.TextStyle(fontSize: 10),
            )
          else
            ...actions.asMap().entries.map(
              (entry) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 9),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: entry.key == 0
                      ? PdfColors.orange50
                      : PdfColors.blueGrey50,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 20,
                      height: 20,
                      alignment: pw.Alignment.center,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.white,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Text(
                        '${entry.key + 1}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            entry.value.$1,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            entry.value.$2,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.blueGrey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _scoreCard(int score, int passed, int warnings, int failed) {
    final color = score >= 80
        ? PdfColors.green700
        : score >= 50
        ? PdfColors.orange700
        : PdfColors.red700;
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.blueGrey100),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 66,
            height: 66,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: color, width: 4),
            ),
            child: pw.Text(
              '$score',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ),
          pw.SizedBox(width: 18),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SEO Health Score',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Passed: $passed    Warnings: $warnings    Failed: $failed',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.blueGrey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<(String, String)> _prioritizedActions(SeoAuditResult result) {
    final actions = <(int, String, String)>[];
    if (result.indexation.blocksIndexing)
      actions.add((
        0,
        'Review robots directives',
        'Remove noindex/nofollow if this page should be discoverable.',
      ));
    if (result.title == null ||
        result.title!.length < 30 ||
        result.title!.length > 60)
      actions.add((
        1,
        'Improve the meta title',
        'Write a unique, relevant title, ideally around 30–60 characters.',
      ));
    if (result.description == null ||
        result.description!.length < 70 ||
        result.description!.length > 160)
      actions.add((
        2,
        'Improve the meta description',
        'Summarize the page clearly in roughly 70–160 characters.',
      ));
    if (!result.hasSchema)
      actions.add((
        3,
        'Add structured data',
        'Add valid JSON-LD that describes the page or organization.',
      ));
    if (result.h1Count != 1)
      actions.add((
        4,
        'Fix the H1 structure',
        'Use one descriptive H1 heading for the page.',
      ));
    if (result.content.isThinContent)
      actions.add((
        5,
        'Expand thin content',
        'Add useful, original information that answers visitor questions.',
      ));
    for (final check in result.failedChecks) {
      if (actions.any(
        (a) => check.label.toLowerCase().contains(a.$2.toLowerCase()),
      ))
        continue;
      actions.add((6, check.label, check.note));
    }
    actions.sort((a, b) => a.$1.compareTo(b.$1));
    return actions.map((a) => (a.$2, a.$3)).toList();
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
