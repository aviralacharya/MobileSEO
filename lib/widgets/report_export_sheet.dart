import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/audit_history_service.dart';
import '../services/csv_report_service.dart';
import '../services/pdf_report_service.dart';
import '../services/report_options.dart';
import '../services/seo_audit_service.dart';
import '../services/site_files_checker.dart';
import 'app_sheet.dart';

Future<void> showReportExport(
  BuildContext context, {
  required SeoAuditResult result,
  required String source,
  DateTime? auditedAt,
  AuditHistoryEntry? before,
  SiteFilesReport? siteFiles,
  Set<String> inProgress = const {},
  String projectName = '',
}) => AppSheet.show<void>(
  context: context,
  builder: (_) => _ReportExportSheet(
    result: result,
    source: source,
    auditedAt: auditedAt,
    before: before,
    siteFiles: siteFiles,
    inProgress: inProgress,
    projectName: projectName,
  ),
);

class _ReportExportSheet extends StatefulWidget {
  const _ReportExportSheet({
    required this.result,
    required this.source,
    required this.auditedAt,
    required this.before,
    required this.siteFiles,
    required this.inProgress,
    required this.projectName,
  });
  final SeoAuditResult result;
  final String source, projectName;
  final DateTime? auditedAt;
  final AuditHistoryEntry? before;
  final SiteFilesReport? siteFiles;
  final Set<String> inProgress;
  @override
  State<_ReportExportSheet> createState() => _ReportExportSheetState();
}

class _ReportExportSheetState extends State<_ReportExportSheet> {
  late final _project = TextEditingController(text: widget.projectName);
  final _client = TextEditingController();
  final _brand = TextEditingController(text: 'MobileSEO');
  final _notes = TextEditingController();
  String _format = 'PDF';
  bool _includeComparison = true, _busy = false;
  String? _error;

  @override
  void dispose() {
    _project.dispose();
    _client.dispose();
    _brand.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_busy) return;
    final renderBox = buttonContext.findRenderObject() as RenderBox;
    final origin = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    final format = _format;
    final options = ReportOptions(
      projectName: _project.text.trim(),
      clientName: _client.text.trim(),
      brandName: _brand.text.trim(),
      notes: _notes.text.trim(),
      source: widget.source,
      auditedAt: widget.auditedAt,
      before: _includeComparison ? widget.before : null,
      inProgress: widget.inProgress,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = format == 'PDF'
          ? await const PdfReportService().buildReport(
              widget.result,
              options: options,
              siteFiles: widget.siteFiles,
            )
          : const CsvReportService().buildReport(
              widget.result,
              options: options,
            );
      if (!mounted) return;
      final host = Uri.parse(widget.result.url).host
          .replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_');
      final filename =
          'mobileseo-$host-${DateTime.now().millisecondsSinceEpoch}.${format.toLowerCase()}';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: format == 'PDF' ? 'application/pdf' : 'text/csv',
              name: filename,
            ),
          ],
          fileNameOverrides: [filename],
          subject:
              '${widget.source == 'Sample audit' ? 'Sample · ' : ''}SEO report · $host',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not create or share the report. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Client-ready report',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Measured results, prioritized findings and clear next steps.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final format in ['PDF', 'CSV'])
                  ChoiceChip(
                    label: Text(format),
                    selected: _format == format,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _format = format),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _project,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Project / report name (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _client,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Client name (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brand,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Prepared by / brand',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLength: 2000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Notes & next steps (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (widget.before != null)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include before & after'),
                subtitle: const Text(
                  'Compare with the previous audit of this page.',
                ),
                value: _includeComparison,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _includeComparison = value),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Builder(
              builder: (buttonContext) => FilledButton.icon(
                onPressed: _busy ? null : () => _share(buttonContext),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(_busy ? 'Preparing report…' : 'Share $_format'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
