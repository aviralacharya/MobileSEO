import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'audit_review.dart';
import 'report_options.dart';
import 'seo_audit_service.dart';
import 'site_files_checker.dart';

class PdfReportService {
  const PdfReportService();

  Future<Uint8List> buildReport(
    SeoAuditResult result, {
    DateTime? generatedAt,
    ReportOptions options = const ReportOptions(),
    SiteFilesReport? siteFiles,
  }) async {
    final regularFont = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final boldFont = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final findings = reviewAudit(result);
    final comparison = options.comparison(result);
    final previous = {
      if (options.before != null)
        for (final finding in reviewAudit(options.before!.result))
          finding.id: finding,
    };
    final generated = generatedAt ?? DateTime.now();
    final brand = options.brandName.trim().isEmpty
        ? 'MobileSEO'
        : options.brandName.trim();
    final doc = pw.Document(
      title:
          '${options.projectName.isEmpty ? 'Page' : options.projectName} · SEO Audit',
      author: brand,
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(regularFont),
        bold: pw.Font.ttf(boldFont),
      ),
    );
    pw.Widget heading(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 20, bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        maxPages: 30,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.blueGrey100),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  _excerpt(brand, 80),
                  style: pw.TextStyle(
                    color: PdfColors.indigo700,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Text(
                options.source == 'Sample audit'
                    ? 'SAMPLE REPORT'
                    : 'SEO AUDIT REPORT',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Prepared with MobileSEO · Single-page HTML audit',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey600,
                ),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 20),
          pw.Text(
            options.projectName.trim().isEmpty
                ? 'SEO health & next steps'
                : _excerpt(options.projectName, 120),
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          if (options.clientName.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                'Prepared for ${_excerpt(options.clientName, 120)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ),
          pw.SizedBox(height: 10),
          pw.Text(
            _excerpt(result.url, 600),
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.indigo700),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '${options.source} · ${options.auditedAt == null ? 'Audit time not recorded' : 'Audited ${_date(options.auditedAt!)}'}\nGenerated ${_date(generated)}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.blueGrey600,
            ),
          ),
          heading('Executive summary'),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${result.score}/100 measured SEO score',
                  style: pw.TextStyle(
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  '${findings.where((f) => f.severity == FindingSeverity.critical).length} critical · ${findings.where((f) => f.severity == FindingSeverity.improvement).length} to improve · ${findings.where((f) => f.passed).length} passed',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '${result.passedCount} of ${result.checks.length} core checks pass. The score covers title, description, H1, H2, image alt text and schema presence. Extended diagnostics do not add score points.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                if (selectedCoreFixes(result, options.inProgress) > 0) ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Projected: ${projectedAuditScore(result, options.inProgress)}/100 if selected in-progress core checks pass. This is a scenario, not a measured improvement.',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Automated guidance based on the returned HTML, not a ranking guarantee. Publish changes and re-audit the same page to verify improvements. Effort estimates vary by website.',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.blueGrey600,
            ),
          ),
          if (comparison != null) ...[
            heading('Before & after · Same page'),
            pw.Text(
              '${comparison.before.score}/100 to ${comparison.after.score}/100 (${comparison.scoreChange > 0 ? '+' : ''}${comparison.scoreChange} points)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Before: ${_date(options.before!.createdAt)}\nAfter: ${options.auditedAt == null ? 'Time not recorded' : _date(options.auditedAt!)}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Resolved (${comparison.resolved.length}): ${comparison.resolved.isEmpty ? 'None' : comparison.resolved.map((f) => f.title).join(', ')}\nNew (${comparison.introduced.length}): ${comparison.introduced.isEmpty ? 'None' : comparison.introduced.map((f) => f.title).join(', ')}\nRemaining (${comparison.remaining.length}): ${comparison.remaining.isEmpty ? 'None' : comparison.remaining.map((f) => f.title).join(', ')}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          pw.NewPage(),
          heading('Prioritized findings & evidence'),
          for (final finding in findings)
            pw.Inseparable(
              child: pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey100),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${finding.title} · ${finding.severityLabel}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${options.workflow(finding, comparison)} · ${finding.category} · ${finding.scored ? 'Core score check' : 'Extended diagnostic'}${finding.passed ? '' : ' · ${finding.effort} estimated'}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.blueGrey600,
                      ),
                    ),
                    pw.SizedBox(height: 7),
                    pw.Text(
                      'Evidence: ${_excerpt(finding.evidence, 700)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    if (previous[finding.id] != null) ...[
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Previous evidence: ${_excerpt(previous[finding.id]!.evidence, 400)}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.blueGrey600,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Recommendation: ${_excerpt(finding.recommendation, 500)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          if (siteFiles != null) ...[
            pw.NewPage(freeSpace: 140),
            heading('Site-level crawl files'),
            pw.Text(
              'Root-file availability is separate from the page score.',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 6),
            for (final file in [
              siteFiles.robots,
              siteFiles.sitemap,
              if (siteFiles.aiReadiness.llmsTxt != null)
                siteFiles.aiReadiness.llmsTxt!,
              if (siteFiles.aiReadiness.llmsFullTxt != null)
                siteFiles.aiReadiness.llmsFullTxt!,
            ])
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Text(
                  '${file.fileName}: ${file.detail}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
          ],
          if (options.notes.trim().isNotEmpty) ...[
            pw.NewPage(freeSpace: 100),
            heading('Client notes & next steps'),
            pw.Text(
              options.notes.trim(),
              overflow: pw.TextOverflow.span,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  String _date(DateTime value) =>
      '${value.toUtc().toIso8601String().replaceFirst('T', ' ').split('.').first} UTC';
  String _excerpt(String value, int limit) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= limit
        ? compact
        : '${compact.substring(0, limit)}… [excerpt]';
  }
}
