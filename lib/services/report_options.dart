import 'audit_history_service.dart';
import 'audit_review.dart';
import 'seo_audit_service.dart';

class ReportOptions {
  const ReportOptions({
    this.projectName = '',
    this.clientName = '',
    this.brandName = 'MobileSEO',
    this.notes = '',
    this.source = 'Live audit',
    this.auditedAt,
    this.before,
    this.inProgress = const {},
  });
  final String projectName, clientName, brandName, notes, source;
  final DateTime? auditedAt;
  final AuditHistoryEntry? before;
  final Set<String> inProgress;

  AuditComparison? comparison(SeoAuditResult result) => before == null
      ? null
      : AuditComparison(before: before!.result, after: result);

  String workflow(AuditFinding finding, AuditComparison? comparison) =>
      finding.passed
      ? comparison?.resolved.any((resolved) => resolved.id == finding.id) ==
                true
            ? 'Verified'
            : 'Passed'
      : inProgress.contains(finding.id)
      ? 'In progress'
      : 'To do';
}
